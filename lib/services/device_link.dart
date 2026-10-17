import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../data/database.dart';
import '../data/device_sync.dart';
import 'cloud_mailbox.dart';

/// Port Shop-it listens on when this device is sharing lists.
const shopItSyncPort = 47821;

/// Port used to notice other copies of Shop-it on the same Wi-Fi.
const shopItBeaconPort = 47822;

const shopItSyncHeader = 'x-shop-it';

/// A name the other device can show, such as "the phone".
String thisDeviceName() {
  if (Platform.isAndroid) return 'the phone';
  if (Platform.isWindows) return 'the computer';
  return 'the other device';
}

/// Turns connection failures into a sentence for the dialog.
String friendlySyncError(Object error) {
  if (error is SyncException) return error.message;
  if (error is SocketException) {
    return "Can't reach the other device. Keep both apps open on the same "
        'Wi-Fi.';
  }
  if (error is TimeoutException) {
    return 'The other device did not answer.';
  }
  return 'Could not sync with the other device.';
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
    socket.broadcastEnabled = true;
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
    final socket = _socket;
    if (socket == null) return;
    final bytes = utf8.encode(
      ShopItBeacon(port: _httpPort, id: _deviceId, name: _name).encode(),
    );
    try {
      socket.send(bytes, InternetAddress('255.255.255.255'), shopItBeaconPort);
    } on SocketException {
      // The network went away; the next announcement tries again.
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

  /// Household code to send back, when this device already has one.
  String? Function()? readHousehold;

  /// The other device included a household code in its sync.
  void Function(String code)? onHousehold;

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
      final body = await _readBody(request);
      if (request.method != 'POST' || request.uri.path != '/v1/sync') {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      if (request.headers.value(shopItSyncHeader) != '1') {
        response.statusCode = HttpStatus.unauthorized;
        return;
      }
      final db = _db;
      if (db == null) {
        response.statusCode = HttpStatus.serviceUnavailable;
        return;
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw const SyncException('Could not read that sync.');
      }
      final remoteCode = decoded['household'];
      if (remoteCode is String && isHouseholdCode(remoteCode)) {
        try {
          onHousehold?.call(remoteCode);
        } on Object {
          // The lists still merge if the code cannot be saved yet.
        }
      }
      await db.applySnapshot(SyncSnapshot.fromJson(decoded));
      final reply = await db.exportSnapshot();
      final json = reply.toJson();
      final mine = readHousehold?.call();
      if (mine != null && isHouseholdCode(mine)) json['household'] = mine;
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(json));
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

Future<String> _readBody(HttpRequest request) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in request) {
    builder.add(chunk);
    if (builder.length > 8 * 1024 * 1024) {
      throw const SyncException('That sync was too large.');
    }
  }
  return utf8.decode(builder.takeBytes());
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
  final snapshot = await db.exportSnapshot();
  final payload = snapshot.toJson();
  if (household != null && isHouseholdCode(household)) {
    payload['household'] = household;
  }
  final client = HttpClient();
  try {
    final request = await client.post(host, port, '/v1/sync').timeout(timeout);
    request.headers.set(shopItSyncHeader, '1');
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(payload));
    final response = await request.close().timeout(timeout);
    final text = await utf8.decoder.bind(response).join().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) {
      throw const SyncException('The other device could not sync.');
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const SyncException(
        'The other device sent a reply this app cannot read.',
      );
    }
    await db.applySnapshot(SyncSnapshot.fromJson(decoded));
    final remote = decoded['household'];
    if (remote is String && isHouseholdCode(remote)) return remote;
    return null;
  } on SyncException {
    rethrow;
  } on SocketException {
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
