import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/providers.dart';
import '../../services/cloud_mailbox.dart';
import '../../services/device_link.dart';

const _prefKey = 'device_link';
const _deviceIdKey = 'device_id';
const _cloudCodeKey = 'cloud_household';
const _network = MethodChannel('shop.it/network');

/// Whether this device is sharing lists on Wi-Fi and/or over the internet.
class DeviceLinkState {
  const DeviceLinkState({
    this.sharing = false,
    this.peerNames = const [],
    this.lastSync,
    this.error,
    this.busy = false,
    this.cloudCode,
    this.cloudBusy = false,
  });

  final bool sharing;
  final List<String> peerNames;
  final DateTime? lastSync;
  final String? error;
  final bool busy;

  /// Household pairing code when this device is joined to cloud sync.
  final String? cloudCode;
  final bool cloudBusy;

  bool get cloudLinked => cloudCode != null && cloudCode!.isNotEmpty;

  String get summary {
    if (!sharing && !cloudLinked) return 'Not shared.';
    final parts = <String>[];
    if (sharing) {
      if (peerNames.isEmpty) {
        parts.add(
          lastSync != null
              ? 'Synced on this Wi-Fi.'
              : 'Looking for Shop-it on this Wi-Fi.',
        );
      } else if (peerNames.length == 1) {
        parts.add('Sharing with ${peerNames.first} on this Wi-Fi.');
      } else {
        parts.add('Sharing with ${peerNames.length} devices on this Wi-Fi.');
      }
    }
    if (cloudLinked) {
      parts.add(
        lastSync != null
            ? 'Cloud sync is on.'
            : 'Cloud sync is on. Waiting for the other device.',
      );
    }
    return parts.join(' ');
  }

  DeviceLinkState copyWith({
    bool? sharing,
    List<String>? peerNames,
    DateTime? lastSync,
    String? error,
    bool clearError = false,
    bool? busy,
    String? cloudCode,
    bool clearCloud = false,
    bool? cloudBusy,
  }) {
    return DeviceLinkState(
      sharing: sharing ?? this.sharing,
      peerNames: peerNames ?? this.peerNames,
      lastSync: lastSync ?? this.lastSync,
      error: clearError ? null : error ?? this.error,
      busy: busy ?? this.busy,
      cloudCode: clearCloud ? null : cloudCode ?? this.cloudCode,
      cloudBusy: cloudBusy ?? this.cloudBusy,
    );
  }
}

/// Shares lists on the same Wi-Fi and, when paired, through the cloud mailbox.
class DeviceLinkController extends Notifier<DeviceLinkState> {
  DeviceLinkController({CloudMailbox? mailbox}) : _mailbox = mailbox;

  final CloudMailbox? _mailbox;
  final _host = DeviceHost();
  final _discovery = DeviceDiscovery();
  Timer? _wifiTimer;
  Timer? _cloudTimer;
  Object _token = Object();
  var _syncing = false;
  var _cloudSyncing = false;

