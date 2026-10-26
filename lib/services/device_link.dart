import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../app/form_factor.dart';
import '../data/database.dart';
import '../data/device_sync.dart';
import 'cloud_mailbox.dart';

/// Port Shop-it listens on when this device is sharing lists.
const shopItSyncPort = 47821;

/// Port used to notice other copies of Shop-it on the same Wi-Fi.
const shopItBeaconPort = 47822;

const shopItSyncHeader = 'x-shop-it-mac';

/// The id this install announces as. Preferences failing must not stop
/// sharing, so a new id is used for the session when they do.
Future<String> resolveDeviceId({
  String? remembered,
  required Future<String?> Function() readSaved,
  required Future<void> Function(String id) write,
}) async {
  if (remembered != null && remembered.isNotEmpty) return remembered;
  var created = '';
  try {
    final saved = await readSaved();
    if (saved != null && saved.isNotEmpty) return saved;
    created = _newDeviceId();
    await write(created);
    return created;
  } on Object {
    if (created.isNotEmpty) return created;
    return _newDeviceId();
  }
}

String _newDeviceId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

/// A name the other device can show, such as "the phone" or "the iPad".
String thisDeviceName() {
  final phone = hostIsPhone();
  if (Platform.isIOS) return phone ? 'the iPhone' : 'the iPad';
  if (Platform.isAndroid) return phone ? 'the phone' : 'the tablet';
  if (Platform.isMacOS) return 'the Mac';
  if (Platform.isWindows) return 'the computer';
  return 'the other device';
}

/// Turns connection failures into a sentence for the dialog.
String friendlySyncError(Object error) {
  if (error is SyncException) return error.message;
  if (error is SocketException ||
      error is HttpException ||
      error is HandshakeException ||
      error is TlsException ||
      error is OSError) {
    return "Can't reach the other device. Keep both apps open on the same "
        'Wi-Fi.';
  }
  if (error is TimeoutException) {
    return 'The other device did not answer.';
  }
  // Method-channel failures (a Wi-Fi lock, preferences) are not a sentence
  // the dialog can show. Sharing treats them as non-fatal on their own.
  if (error is PlatformException) {
    return 'Could not sync with the other device.';
  }
  final type = error.runtimeType.toString();
  if (type.contains('Sqlite') || type.contains('Drift')) {
    return 'Could not save the lists from the other device.';
  }
  final detail = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (detail.isEmpty) return 'Could not sync with the other device.';
  final short = detail.length > 140 ? '${detail.substring(0, 137)}...' : detail;
  return 'Could not sync with the other device. $short';
}

/// What one device announces so the others can find it.
class ShopItBeacon {
  const ShopItBeacon({
    required this.port,
    required this.id,
    required this.name,
  });

  final int port;
  final String id;
  final String name;

  String encode() => 'SHOPIT1\t$port\t$id\t$name';

  static ShopItBeacon? tryParse(String raw) {
    final parts = raw.split('\t');
    if (parts.length < 4 || parts[0] != 'SHOPIT1') return null;
    final port = int.tryParse(parts[1]);
    final id = parts[2];
    final name = parts.sublist(3).join('\t').trim();
    if (port == null || port <= 0 || port > 65535) return null;
    if (id.isEmpty || name.isEmpty) return null;
    return ShopItBeacon(port: port, id: id, name: name);
  }
}

/// Another Shop-it that announced itself on this network.
class NearbyDevice {
  const NearbyDevice({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
  });

  final String id;
  final String name;
  final String host;
  final int port;
}

/// One announcement: sent from [from] to the broadcast [to].
class BeaconSend {
  const BeaconSend({required this.from, required this.to});

  final InternetAddress from;
  final InternetAddress to;
}

/// Virtual, mobile-data, and tunnel adapters are skipped. A failed send on
/// one of those used to close the socket that listens for the other device.
bool announcesOnInterface(String name) {
  final lower = name.toLowerCase();
  const skip = [
    'loopback',
    'virtual',
    'vethernet',
    'vmware',
    'vbox',
    'docker',
    'wsl',
    'hyper-v',
    'hyperv',
    'bluetooth',
    'npcap',
    'tunnel',
    'tun',
    'awdl',
    'llw',
    'bridge',
    'anpi',
    'ipsec',
    'rmnet',
    'ccmni',
    'pdp',
    'dummy',
  ];
  return !skip.any(lower.contains);
}

