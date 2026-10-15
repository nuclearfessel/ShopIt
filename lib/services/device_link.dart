import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../data/database.dart';
import '../data/device_sync.dart';

/// Port Shop-it listens on when this device is sharing lists.
const shopItSyncPort = 47821;

const shopItSyncCodeHeader = 'x-shop-it-code';

/// A 6-digit code the other device has to enter.
String newPairingCode() {
  final value = Random.secure().nextInt(1000000);
  return value.toString().padLeft(6, '0');
}

/// Turns "Can't reach…" style failures into a sentence for the dialog.
String friendlySyncError(Object error) {
  if (error is SyncException) return error.message;
  if (error is SocketException) {
    return "Can't reach that device. Check the address, and that both apps "
        'are open on the same Wi-Fi.';
  }
  if (error is TimeoutException) {
    return 'The other device did not answer.';
  }
  return 'Could not sync with the other device.';
}

/// `host` or `host:port`, with an optional `http://` in front.
class SyncAddress {
  const SyncAddress(this.host, this.port);
  final String host;
  final int port;
}

SyncAddress parseSyncAddress(String raw) {
  var text = raw.trim();
  final lower = text.toLowerCase();
  for (final prefix in ['http://', 'https://']) {
    if (lower.startsWith(prefix)) {
      text = text.substring(prefix.length);
      break;
    }
  }
  final slash = text.indexOf('/');
  if (slash >= 0) text = text.substring(0, slash);
  text = text.trim();
  if (text.isEmpty) {
    throw const SyncException('Enter the address shown on the other device.');
  }
  final colon = text.lastIndexOf(':');
  if (colon > 0 && !text.substring(0, colon).contains(':')) {
    final host = text.substring(0, colon).trim();
    final port = int.tryParse(text.substring(colon + 1));
    if (host.isEmpty || port == null || port <= 0 || port > 65535) {
      throw const SyncException(
        'That address does not look right. Use the one shown on the other '
        'device, such as 192.168.1.20:47821.',
      );
    }
    return SyncAddress(host, port);
  }
  if (text.contains(':') || text.contains(' ')) {
    throw const SyncException(
      'That address does not look right. Use the one shown on the other '
      'device, such as 192.168.1.20:47821.',
    );
  }
  return SyncAddress(text, shopItSyncPort);
}

/// IPv4 addresses the other device can use to reach this one, private
/// networks first.
Future<List<String>> localSyncAddresses() async {
  final primary = await _ipv4(includeLinkLocal: false);
  if (primary.isNotEmpty) return primary;
  return _ipv4(includeLinkLocal: true);
}

Future<List<String>> _ipv4({required bool includeLinkLocal}) async {
  final found = <String>[];
  final interfaces = await NetworkInterface.list(
    includeLoopback: false,
    includeLinkLocal: includeLinkLocal,
    type: InternetAddressType.IPv4,
  );
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      if (address.isLoopback) continue;
      found.add(address.address);
    }
  }
  found.sort((a, b) => _rank(a).compareTo(_rank(b)));
  return found;
}

int _rank(String ip) {
  if (ip.startsWith('10.') || ip.startsWith('192.168.')) return 0;
  final match = RegExp(r'^172\.(\d+)\.').firstMatch(ip);
  if (match != null) {
    final second = int.parse(match.group(1)!);
    if (second >= 16 && second <= 31) return 0;
  }
  if (ip.startsWith('169.254.')) return 2;
  return 1;
}

/// Listens for the other device and merges whatever it sends.
class DeviceHost {
  HttpServer? _server;
  AppDatabase? _db;
  String _code = '';
  Future<void> _queue = Future<void>.value();

  /// Called after a sync has been merged into the local database.
  void Function()? onSynced;

  bool get running => _server != null;
  int? get port => _server?.port;

  Future<int> start({
    required AppDatabase db,
    required String code,
    InternetAddress? bindAddress,
    int port = shopItSyncPort,
  }) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const SyncException('The sharing code must be 6 digits.');
    }
    await stop();
    _db = db;
    _code = code;
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
      final got = request.headers.value(shopItSyncCodeHeader);
      if (got != _code) {
        response.statusCode = HttpStatus.unauthorized;
        response.write('That code does not match.');
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
      await db.applySnapshot(SyncSnapshot.fromJson(decoded));
      final reply = await db.exportSnapshot();
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(reply.toJson()));
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

/// Sends this device's lists to [host] and applies what comes back.
Future<void> syncWithDevice({
  required AppDatabase db,
  required String host,
  required int port,
  required String code,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final snapshot = await db.exportSnapshot();
  final client = HttpClient();
  try {
    final request = await client.post(host, port, '/v1/sync').timeout(timeout);
    request.headers.set(shopItSyncCodeHeader, code);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(snapshot.toJson()));
    final response = await request.close().timeout(timeout);
    final text = await utf8.decoder.bind(response).join().timeout(timeout);
    if (response.statusCode == HttpStatus.unauthorized) {
      throw const SyncException(
        'That code does not match the one on the other device.',
      );
    }
    if (response.statusCode != HttpStatus.ok) {
      final message = text.trim();
      throw SyncException(
        message.isEmpty ? 'The other device could not sync.' : message,
      );
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const SyncException(
        'The other device sent a reply this app cannot read.',
      );
    }
    await db.applySnapshot(SyncSnapshot.fromJson(decoded));
  } on SyncException {
    rethrow;
  } on SocketException {
    throw const SyncException(
      "Can't reach that device. Check the address, and that both apps "
      'are open on the same Wi-Fi.',
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