  CloudMailbox get mailbox => _mailbox ?? CloudMailbox();

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
      if (token != _token) return;
      if (state.sharing) unawaited(_syncPeers(token));
      if (state.cloudLinked) unawaited(_syncCloud(token));
    });
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() {
      _token = Object();
      _wifiTimer?.cancel();
      _wifiTimer = null;
      _cloudTimer?.cancel();
      _cloudTimer = null;
      _host.onSynced = null;
      _discovery.onChanged = null;
      WidgetsBinding.instance.removeObserver(observer);
      unawaited(_shutdown());
    });
    unawaited(_restore(token));
    return const DeviceLinkState();
  }

  /// Starts looking for the other device on this Wi-Fi and syncing with it.
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
      state = state.copyWith(sharing: true, busy: false, clearError: true);
      await _save();
      _startTimer(token);
    } on Object catch (error) {
      await _shutdown();
      if (token != _token) return;
      state = state.copyWith(
        sharing: false,
        busy: false,
        error: friendlySyncError(error),
      );
    }
  }

  /// Stops Wi-Fi sharing and forgets nearby devices.
  Future<void> stop() async {
    final token = _token;
    await _shutdown();
    if (token != _token) return;
    state = state.copyWith(
      sharing: false,
      peerNames: const [],
      busy: false,
      clearError: true,
    );
    await _save();
    _startTimer(token);
  }

  /// Creates a household and shows a code the other device can enter.
  Future<void> createCloudHousehold() async {
    final token = _token;
    if (state.cloudBusy || state.cloudLinked) return;
    state = state.copyWith(cloudBusy: true, clearError: true);
    try {
      final code = await mailbox.createHousehold();
      if (token != _token) return;
      state = state.copyWith(
        cloudCode: code,
        cloudBusy: false,
        clearError: true,
      );
      await _save();
      _startTimer(token);
      await _syncCloud(token);
    } on Object catch (error) {
      if (token != _token) return;
      state = state.copyWith(
        cloudBusy: false,
        error: friendlySyncError(error),
      );
    }
  }

  /// Joins an existing household with the code from the other device.
  Future<void> joinCloudHousehold(String raw) async {
    final token = _token;
    final code = raw.trim().toLowerCase();
    if (state.cloudBusy || state.cloudLinked) return;
    if (!isHouseholdCode(code)) {
      state = state.copyWith(
        error: 'Enter the eight-character code from the other device.',
      );
      return;
    }
    state = state.copyWith(cloudBusy: true, clearError: true);
    try {
      // Touch the mailbox so a bad code fails before we save it.
      await mailbox.read(code);
      if (token != _token) return;
      state = state.copyWith(
        cloudCode: code,
        cloudBusy: false,
        clearError: true,
      );
      await _save();
      _startTimer(token);
      await _syncCloud(token);
    } on Object catch (error) {
      if (token != _token) return;
      state = state.copyWith(
        cloudBusy: false,
        error: friendlySyncError(error),
      );
    }
  }

  /// Leaves the cloud household. Wi-Fi sharing is unchanged.
  Future<void> leaveCloud() async {
    final token = _token;
    state = state.copyWith(clearCloud: true, clearError: true);
    await _save();
    if (token != _token) return;
    _startTimer(token);
  }

  Future<void> _restore(Object token) async {
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } on Object {
      return;
    }
    if (token != _token) return;

    final cloud = prefs.getString(_cloudCodeKey);
    if (cloud != null && isHouseholdCode(cloud)) {
      state = state.copyWith(cloudCode: cloud.toLowerCase());
    }

    String? raw;
    try {
      raw = prefs.getString(_prefKey);
    } on Object {
      raw = null;
    }
    if (token != _token) return;
    if (raw != null && raw.isNotEmpty) {
      Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        decoded = null;
      }
      if (decoded is Map && decoded['sharing'] == true) {
        await startSharing();
      }
    }
    if (token != _token) return;
    _startTimer(token);
    if (state.cloudLinked) unawaited(_syncCloud(token));
  }

  void _startTimer(Object token) {
    _wifiTimer?.cancel();
    _cloudTimer?.cancel();
    _wifiTimer = null;
    _cloudTimer = null;
    if (state.sharing) {
      _wifiTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (token != _token) return;
        unawaited(_syncPeers(token));
      });
    }
    if (state.cloudLinked) {
      // Cloud is slower than Wi-Fi so it does not hammer the free mailbox.
      _cloudTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (token != _token) return;
        unawaited(_syncCloud(token));
      });
    }
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

  Future<void> _syncCloud(Object token) async {
    if (_cloudSyncing || token != _token || !state.cloudLinked) return;
    final code = state.cloudCode;
    if (code == null) return;
    _cloudSyncing = true;
    try {
      final db = ref.read(databaseProvider);
      await mailbox.syncDevice(
        code: code,
        deviceId: await _deviceId(),
        deviceName: thisDeviceName(),
        db: db,
      );
      if (token != _token) return;
      state = state.copyWith(lastSync: DateTime.now(), clearError: true);
    } on Object catch (error) {
      if (token != _token) return;
      state = state.copyWith(error: friendlySyncError(error));
    } finally {
      _cloudSyncing = false;
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

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (state.sharing) {
        await prefs.setString(_prefKey, jsonEncode({'sharing': true}));
      } else {
        await prefs.remove(_prefKey);
      }
      final code = state.cloudCode;
      if (code != null && code.isNotEmpty) {
        await prefs.setString(_cloudCodeKey, code);
      } else {
        await prefs.remove(_cloudCodeKey);
      }
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