/// Directed broadcasts for real network adapters. The global broadcast is
/// only the fallback, because a computer with a virtual adapter often sends
/// that packet from an address the phone cannot reach.
List<BeaconSend> beaconSendsFor(
  Iterable<({String name, String address})> interfaces,
) {
  final sends = <BeaconSend>[];
  final seen = <String>{};
  for (final interface in interfaces) {
    if (!announcesOnInterface(interface.name)) continue;
    final directed = subnetBroadcast(interface.address);
    if (directed == null) continue;
    final from = InternetAddress(interface.address);
    if (seen.add('${interface.address}>$directed')) {
      sends.add(BeaconSend(from: from, to: InternetAddress(directed)));
    }
    // Some phones only hear this general broadcast, and some only hear the
    // subnet one. Send both, each from the adapter's own address.
    if (seen.add('${interface.address}>255.255.255.255')) {
      sends.add(BeaconSend(from: from, to: InternetAddress('255.255.255.255')));
    }
  }
  if (sends.isEmpty) {
    sends.add(
      BeaconSend(
        from: InternetAddress.anyIPv4,
        to: InternetAddress('255.255.255.255'),
      ),
    );
  }
  return sends;
}

/// Where a beacon is sent. Phones often drop the global broadcast and
/// deliver only the subnet broadcast, such as 192.168.1.255.
Future<List<BeaconSend>> beaconTargets() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    return beaconSendsFor([
      for (final interface in interfaces)
        for (final address in interface.addresses)
          (name: interface.name, address: address.address),
    ]);
  } on SocketException {
    return beaconSendsFor(const []);
  }
}

/// The /24 broadcast for [ipv4], or null when [ipv4] is not a usable address.
String? subnetBroadcast(String ipv4) {
  if (ipv4.startsWith('127.')) return null;
  final parts = ipv4.split('.');
  if (parts.length != 4) return null;
  if (parts.any((part) => int.tryParse(part) == null)) return null;
  return '${parts[0]}.${parts[1]}.${parts[2]}.255';
}

/// Broadcasts "Shop-it is here" and remembers the replies.
class DeviceDiscovery {
  RawDatagramSocket? _socket;
  Timer? _announce;
  var _httpPort = shopItSyncPort;
  var _deviceId = '';
  var _name = '';
  final _peers = <String, ({NearbyDevice device, DateTime seen})>{};

  /// Called when the set of nearby devices changes.
  void Function()? onChanged;

  List<NearbyDevice> get peers {
    _dropStale(notify: false);
    return [for (final peer in _peers.values) peer.device];
  }

  Future<void> start({
    required int httpPort,
    required String deviceId,
    required String name,
  }) async {
    await stop();
    _httpPort = httpPort;
    _deviceId = deviceId;
    _name = name;
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      shopItBeaconPort,
      reuseAddress: true,
    );
    try {
      socket.broadcastEnabled = true;
    } on Object {
      // Android can reject this option. The socket still sends directed
      // broadcasts, which is what most phones actually deliver.
    }
    _socket = socket;
    socket.listen(_onEvent, onError: (_, _) {});
    _announce = Timer.periodic(const Duration(seconds: 2), (_) => _send());
    _send();
  }

  Future<void> stop() async {
    _announce?.cancel();
    _announce = null;
    final socket = _socket;
    _socket = null;
    socket?.close();
    if (_peers.isNotEmpty) {
      _peers.clear();
      onChanged?.call();
    }
  }

  void _send() {
    _dropStale(notify: true);
    if (_socket == null) return;
    final bytes = utf8.encode(
      ShopItBeacon(port: _httpPort, id: _deviceId, name: _name).encode(),
    );
    // A separate socket per announcement. Sending a broadcast the adapter
    // rejects must not close the socket that is listening for replies.
    unawaited(() async {
      final targets = await beaconTargets();
      var sent = false;
      for (final target in targets) {
        if (_socket == null) return;
        sent = await _sendOne(bytes, target) || sent;
      }
      final usedGlobal = targets.any(
        (target) => target.to.address == '255.255.255.255',
      );
      if (!sent && !usedGlobal && _socket != null) {
        await _sendOne(
          bytes,
          BeaconSend(
            from: InternetAddress.anyIPv4,
            to: InternetAddress('255.255.255.255'),
          ),
        );
      }
    }());
  }

  Future<bool> _sendOne(List<int> bytes, BeaconSend target) async {
    RawDatagramSocket? sender;
    try {
      sender = await RawDatagramSocket.bind(target.from, 0, reuseAddress: true);
      try {
        sender.broadcastEnabled = true;
      } on Object {
        // Android can reject this option. A directed broadcast may
        // still leave from this address.
      }
      sender.send(bytes, target.to, shopItBeaconPort);
      return true;
    } on Object {
      // This adapter cannot take the announcement. The next one tries.
      return false;
    } finally {
      sender?.close();
    }
  }

  void _onEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final socket = _socket;
    if (socket == null) return;
    final packet = socket.receive();
    if (packet == null) return;
    if (packet.address.type != InternetAddressType.IPv4) return;
    if (packet.address.isLoopback) return;
    final beacon = ShopItBeacon.tryParse(utf8.decode(packet.data));
    if (beacon == null || beacon.id == _deviceId) return;
    final next = NearbyDevice(
      id: beacon.id,
      name: beacon.name,
      host: packet.address.address,
      port: beacon.port,
    );
    final previous = _peers[beacon.id]?.device;
    _peers[beacon.id] = (device: next, seen: DateTime.now());
    if (previous?.host != next.host ||
        previous?.port != next.port ||
        previous?.name != next.name) {
      onChanged?.call();
    }
  }

  void _dropStale({required bool notify}) {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 8));
    final before = _peers.length;
    _peers.removeWhere((_, peer) => peer.seen.isBefore(cutoff));
    if (notify && _peers.length != before) onChanged?.call();
  }
}

