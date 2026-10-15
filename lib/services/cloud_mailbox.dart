import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../data/database.dart';
import '../data/device_sync.dart';

/// Version of the blob stored in the shared mailbox.
const cloudMailboxVersion = 1;

/// Default internet mailbox. Uses a free key/value host so Shop-it can sync
/// without a custom server. The household code is the secret path.
const defaultCloudMailboxBase = 'https://keyvalue.immanuel.co/api/KeyVal';

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
    'name': name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'snapshot': snapshot.toJson(),
  };

  static CloudDeviceEntry? tryParse(String deviceId, Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, Object?>.from(raw);
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
      for (final entry in devices.entries) entry.key: entry.value.toJson(),
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

/// Reads and writes the household mailbox over HTTPS.
class CloudMailbox {
  CloudMailbox({this.baseUrl = defaultCloudMailboxBase, HttpClient? client})
    : _client = client;

  final String baseUrl;
  final HttpClient? _client;

  /// Creates an empty household and returns its pairing code.
  Future<String> createHousehold() async {
    final code = newHouseholdCode();
    await write(code, CloudMailboxDoc.empty());
    return code;
  }

  /// Loads the mailbox for [code], or an empty one when nothing is stored yet.
  Future<CloudMailboxDoc> read(String code) async {
    final text = await _get(code, 'mailbox');
    if (text == null || text.isEmpty || text == 'null') {
      return CloudMailboxDoc.empty();
    }
    final jsonText = _decodeStored(text);
    Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      throw const SyncException('Could not read the cloud mailbox.');
    }
    if (decoded is! Map) {
      throw const SyncException('Could not read the cloud mailbox.');
    }
    return CloudMailboxDoc.fromJson(decoded);
  }

  /// Replaces the mailbox for [code].
  Future<void> write(String code, CloudMailboxDoc doc) async {
    // Base64 keeps the body safe for hosts that mishandle JSON punctuation.
    final raw = utf8.encode(jsonEncode(doc.toJson()));
    await _put(code, 'mailbox', base64Url.encode(raw));
  }

  /// Merges every other device's snapshot into [db], then uploads this device.
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
    final mine = await db.exportSnapshot();
    doc.devices[deviceId] = CloudDeviceEntry(
      deviceId: deviceId,
      name: deviceName,
      updatedAt: DateTime.now().toUtc(),
      snapshot: mine,
    );
    await write(code, doc);
  }

  Future<String?> _get(String secret, String key) async {
    final client = _client ?? HttpClient();
    final owned = _client == null;
    try {
      final uri = Uri.parse('$baseUrl/GetValue/$secret/$key');
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 12));
      request.headers.set(HttpHeaders.userAgentHeader, 'Shop-it');
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode == HttpStatus.notFound) return null;
      if (response.statusCode != HttpStatus.ok) {
        throw SyncException(
          'The cloud mailbox did not answer (${response.statusCode}).',
        );
      }
      if (body.length >= 2 && body.startsWith('"') && body.endsWith('"')) {
        try {
          final decoded = jsonDecode(body);
          if (decoded is String) return decoded;
        } on FormatException {
          // Use the raw body.
        }
      }
      return body;
    } on SyncException {
      rethrow;
    } on SocketException {
      throw const SyncException(
        "Can't reach the cloud mailbox. Check the internet connection.",
      );
    } on TimeoutException {
      throw const SyncException('The cloud mailbox did not answer.');
    } finally {
      if (owned) client.close(force: true);
    }
  }

  Future<void> _put(String secret, String key, String value) async {
    final client = _client ?? HttpClient();
    final owned = _client == null;
    try {
      final uri = Uri.parse('$baseUrl/UpdateValue/$secret/$key');
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 12));
      request.headers.set(HttpHeaders.userAgentHeader, 'Shop-it');
      request.headers.contentType = ContentType(
        'text',
        'plain',
        charset: 'utf-8',
      );
      request.write(value);
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      await response.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SyncException(
          'Could not save to the cloud mailbox (${response.statusCode}).',
        );
      }
    } on SyncException {
      rethrow;
    } on SocketException {
      throw const SyncException(
        "Can't reach the cloud mailbox. Check the internet connection.",
      );
    } on TimeoutException {
      throw const SyncException('The cloud mailbox did not answer.');
    } finally {
      if (owned) client.close(force: true);
    }
  }
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

String _decodeStored(String text) {
  final trimmed = text.trim();
  try {
    final bytes = base64Url.decode(trimmed);
    return utf8.decode(bytes);
  } on FormatException {
    // Older plain-JSON writes, or a host that wraps quotes.
  }
  if (trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is String) return _decodeStored(decoded);
    } on FormatException {
      // Fall through.
    }
  }
  return trimmed;
}

/// In-memory mailbox for tests. No network.
class MemoryCloudMailbox extends CloudMailbox {
  MemoryCloudMailbox() : super(baseUrl: 'memory://');

  final _store = <String, String>{};

  @override
  Future<CloudMailboxDoc> read(String code) async {
    final text = _store[code];
    if (text == null || text.isEmpty) return CloudMailboxDoc.empty();
    return CloudMailboxDoc.fromJson(jsonDecode(_decodeStored(text)) as Map);
  }

  @override
  Future<void> write(String code, CloudMailboxDoc doc) async {
    final raw = utf8.encode(jsonEncode(doc.toJson()));
    _store[code] = base64Url.encode(raw);
  }
}
