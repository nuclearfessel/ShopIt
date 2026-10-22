import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../data/database.dart';
import '../data/device_sync.dart';

/// Version of each device's retained cloud message.
const cloudMailboxVersion = 1;

/// MQTT broker used only as an encrypted drop box. List JSON is sealed with
/// the secret half of the household code. The public mailbox id is the only
/// part that appears in the topic, so seeing the topic does not reveal the
/// key. Retained messages hold the latest snapshot per device so the phone
/// and computer do not need to be online at the same time.
const defaultCloudMqttHost = 'broker.hivemq.com';
const defaultCloudMqttPort = 8883;

/// One way to reach the mailbox. WebSocket is tried as well as MQTT-over-TLS
/// because mobile networks often block port 8883 while still allowing the
/// websocket ports.
class CloudEndpoint {
  const CloudEndpoint({
    required this.server,
    required this.port,
    required this.websocket,
  });

  final String server;
  final int port;
  final bool websocket;

  @override
  bool operator ==(Object other) =>
      other is CloudEndpoint &&
      other.server == server &&
      other.port == port &&
      other.websocket == websocket;

  @override
  int get hashCode => Object.hash(server, port, websocket);
}

/// TLS only. Plain websocket is not used, because it would expose the
/// ciphertext and the mailbox id without encryption on the connection.
const cloudEndpoints = <CloudEndpoint>[
  CloudEndpoint(
    server: 'wss://broker.hivemq.com/mqtt',
    port: 8884,
    websocket: true,
  ),
  CloudEndpoint(server: defaultCloudMqttHost, port: 8883, websocket: false),
];

const _mailboxMacBytes = 16;
const _mailboxNonceBytes = 12;

/// One device's latest snapshot sitting in the household mailbox.
class CloudDeviceEntry {
  const CloudDeviceEntry({
    required this.deviceId,
    required this.name,
    required this.updatedAt,
    required this.snapshot,
  });

  final String deviceId;
  final String name;
  final DateTime updatedAt;
  final SyncSnapshot snapshot;

  Map<String, Object?> toJson() => {
    'v': cloudMailboxVersion,
    'name': name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'snapshot': snapshot.toJson(),
  };

  static CloudDeviceEntry? tryParse(String deviceId, Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, Object?>.from(raw);
    final version = map['v'];
    if (version != null && version != cloudMailboxVersion) return null;
    final name = map['name'];
    final updated = map['updatedAt'];
    final snap = map['snapshot'];
    if (name is! String || name.isEmpty) return null;
    if (updated is! String) return null;
    final at = DateTime.tryParse(updated)?.toUtc();
    if (at == null) return null;
    if (snap is! Map) return null;
    try {
      return CloudDeviceEntry(
        deviceId: deviceId,
        name: name,
        updatedAt: at,
        snapshot: SyncSnapshot.fromJson(snap),
      );
    } on SyncException {
      return null;
    }
  }
}

/// The shared document every paired device reads and writes.
class CloudMailboxDoc {
  CloudMailboxDoc({Map<String, CloudDeviceEntry>? devices})
    : devices = devices ?? {};

  final Map<String, CloudDeviceEntry> devices;

  Map<String, Object?> toJson() => {
    'v': cloudMailboxVersion,
    'devices': {
      for (final entry in devices.entries)
        entry.key: {
          'name': entry.value.name,
          'updatedAt': entry.value.updatedAt.toUtc().toIso8601String(),
          'snapshot': entry.value.snapshot.toJson(),
        },
    },
  };

  factory CloudMailboxDoc.fromJson(Map<dynamic, dynamic> json) {
    if (json['v'] != cloudMailboxVersion) {
      throw const SyncException(
        'The cloud mailbox is from a different version of ShopIt.',
      );
    }
    final raw = json['devices'];
    final devices = <String, CloudDeviceEntry>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final id = entry.key;
        if (id is! String || id.isEmpty) continue;
        final parsed = CloudDeviceEntry.tryParse(id, entry.value);
        if (parsed != null) devices[id] = parsed;
      }
    }
    return CloudMailboxDoc(devices: devices);
  }

  static CloudMailboxDoc empty() => CloudMailboxDoc();
}

/// Reads and writes the household mailbox. Payloads on the broker are
/// ciphertext sealed with the secret half of the household code.
class CloudMailbox {
  CloudMailbox({
    this.host = defaultCloudMqttHost,
    this.port = defaultCloudMqttPort,
  });