/// Listens for the other device and merges whatever it sends.
class DeviceHost {
  HttpServer? _server;
  AppDatabase? _db;
  Future<void> _queue = Future<void>.value();

  /// Called after a sync has been merged into the local database.
  void Function()? onSynced;

  /// Household code both devices typed in. Lists are refused without it.
  String? Function()? readHousehold;

  bool get running => _server != null;
  int? get port => _server?.port;

  Future<int> start({
    required AppDatabase db,
    InternetAddress? bindAddress,
    int port = shopItSyncPort,
  }) async {
    await stop();
    _db = db;
    final address = bindAddress ?? InternetAddress.anyIPv4;
    _server = await _bind(address, port);
    _server!.listen(_onRequest, onError: (_, _) {});
    return _server!.port;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _db = null;
    if (server != null) await server.close(force: true);
  }

  Future<HttpServer> _bind(InternetAddress address, int port) async {
    try {
      return await HttpServer.bind(address, port);
    } on SocketException {
      if (port == 0) rethrow;
    }
    for (var next = port + 1; next < port + 5; next++) {
      try {
        return await HttpServer.bind(address, next);
      } on SocketException {
        continue;
      }
    }
    throw const SyncException(
      'Could not start sharing. Something else is already using the port.',
    );
  }

  void _onRequest(HttpRequest request) {
    final next = _queue.then((_) => _handle(request));
    _queue = next.then((_) {}, onError: (_, _) {});
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      final body = await _readBytes(request);
      if (request.method != 'POST' || request.uri.path != '/v1/sync') {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      final code = readHousehold?.call();
      final presented = request.headers.value(shopItSyncHeader) ?? '';
      if (code == null ||
          !isHouseholdCode(code) ||
          !await mailboxBodyMacMatches(code, body, presented)) {
        response.statusCode = HttpStatus.unauthorized;
        return;
      }
      final db = _db;
      if (db == null) {
        response.statusCode = HttpStatus.serviceUnavailable;
        return;
      }
      final opened = await openMailboxPayload(code, utf8.decode(body));
      if (opened == null) {
        response.statusCode = HttpStatus.unauthorized;
        return;
      }
      final decoded = jsonDecode(opened);
      if (decoded is! Map) {
        throw const SyncException('Could not read that sync.');
      }
      await db.applySnapshot(
        SyncSnapshot.fromJson(decoded),
        replaceLocalOnlyItems: false,
        acceptRemoteOnlyLiveItems: true,
      );
      final reply = await db.exportSnapshot();
      final sealed = await sealMailboxPayload(code, jsonEncode(reply.toJson()));
      response.headers.contentType = ContentType.text;
      response.write(sealed);
      try {
        onSynced?.call();
      } on Object {
        // The lists are already saved; the screen updates on the next sync.
      }
    } on SyncException catch (error) {
      response.statusCode = HttpStatus.badRequest;
      response.write(error.message);
    } on FormatException {
      response.statusCode = HttpStatus.badRequest;
      response.write('Could not read that sync.');
    } on Object {
      response.statusCode = HttpStatus.badRequest;
      response.write('Could not sync.');
    } finally {
      try {
        await response.close();
      } on Object {
        // The other device hung up.
      }
    }
  }
}

