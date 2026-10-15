import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/providers.dart';
import '../../services/device_link.dart';

const _prefKey = 'device_link';
const _deviceIdKey = 'device_id';
const _network = MethodChannel('shop.it/network');

/// Whether this device is sharing lists on the Wi-Fi.
class DeviceLinkState {
  const DeviceLinkState({
    this.sharing = false,
    this.peerNames = const [],
    this.lastSync,
    this.error,
    this.busy = false,
  });

  final bool sharing;
  final List<String> peerNames;
  final DateTime? lastSync;
  final String? error;
  final bool busy;

  String get summary {
    if (!sharing) return 'Not shared.';
    if (peerNames.isEmpty) {
      if (lastSync != null) return 'Synced with the other device.';
      return 'Looking for Shop-it on this Wi-Fi.';
    }
    if (peerNames.length == 1) return 'Sharing with ${peerNames.first}.';
    return 'Sharing with ${peerNames.length} devices.';
  }

  DeviceLinkState copyWith({
    bool? sharing,
    List<String>? peerNames,
    DateTime? lastSync,
    String? error,
    bool clearError = false,
    bool? busy,
  }) {
    return DeviceLinkState(
      sharing: sharing ?? this.sharing,
      peerNames: peerNames ?? this.peerNames,
      lastSync: lastSync ?? this.lastSync,
      error: clearError ? null : error ?? this.error,
      busy: busy ?? this.busy,
    );
  }
}

/// Shares lists with any other Shop-it on the same Wi-Fi.
class DeviceLinkController extends Notifier<DeviceLinkState> {
  final _host = DeviceHost();
  final _discovery = DeviceDiscovery();
  Timer? _timer;
  Object _token = Object();
  var _syncing = false;

  @override
  DeviceLinkState build() {
    final token = _token = Object();
    _host.onSynced = () {
      if (token != _token || !state.sharing) return;
      state = state.copyWith(lastSync: DateTime.now(), clearError: true);
    };
    _discovery.onChanged = () {
      if (token != _token || !state.sharing) return;
      final names = [for (final peer in _discovery.peers) peer.name];
      if (_sameNames(names, state.peerNames)) return;
      state = state.copyWith(peerNames: names);
    };
    final observer = _AppResumeObserver(() {
      if (token != _token || !state.sharing) return;
      unawaited(_syncPeers(token));
    });
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() {
      _token = Object();
      _timer?.cancel();
      _timer = null;
      _host.onSynced = null;
      _discovery.onChanged = null;
      WidgetsBinding.instance.removeObserver(observer);
      unawaited(_shutdown());
    });
    unawaited(_restore(token));
    return const DeviceLinkState();
  }

  /// Starts looking for the other device and syncing with it.
  Future<void> startSharing() async {
    final token = _token;
    if (state.busy || state.sharing) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final db = ref.read(databaseProvider);
      final port = await _host.start(db: db);
      if (token != _token) return;
      await _discovery.start(
        httpPort: port,
        deviceId: await _deviceId(),
        name: thisDeviceName(),
      );
      if (token != _token) return;
      await _multicast(true);
      const next = DeviceLinkState(sharing: true);
      state = next;
      await _save(true);
      _startTimer(token);
    } on Object catch (error) {
      await _shutdown();
      if (token != _token) return;
      state = DeviceLinkState(error: friendlySyncError(error));
    }
  }

  /// Stops sharing and forgets nearby devices.
  Future<void> stop() async {
    final token = _token;
    _timer?.cancel();
    _timer = null;
    await _shutdown();
    if (token != _token) return;
    const next = DeviceLinkState();
    state = next;
    await _save(false);
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
    if (decoded is! Map || decoded['sharing'] != true) return;
    await startSharing();
  }

  void _startTimer(Object token) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (token != _token) return;
      unawaited(_syncPeers(token));
    });
  }

  Future<void> _syncPeers(Object token) async {
    if (_syncing || token != _token || !state.sharing) return;
    final peers = _discovery.peers;
    if (peers.isEmpty) return;
    _syncing = true;
    try {
      final db = ref.read(databaseProvider);
      for (final peer in peers) {
        await syncWithDevice(db: db, host: peer.host, port: peer.port);
        if (token != _token) return;
        state = state.copyWith(lastSync: DateTime.now(), clearError: true);
      }
    } on Object catch (error) {
      if (token != _token) return;
      state = state.copyWith(error: friendlySyncError(error));
    } finally {
      _syncing = false;
    }
  }

  Future<void> _shutdown() async {
    await _multicast(false);
    await _discovery.stop();
    await _host.stop();
  }

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_deviceIdKey);
    if (saved != null && saved.isNotEmpty) return saved;
    final next = _newId();
    await prefs.setString(_deviceIdKey, next);
    return next;
  }

  Future<void> _save(bool sharing) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!sharing) {
        await prefs.remove(_prefKey);
        return;
      }
      await prefs.setString(_prefKey, jsonEncode({'sharing': true}));
    } on Object {
      // Sharing still works this session if the choice cannot be saved.
    }
  }
}

String _newId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

bool _sameNames(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Future<void> _multicast(bool on) async {
  if (!Platform.isAndroid) return;
  try {
    await _network.invokeMethod<void>('multicastLock', on);
  } on Object {
    // Some phones receive the announcement without the lock.
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