  final String host;
  final int port;
  CloudEndpoint? _preferred;

  /// Creates a household code. The mailbox is created when the first device
  /// uploads a snapshot.
  Future<String> createHousehold() async => newHouseholdCode();

  /// Loads every retained device snapshot for [code].
  Future<CloudMailboxDoc> read(String code) async {
    final devices = await _collect(code);
    return CloudMailboxDoc(devices: devices);
  }

  /// Publishes one retained placeholder so a brand-new household is reachable.
  /// Prefer [syncDevice] for a real upload.
  Future<void> write(String code, CloudMailboxDoc doc) async {
    // Kept for tests and older call sites. Live sync uses [syncDevice].
    for (final entry in doc.devices.entries) {
      await _publish(code, entry.value);
    }
  }

  /// Merges every other device's snapshot into [db], then uploads this device.
  Future<void> syncDevice({
    required String code,
    required String deviceId,
    required String deviceName,
    required AppDatabase db,
  }) async {
    final others = await _collect(code, ignoreDeviceId: deviceId);
    await _mergePeerSnapshots(db, others.values);
    final mine = CloudDeviceEntry(
      deviceId: deviceId,
      name: deviceName,
      updatedAt: DateTime.now().toUtc(),
      snapshot: await db.exportSnapshot(),
    );
    await _publish(code, mine);
  }

  /// Applies peer snapshots oldest-first. Membership follows the newest
  /// *content* (list/item timestamps). A peer whose lists are older cannot
  /// stack onto or wipe fresher local names; a peer with newer content
  /// replaces local-only names so devices converge.
  Future<void> _mergePeerSnapshots(
    AppDatabase db,
    Iterable<CloudDeviceEntry> peers,
  ) async {
    final ordered = peers.toList()
      ..sort((a, b) {
        final byContent = _entryContentStamp(a).compareTo(_entryContentStamp(b));
        if (byContent != 0) return byContent;
        return a.updatedAt.compareTo(b.updatedAt);
      });
    if (ordered.isEmpty) return;

    final localStamp = snapshotContentStamp(await db.exportSnapshot());
    final newestPeer = ordered.last;
    final peerStamp = snapshotContentStamp(newestPeer.snapshot);
    // Local membership wins only when local content is strictly newer. A tie
    // lets the newer peer publish replace, so an empty computer still picks up
    // the phone. Same-second edits are rare; Wi-Fi sync still replaces always.
    final localIsNewest =
        localStamp != null &&
        peerStamp != null &&
        localStamp.isAfter(peerStamp);

    if (localIsNewest) {
      for (final entry in ordered) {
        await db.applySnapshot(
          entry.snapshot,
          replaceLocalOnlyItems: false,
          acceptRemoteOnlyLiveItems: false,
        );
      }
      return;
    }

    for (final entry in ordered.take(ordered.length - 1)) {
      await db.applySnapshot(
        entry.snapshot,
        replaceLocalOnlyItems: false,
        acceptRemoteOnlyLiveItems: true,
      );
    }
    await db.applySnapshot(
      newestPeer.snapshot,
      replaceLocalOnlyItems: true,
      acceptRemoteOnlyLiveItems: true,
    );
  }

  DateTime _entryContentStamp(CloudDeviceEntry entry) =>
      snapshotContentStamp(entry.snapshot) ?? entry.updatedAt;

  /// Removes this device's retained snapshot. An empty retained publish is
  /// how the broker deletes the stored copy.
  Future<void> forgetDevice({
    required String code,
    required String deviceId,
  }) async {
    final client = await _open('d-${_shortId()}');
    try {
      final topic = _deviceTopic(code, deviceId);
      final empty = MqttClientPayloadBuilder().payload!;
      client.publishMessage(topic, MqttQos.atLeastOnce, empty, retain: true);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    } on SyncException {
      rethrow;
    } on Object {
      throw const SyncException(
        'Could not remove the stored cloud copy. Leave sync again when you are online.',
      );
    } finally {
      _disconnect(client);
    }
  }