Future<List<int>> _readBytes(HttpRequest request) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in request) {
    builder.add(chunk);
    if (builder.length > 8 * 1024 * 1024) {
      throw const SyncException('That sync was too large.');
    }
  }
  return builder.takeBytes();
}

/// Picks the household code both devices should use.
///
/// A mailbox that has already synced is kept. Otherwise the two codes
/// collapse to one so the devices meet in the same mailbox.
String? pickHouseholdCode(
  String? local,
  String? remote, {
  required bool keepLocal,
}) {
  final localOk = local != null && isHouseholdCode(local);
  final remoteOk = remote != null && isHouseholdCode(remote);
  if (localOk && keepLocal) return local;
  if (!remoteOk) return localOk ? local : null;
  if (!localOk) return remote;
  if (local == remote) return local;
  return local.compareTo(remote) <= 0 ? local : remote;
}

/// Sends this device's lists to [host] and applies what comes back.
///
/// Returns the household code the other device sent, when it sent one.
Future<String?> syncWithDevice({
  required AppDatabase db,
  required String host,
  required int port,
  String? household,
  Duration timeout = const Duration(seconds: 8),
}) async {
  if (household == null || !isHouseholdCode(household)) {
    throw const SyncException(
      'Enter the same household code on both devices before sharing lists.',
    );
  }
  final snapshot = await db.exportSnapshot();
  final sealed = await sealMailboxPayload(
    household,
    jsonEncode(snapshot.toJson()),
  );
  final bytes = utf8.encode(sealed);
  final client = HttpClient()..findProxy = ((_) => 'DIRECT');
  client.connectionTimeout = timeout;
  try {
    final request = await client.post(host, port, '/v1/sync').timeout(timeout);
    request.headers.set(
      shopItSyncHeader,
      await mailboxBodyMac(household, bytes),
    );
    request.headers.contentType = ContentType.text;
    request.add(bytes);
    final response = await request.close().timeout(timeout);
    final text = await utf8.decoder.bind(response).join().timeout(timeout);
    if (response.statusCode == HttpStatus.unauthorized) {
      throw const SyncException(
        'The other device refused the sync. Use the same household code on both.',
      );
    }
    if (response.statusCode != HttpStatus.ok) {
      throw const SyncException('The other device could not sync.');
    }
    final opened = await openMailboxPayload(household, text);
    if (opened == null) {
      throw const SyncException(
        'The other device sent a reply this app cannot read.',
      );
    }
    final decoded = jsonDecode(opened);
    if (decoded is! Map) {
      throw const SyncException(
        'The other device sent a reply this app cannot read.',
      );
    }
    await db.applySnapshot(
      SyncSnapshot.fromJson(decoded),
      replaceLocalOnlyItems: false,
      acceptRemoteOnlyLiveItems: true,
    );
    return null;
  } on SyncException {
    rethrow;
  } on SocketException {
    throw const SyncException(
      "Can't reach the other device. Keep both apps open on the same Wi-Fi.",
    );
  } on HttpException {
    throw const SyncException(
      "Can't reach the other device. Keep both apps open on the same Wi-Fi.",
    );
  } on HandshakeException {
    throw const SyncException(
      "Can't reach the other device. Keep both apps open on the same Wi-Fi.",
    );
  } on TlsException {
    throw const SyncException(
      "Can't reach the other device. Keep both apps open on the same Wi-Fi.",
    );
  } on OSError {
    throw const SyncException(
      "Can't reach the other device. Keep both apps open on the same Wi-Fi.",
    );
  } on TimeoutException {
    throw const SyncException('The other device did not answer.');
  } on FormatException {
    throw const SyncException(
      'The other device sent a reply this app cannot read.',
    );
  } finally {
    client.close(force: true);
  }
}
