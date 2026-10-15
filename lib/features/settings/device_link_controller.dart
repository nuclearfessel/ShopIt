import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/device_sync.dart';
import '../../data/providers.dart';
import '../../services/device_link.dart';

const _prefKey = 'device_link';

enum DeviceRole { none, host, client }

/// Whether this device is sharing lists, connecting to another, or neither.
class DeviceLinkState {
  const DeviceLinkState({
    this.role = DeviceRole.none,
    this.code = '',
    this.address = '',
    this.port = shopItSyncPort,
    this.localAddresses = const [],
    this.lastSync,
    this.error,
    this.busy = false,
  });

  final DeviceRole role;
  final String code;
  final String address;
  final int port;
  final List<String> localAddresses;
  final DateTime? lastSync;
  final String? error;
  final bool busy;

  bool get hosting => role == DeviceRole.host;
  bool get connected => role == DeviceRole.client;

  String get summary {
    switch (role) {
      case DeviceRole.none:
        return 'Not shared yet.';
      case DeviceRole.host:
        if (localAddresses.isEmpty) {
          return 'Sharing, but this device has no Wi-Fi address yet.';
        }
        return 'Sharing at ${localAddresses.first}:$port';
      case DeviceRole.client:
        if (lastSync == null) return 'Trying to reach $address:$port';
        return 'Connected to $address:$port';
    }
  }

  DeviceLinkState copyWith({
    DeviceRole? role,
    String? code,
    String? address,
    int? port,
    List<String>? localAddresses,
    DateTime? lastSync,
    String? error,
    bool clearError = false,
    bool? busy,
  }) {
    return DeviceLinkState(
      role: role ?? this.role,
      code: code ?? this.code,
      address: address ?? this.address,
      port: port ?? this.port,
      localAddresses: localAddresses ?? this.localAddresses,
      lastSync: lastSync ?? this.lastSync,
      error: clearError ? null : error ?? this.error,
      busy: busy ?? this.busy,
    );
  }
}

/// Keeps the Wi-Fi link alive for the whole time the app is open.
class DeviceLinkController extends Notifier<DeviceLinkState> {
  final _host = DeviceHost();
  Timer? _timer;
  Object _token = Object();
  var _syncing = false;