  Future<Map<String, CloudDeviceEntry>> _collect(
    String code, {
    String? ignoreDeviceId,
  }) async {
    final client = await _open('r-${_shortId()}');
    final devices = <String, CloudDeviceEntry>{};
    try {
      final topic = _householdTopic(code);
      client.subscribe(topic, MqttQos.atLeastOnce);
      final pending = <Future<void>>[];
      var closed = false;
      final sub = client.updates?.listen((messages) {
        if (closed) return;
        for (final message in messages) {
          final rec = message.payload;
          if (rec is! MqttPublishMessage) continue;
          final deviceId = _deviceIdFromTopic(message.topic);
          if (deviceId == null) continue;
          if (ignoreDeviceId != null && deviceId == ignoreDeviceId) continue;
          final text = MqttPublishPayload.bytesToStringAsString(
            rec.payload.message,
          );
          pending.add(() async {
            final entry = await _entryFromPayload(code, deviceId, text);
            if (entry != null) devices[deviceId] = entry;
          }());
        }
      }, onError: (Object _, StackTrace _) {});
      // Retained messages can arrive after the first wait, especially on a
      // phone. Keep draining until the connection has been quiet, and do not
      // touch the map again once it has been returned.
      final started = DateTime.now();
      var quietSince = started;
      while (DateTime.now().difference(started) < const Duration(seconds: 4)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (pending.isEmpty) {
          final waited = DateTime.now().difference(started);
          final quiet = DateTime.now().difference(quietSince);
          if (waited >= const Duration(seconds: 2) &&
              quiet >= const Duration(milliseconds: 300)) {
            break;
          }
          continue;
        }
        final batch = List<Future<void>>.from(pending);
        pending.clear();
        await Future.wait(batch);
        quietSince = DateTime.now();
      }
      closed = true;
      if (pending.isNotEmpty) {
        await Future.wait(List<Future<void>>.from(pending));
      }
      await sub?.cancel();
      return Map<String, CloudDeviceEntry>.from(devices);
    } on SyncException {
      rethrow;
    } on SocketException {
      throw const SyncException(
        "Can't reach the cloud mailbox. Check the internet connection.",
      );
    } on TimeoutException {
      throw const SyncException('The cloud mailbox did not answer.');
    } on Object {
      throw const SyncException('The cloud mailbox did not answer.');
    } finally {
      _disconnect(client);
    }
  }

  Future<void> _publish(String code, CloudDeviceEntry entry) async {
    final client = await _open('w-${_shortId()}');
    try {
      final topic = _deviceTopic(code, entry.deviceId);
      final builder = MqttClientPayloadBuilder();
      builder.addString(
        await sealMailboxPayload(code, jsonEncode(entry.toJson())),
      );
      client.publishMessage(
        topic,
        MqttQos.atLeastOnce,
        builder.payload!,
        retain: true,
      );
      // Give the broker a moment to accept the retained publish.
      await Future<void>.delayed(const Duration(milliseconds: 400));
    } on SyncException {
      rethrow;
    } on SocketException {
      throw const SyncException(
        "Can't reach the cloud mailbox. Check the internet connection.",
      );
    } on TimeoutException {
      throw const SyncException('The cloud mailbox did not answer.');
    } on Object {
      throw const SyncException('Could not save to the cloud mailbox.');
    } finally {
      _disconnect(client);
    }
  }

  List<CloudEndpoint> get _endpoints {
    if (host != defaultCloudMqttHost || port != defaultCloudMqttPort) {
      return [CloudEndpoint(server: host, port: port, websocket: port == 8884)];
    }
    final preferred = _preferred;
    if (preferred == null) return cloudEndpoints;
    return [
      preferred,
      for (final endpoint in cloudEndpoints)
        if (endpoint != preferred) endpoint,
    ];
  }

  /// Connects through the first endpoint that answers. Remembers it so the
  /// next sync does not wait on a port this network blocks.
  Future<MqttServerClient> _open(String id) async {
    Object? last;
    for (final endpoint in _endpoints) {
      final client = buildCloudMqttClient(endpoint: endpoint, clientId: id);
      try {
        await _connect(client);
        _preferred = endpoint;
        return client;
      } on Object catch (error) {
        last = error;
        _disconnect(client);
      }
    }
    if (last is SyncException) throw last;
    throw const SyncException(
      "Can't reach the cloud mailbox. Check the internet connection.",
    );
  }

