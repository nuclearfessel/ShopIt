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
/// the household code before it is published, so the broker never sees list
/// contents. Retained messages hold the latest snapshot per device so the
/// phone and computer do not need to be online at the same time.
const defaultCloudMqttHost = 'broker.hivemq.com';
const defaultCloudMqttPort = 8883;

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
        'The cloud mailbox is from a different version of Shop-it.',
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
/// ciphertext sealed with the household code.
class CloudMailbox {
  CloudMailbox({
    this.host = defaultCloudMqttHost,
    this.port = defaultCloudMqttPort,
  });

  final String host;
  final int port;

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
    for (final entry in others.values) {
      await db.applySnapshot(entry.snapshot);
    }
    final mine = CloudDeviceEntry(
      deviceId: deviceId,
      name: deviceName,
      updatedAt: DateTime.now().toUtc(),
      snapshot: await db.exportSnapshot(),
    );
    await _publish(code, mine);
  }

  Future<Map<String, CloudDeviceEntry>> _collect(
    String code, {
    String? ignoreDeviceId,
  }) async {
    final client = _client('r-${_shortId()}');
    final devices = <String, CloudDeviceEntry>{};
    try {
      await _connect(client);
      final topic = _householdTopic(code);
      client.subscribe(topic, MqttQos.atLeastOnce);
      final pending = <Future<void>>[];
      final sub = client.updates?.listen((messages) {
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
      });
      // Retained messages arrive right after subscribe; wait briefly for them.
      await Future<void>.delayed(const Duration(seconds: 2));
      await Future.wait(pending);
      await sub?.cancel();
      return devices;
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
    final client = _client('w-${_shortId()}');
    try {
      await _connect(client);
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

  MqttServerClient _client(String id) {
    final client = MqttServerClient.withPort(host, id, port);
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.connectTimeoutPeriod = 10000;
    client.secure = port == 8883 || port == 8884;
    client.useWebSocket = port == 8000 || port == 8884;
    client.setProtocolV311();
    client.autoReconnect = false;
    return client;
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

String _householdTopic(String code) => 'shopit/p/$code/+';

String _deviceTopic(String code, String deviceId) => 'shopit/p/$code/$deviceId';

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
    utf8.encode('shop-it-mailbox-v1:${code.trim().toLowerCase()}'),
  );
  return SecretKey(hash.bytes);
}

String _shortId() {
  final random = Random.secure();
  return List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
}

/// Eight-character code one device shows and the other types in.
String newHouseholdCode() {
  final random = Random.secure();
  const alphabet = 'abcdefghijklmnopqrstuvwxyz23456789';
  return List.generate(
    8,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
}

/// True when [raw] looks like a household pairing code.
bool isHouseholdCode(String raw) {
  final code = raw.trim().toLowerCase();
  if (code.length != 8) return false;
  return RegExp(r'^[a-z2-9]+$').hasMatch(code);
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
    for (final entry in doc.devices.values) {
      if (entry.deviceId == deviceId) continue;
      await db.applySnapshot(entry.snapshot);
    }
    final mine = CloudDeviceEntry(
      deviceId: deviceId,
      name: deviceName,
      updatedAt: DateTime.now().toUtc(),
      snapshot: await db.exportSnapshot(),
    );
    _store['$code/$deviceId'] = mine;
  }
}