  @override
  DeviceLinkState build() {
    final token = _token = Object();
    _host.onSynced = () {
      if (token != _token || state.role != DeviceRole.host) return;
      state = state.copyWith(lastSync: DateTime.now(), clearError: true);
    };
    final observer = _AppResumeObserver(() {
      if (token != _token || state.role != DeviceRole.client) return;
      _exchange(token);
    });
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() {
      _token = Object();
      _timer?.cancel();
      _timer = null;
      _host.onSynced = null;
      WidgetsBinding.instance.removeObserver(observer);
      unawaited(_host.stop());
    });
    unawaited(_restore(token));
    return const DeviceLinkState();
  }

  /// Shows an address and code so the other device can connect here.
  Future<void> share({String? existingCode}) async {
    final token = _token;
    if (state.busy) return;
    _timer?.cancel();
    state = state.copyWith(busy: true, clearError: true);
    final code = existingCode ?? newPairingCode();
    try {
      final db = ref.read(databaseProvider);
      final port = await _host.start(db: db, code: code);
      if (token != _token) return;
      final addresses = await localSyncAddresses();
      if (token != _token) return;
      final next = DeviceLinkState(
        role: DeviceRole.host,
        code: code,
        port: port,
        localAddresses: addresses,
      );
      state = next;
      await _save(next);
    } on Object catch (error) {
      if (token != _token) return;
      state = state.copyWith(busy: false, error: friendlySyncError(error));
    }
  }

  /// Connects to a device that is already sharing and keeps syncing.
  ///
  /// [keepTrying] is for a link that was saved earlier: if the other device
  /// is not reachable yet, keep the link and try again.
  Future<void> connect({
    required String address,
    required String code,
    bool keepTrying = false,
  }) async {
    final token = _token;
    if (state.busy) return;
    final trimmed = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      state = state.copyWith(
        error: 'Enter the 6-digit code shown on the other device.',
      );
      return;
    }
    SyncAddress parsed;
    try {
      parsed = parseSyncAddress(address);
    } on SyncException catch (error) {
      state = state.copyWith(error: error.message);
      return;
    }
    final previous = state;
    _timer?.cancel();
    state = state.copyWith(busy: true, clearError: true);
    await _host.stop();
    try {
      final db = ref.read(databaseProvider);
      await syncWithDevice(
        db: db,
        host: parsed.host,
        port: parsed.port,
        code: trimmed,
      );
      if (token != _token) return;
      final next = DeviceLinkState(
        role: DeviceRole.client,
        code: trimmed,
        address: parsed.host,
        port: parsed.port,
        lastSync: DateTime.now(),
      );
      state = next;
      await _save(next);
      _startTimer(token);
    } on Object catch (error) {
      if (token != _token) return;
      if (keepTrying) {
        final next = DeviceLinkState(
          role: DeviceRole.client,
          code: trimmed,
          address: parsed.host,
          port: parsed.port,
          error: friendlySyncError(error),
        );
        state = next;
        await _save(next);
        _startTimer(token);
        return;
      }
      state = previous.copyWith(busy: false, error: friendlySyncError(error));
      if (previous.hosting && previous.code.length == 6) {
        await share(existingCode: previous.code);
      }
    }
  }

  /// Pulls and pushes lists once. Sharing from this device has nothing to
  /// pull: the other device is the one that checks in.
  Future<void> syncNow() => _exchange(_token);

  /// Stops sharing and forgets the other device.
  Future<void> stop() async {
    final token = _token;
    _timer?.cancel();
    _timer = null;
    await _host.stop();
    if (token != _token) return;
    const next = DeviceLinkState();
    state = next;
    await _save(next);
  }

  Future<void> _restore(Object token) async {
    String? raw;
    try {
      raw = (await SharedPreferences.getInstance()).getString(_prefKey);
    } on Object {
      return;
    }
    if (token != _token || raw == null || raw.isEmpty) return;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;
    final code = decoded['code'];
    if (code is! String || !RegExp(r'^\d{6}$').hasMatch(code)) return;
    if (decoded['role'] == 'host') {
      await share(existingCode: code);
      return;
    }
    if (decoded['role'] != 'client') return;
    final address = decoded['address'];
    final port = decoded['port'];
    if (address is! String || address.isEmpty || port is! int) return;
    await connect(address: '$address:$port', code: code, keepTrying: true);
  }

  void _startTimer(Object token) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (token != _token) return;
      _exchange(token);
    });
  }

  Future<void> _exchange(Object token) async {
    if (_syncing || token != _token || state.role != DeviceRole.client) return;
    _syncing = true;
    try {
      final db = ref.read(databaseProvider);
      await syncWithDevice(
        db: db,
        host: state.address,
        port: state.port,
        code: state.code,
      );
      if (token != _token) return;
      state = state.copyWith(lastSync: DateTime.now(), clearError: true);
    } on Object catch (error) {
      if (token != _token) return;
      state = state.copyWith(error: friendlySyncError(error));
    } finally {
      _syncing = false;
    }
  }

  Future<void> _save(DeviceLinkState value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value.role == DeviceRole.none) {
        await prefs.remove(_prefKey);
        return;
      }
      await prefs.setString(
        _prefKey,
        jsonEncode({
          'role': value.role.name,
          'code': value.code,
          'address': value.address,
          'port': value.port,
        }),
      );
    } on Object {
      // Sharing still works this session if the choice cannot be saved.
    }
  }
}

final deviceLinkProvider =
    NotifierProvider<DeviceLinkController, DeviceLinkState>(
      DeviceLinkController.new,
    );

class _AppResumeObserver extends WidgetsBindingObserver {
  _AppResumeObserver(this.onResume);
  final void Function() onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}