  Future<void> _connect(MqttServerClient client) async {
    try {
      final status = await client.connect().timeout(
        const Duration(seconds: 12),
      );
      if (status?.state != MqttConnectionState.connected) {
        throw const SyncException('The cloud mailbox did not answer.');
      }
    } on SyncException {
      rethrow;
    } on SocketException {
      throw const SyncException(
        "Can't reach the cloud mailbox. Check the internet connection.",
      );
    } on TimeoutException {
      throw const SyncException('The cloud mailbox did not answer.');
    } on NoConnectionException {
      throw const SyncException('The cloud mailbox did not answer.');
    } on Object {
      throw const SyncException('The cloud mailbox did not answer.');
    }
  }

  void _disconnect(MqttServerClient client) {
    try {
      client.disconnect();
    } on Object {
      // Already closed.
    }
  }
}

/// Builds a client for [endpoint]. WebSocket must not also set [MqttServerClient.secure]:
/// that flag turns the websocket off and speaks MQTT-TLS instead.
MqttServerClient buildCloudMqttClient({
  required CloudEndpoint endpoint,
  required String clientId,
}) {
  final client = MqttServerClient.withPort(
    endpoint.server,
    clientId,
    endpoint.port,
  );
  client.logging(on: false);
  client.keepAlivePeriod = 20;
  client.connectTimeoutPeriod = 8000;
  client.connectionTimeout = 8000;
  client.useWebSocket = endpoint.websocket;
  client.secure = !endpoint.websocket;
  if (endpoint.websocket) {
    client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
  }
  client.setProtocolV311();
  client.autoReconnect = false;
  return client;
}

String _householdTopic(String code) => 'shopit/p/${householdMailboxId(code)}/+';

String _deviceTopic(String code, String deviceId) =>
    'shopit/p/${householdMailboxId(code)}/$deviceId';

/// Topic for one device. The secret half of [code] is not included.
String mailboxDeviceTopic(String code, String deviceId) =>
    _deviceTopic(code, deviceId);

String? _deviceIdFromTopic(String topic) {
  final parts = topic.split('/');
  if (parts.length != 4 || parts[0] != 'shopit' || parts[1] != 'p') return null;
  final id = parts[3];
  return id.isEmpty ? null : id;
}

Future<CloudDeviceEntry?> _entryFromPayload(
  String code,
  String deviceId,
  String text,
) async {
  final jsonText = await openMailboxPayload(code, text.trim());
  if (jsonText == null) return null;
  Object? decoded;
  try {
    decoded = jsonDecode(jsonText);
  } on FormatException {
    return null;
  }
  return CloudDeviceEntry.tryParse(deviceId, decoded);
}

/// Seals [json] so a broker or anyone without [code] cannot read the lists.
Future<String> sealMailboxPayload(String code, String json) async {
  final algorithm = AesGcm.with256bits();
  final box = await algorithm.encrypt(
    gzip.encode(utf8.encode(json)),
    secretKey: await _mailboxKey(code),
  );
  final packed = <int>[...box.nonce, ...box.mac.bytes, ...box.cipherText];
  return 'enc1:${base64Url.encode(packed)}';
}

/// Opens a payload sealed with [code]. Returns null when it is not ours
/// (plaintext leftovers, or a different household code).
Future<String?> openMailboxPayload(String code, String stored) async {
  final trimmed = stored.trim();
  if (!trimmed.startsWith('enc1:')) return null;
  List<int> packed;
  try {
    packed = base64Url.decode(trimmed.substring(5));
  } on FormatException {
    return null;
  }
  if (packed.length <= _mailboxNonceBytes + _mailboxMacBytes) return null;
  final box = SecretBox(
    packed.sublist(_mailboxNonceBytes + _mailboxMacBytes),
    nonce: packed.sublist(0, _mailboxNonceBytes),
    mac: Mac(
      packed.sublist(_mailboxNonceBytes, _mailboxNonceBytes + _mailboxMacBytes),
    ),
  );
  try {
    final clear = await AesGcm.with256bits().decrypt(
      box,
      secretKey: await _mailboxKey(code),
    );
    return utf8.decode(gzip.decode(clear));
  } on SecretBoxAuthenticationError {
    return null;
  } on Object {
    return null;
  }
}

Future<SecretKey> _mailboxKey(String code) async {
  final hash = await Sha256().hash(
    utf8.encode('shop-it-mailbox-v2:${householdSecret(code)}'),
  );
  return SecretKey(hash.bytes);
}

/// HMAC of [body] using the secret half of [code]. Sent with a Wi-Fi sync
/// so a device that does not know the code cannot read or change lists.
Future<String> mailboxBodyMac(String code, List<int> body) async {
  final mac = await Hmac.sha256().calculateMac(
    body,
    secretKey: await _mailboxKey(code),
  );
  return base64Url.encode(mac.bytes);
}

/// True when [presented] is the MAC this device would produce for [body].
Future<bool> mailboxBodyMacMatches(
  String code,
  List<int> body,
  String presented,
) async {
  final expected = await mailboxBodyMac(code, body);
  if (expected.length != presented.length) return false;
  var diff = 0;
  for (var i = 0; i < expected.length; i++) {
    diff |= expected.codeUnitAt(i) ^ presented.codeUnitAt(i);
  }
  return diff == 0;
}

String _shortId() {
  final random = Random.secure();
  return List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
}

/// Public half of a new code. It only has to be unique, so it is shorter
/// than the secret.
const householdMailboxIdLength = 8;

/// Secret half of a new code. Thirty-two letters at this length is 100 bits,
/// which is still far past a practical guess of a snapshot the broker can
/// already download.
const householdSecretLength = 20;

/// Codes created by the first 1.0.0 rebuild. They still join.
const legacyHouseholdMailboxIdLength = 10;
const legacyHouseholdSecretLength = 26;

String _randomCode(int length) {
  final random = Random.secure();
  const alphabet = 'abcdefghijklmnopqrstuvwxyz23456789';
  return List.generate(
    length,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
}

/// A pairing code: a public mailbox id, a dot, then the secret.
///
/// Only the mailbox id is used in the cloud topic. The secret is the
/// encryption key and is never placed in the topic.
String newHouseholdCode() =>
    '${_randomCode(householdMailboxIdLength)}.${_randomCode(householdSecretLength)}';

/// True when [raw] is a mailbox id, a dot, and a secret of a known length.
bool isHouseholdCode(String raw) {
  final code = raw.trim().toLowerCase();
  final parts = code.split('.');
  if (parts.length != 2) return false;
  final id = parts[0];
  final secret = parts[1];
  final known =
      (id.length == householdMailboxIdLength &&
          secret.length == householdSecretLength) ||
      (id.length == legacyHouseholdMailboxIdLength &&
          secret.length == legacyHouseholdSecretLength);
  if (!known) return false;
  return RegExp(r'^[a-z2-9]+$').hasMatch(id) &&
      RegExp(r'^[a-z2-9]+$').hasMatch(secret);
}

/// The public half of a household code. This is the only part used in a topic.
String householdMailboxId(String code) {
  final normalized = code.trim().toLowerCase();
  if (!isHouseholdCode(normalized)) {
    throw const SyncException('That household code is not valid.');
  }
  return normalized.split('.').first;
}

/// The secret half of a household code. This is the encryption key material.
String householdSecret(String code) {
  final normalized = code.trim().toLowerCase();
  if (!isHouseholdCode(normalized)) {
    throw const SyncException('That household code is not valid.');
  }
  return normalized.split('.').last;
}

/// In-memory mailbox for tests. No network.
class MemoryCloudMailbox extends CloudMailbox {
  MemoryCloudMailbox() : super(host: 'memory');

  final _store = <String, CloudDeviceEntry>{};

  @override
  Future<String> createHousehold() async => newHouseholdCode();

  @override
  Future<CloudMailboxDoc> read(String code) async {
    final devices = <String, CloudDeviceEntry>{};
    final prefix = '$code/';
    for (final entry in _store.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      devices[entry.value.deviceId] = entry.value;
    }
    return CloudMailboxDoc(devices: devices);
  }

  @override
  Future<void> write(String code, CloudMailboxDoc doc) async {
    for (final entry in doc.devices.entries) {
      _store['$code/${entry.key}'] = entry.value;
    }
  }

  @override
  Future<void> syncDevice({
    required String code,
    required String deviceId,
    required String deviceName,
    required AppDatabase db,
  }) async {
    final doc = await read(code);
    final others = [
      for (final entry in doc.devices.values)
        if (entry.deviceId != deviceId) entry,
    ];
    await _mergePeerSnapshots(db, others);
    final mine = CloudDeviceEntry(
      deviceId: deviceId,
      name: deviceName,
      updatedAt: DateTime.now().toUtc(),
      snapshot: await db.exportSnapshot(),
    );
    _store['$code/$deviceId'] = mine;
  }

  @override
  Future<void> forgetDevice({
    required String code,
    required String deviceId,
  }) async {
    _store.remove('$code/$deviceId');
  }
}
