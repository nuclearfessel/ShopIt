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
import '../../services/sync_qr.dart';

const _prefKey = 'device_link';
const _deviceIdKey = 'device_id';
const _cloudCodeKey = 'cloud_household';
const _lastWifiSyncKey = 'last_wifi_sync';
const _lastCloudSyncKey = 'last_cloud_sync';
const _network = MethodChannel('shop.it/network');

/// Whether this device is sharing lists on Wi-Fi and/or over the internet.
class DeviceLinkState {
  const DeviceLinkState({
    this.sharing = false,
    this.peerNames = const [],
    this.lastWifiSync,
    this.lastCloudSync,
    this.wifiError,
    this.cloudError,
    this.busy = false,
    this.cloudCode,
    this.cloudBusy = false,
  });

  final bool sharing;
  final List<String> peerNames;
  final DateTime? lastWifiSync;
  final DateTime? lastCloudSync;
  final String? wifiError;
  final String? cloudError;
  final bool busy;

  /// Household pairing code when this device is joined to cloud sync.
  final String? cloudCode;
  final bool cloudBusy;

  bool get cloudLinked => cloudCode != null && cloudCode!.isNotEmpty;

  String get summary {
    if (!sharing && !cloudLinked) return 'Not shared.';
    final parts = <String>[];
    if (sharing) {
      if (wifiError != null) {
        parts.add('Wi-Fi sync failed.');
      } else if (peerNames.isEmpty) {
        parts.add(
          lastWifiSync != null
              ? 'Synced on this Wi-Fi.'
              : 'Looking for ShopIt on this Wi-Fi.',
        );
      } else if (peerNames.length == 1) {
        parts.add('Sharing with ${peerNames.first} on this Wi-Fi.');
      } else {
        parts.add('Sharing with ${peerNames.length} devices on this Wi-Fi.');
      }
    }
    if (cloudLinked) {
      if (cloudError != null) {
        parts.add('Cloud sync failed.');
      } else {
        parts.add(
          lastCloudSync != null
              ? 'Cloud sync is on.'
              : 'Cloud sync is on. Waiting for the other device.',
        );
      }
    }
    return parts.join(' ');
  }

  DeviceLinkState copyWith({
    bool? sharing,
    List<String>? peerNames,
    DateTime? lastWifiSync,
    DateTime? lastCloudSync,
    String? wifiError,
    bool clearWifiError = false,
    String? cloudError,
    bool clearCloudError = false,
    bool? busy,
    String? cloudCode,
    bool clearCloud = false,
    bool? cloudBusy,
  }) {
    return DeviceLinkState(
      sharing: sharing ?? this.sharing,
      peerNames: peerNames ?? this.peerNames,
      lastWifiSync: lastWifiSync ?? this.lastWifiSync,
      lastCloudSync: lastCloudSync ?? this.lastCloudSync,
      wifiError: clearWifiError ? null : wifiError ?? this.wifiError,
      cloudError: clearCloudError ? null : cloudError ?? this.cloudError,
      busy: busy ?? this.busy,
      cloudCode: clearCloud ? null : cloudCode ?? this.cloudCode,
      cloudBusy: cloudBusy ?? this.cloudBusy,
    );
  }
}

/// Shares lists on the same Wi-Fi and, when paired, through the cloud mailbox.
class DeviceLinkController extends Notifier<DeviceLinkState> {
  DeviceLinkController({this._mailbox});

  final CloudMailbox? _mailbox;
  final _host = DeviceHost();
  final _discovery = DeviceDiscovery();
  Timer? _wifiTimer;
  Timer? _cloudTimer;
  Future<void> _turn = Future<void>.value();
  Object _token = Object();
  var _syncing = false;
  var _cloudSyncing = false;

  CloudMailbox get mailbox => _mailbox ?? CloudMailbox();

  @override
  DeviceLinkState build() {
    final token = _token = Object();
    _host.onSynced = () {
      if (token != _token || !state.sharing) return;
      state = state.copyWith(
        lastWifiSync: DateTime.now(),
        clearWifiError: true,
      );
      unawaited(_save());
    };
    _discovery.onChanged = () {
      if (token != _token || !state.sharing) return;
      final names = [for (final peer in _discovery.peers) peer.name];
      if (_sameNames(names, state.peerNames)) return;
      state = state.copyWith(peerNames: names);
    };
    _host.readHousehold = () => state.cloudCode;
    final observer = _AppResumeObserver(
      onResume: () {
        if (token != _token) return;
        if (state.sharing) unawaited(_syncPeers(token));
        if (state.cloudLinked) unawaited(_syncCloud(token));
      },
      onBackground: () {
        if (token != _token || !state.cloudLinked) return;
        unawaited(_syncCloud(token));
      },
    );
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

  /// Starts looking for the other device on this Wi-Fi.
  ///
  /// Lists move only after both devices have the same household code. The
  /// code is typed in by hand and is not sent across the network.
  Future<void> startSharing() async {
    final token = _token;
    if (state.busy) return;
    if (!state.sharing) {
      state = state.copyWith(busy: true, clearWifiError: true);
      try {
        // The phone drops incoming announcements unless this lock is held
        // before the beacon socket opens.
        await _multicast(true);
        if (token != _token) return;
        final db = ref.read(databaseProvider);
        final port = await _host.start(db: db);
        if (token != _token) return;
        await _discovery.start(
          httpPort: port,
          deviceId: await _deviceId(),
          name: thisDeviceName(),
        );
        if (token != _token) return;
        state = state.copyWith(
          sharing: true,
          busy: false,
          clearWifiError: true,
        );
        await _save();
        _startTimer(token);
        if (state.cloudLinked) unawaited(_syncCloud(token));
        return;
      } on Object catch (error) {
        await _shutdown();
        if (token != _token) return;
        state = state.copyWith(
          sharing: false,
          busy: false,
          wifiError: friendlySyncError(error),
        );
      }
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
      clearWifiError: true,
    );
    await _save();
    _startTimer(token);
  }

  /// Creates a household and shows a code the other device can enter.
  Future<void> createCloudHousehold() async {
    final token = _token;
    if (state.cloudBusy || state.cloudLinked) return;
    state = state.copyWith(cloudBusy: true, clearCloudError: true);
    try {
      final code = await mailbox.createHousehold();
      if (token != _token) return;
      state = state.copyWith(
        cloudCode: code,
        cloudBusy: false,
        clearCloudError: true,
      );
      await _save();
      _startTimer(token);
      // The code is local. A broker that does not answer must not erase it,
      // or Wi-Fi sharing has nothing to prove the other device with.
      await _syncCloud(token);
      if (token != _token) return;
      if (!state.sharing) await startSharing();
    } on Object catch (error) {
      if (token != _token) return;
      state = state.copyWith(
        clearCloud: true,
        cloudBusy: false,
        cloudError: friendlySyncError(error),
      );
      await _save();
    }
  }

  /// Joins the household in a scanned QR code and starts Wi-Fi sharing.
  Future<void> joinFromQr(String raw) async {
    final code = householdFromQr(raw);
    if (code == null) {
      state = state.copyWith(
        cloudError: 'That QR code is not a ShopIt sync code.',
      );
      return;
    }
    if (state.cloudLinked && state.cloudCode != code) {
      state = state.copyWith(
        cloudError: 'Leave cloud sync before scanning a different code.',
      );
      return;
    }
    if (!state.cloudLinked) await joinCloudHousehold(code);
    if (!state.cloudLinked || state.cloudCode != code) return;
    if (!state.sharing) await startSharing();
  }

  /// Joins an existing household with the code from the other device.
  Future<void> joinCloudHousehold(String raw) async {
    final token = _token;
    final code = raw.trim().toLowerCase();
    if (state.cloudBusy || state.cloudLinked) return;
    if (!isHouseholdCode(code)) {
      state = state.copyWith(
        cloudError: 'Enter the full code from the other device.',
      );
      return;
    }
    state = state.copyWith(cloudBusy: true, clearCloudError: true);
    try {
      state = state.copyWith(
        cloudCode: code,
        cloudBusy: false,
        clearCloudError: true,
      );
      await _save();
      _startTimer(token);
      // First sync proves the mailbox is reachable.
      await _syncCloud(token);
      if (token != _token) return;
      if (!state.sharing) await startSharing();
    } on Object catch (error) {
      if (token != _token) return;
      state = state.copyWith(
        clearCloud: true,
        cloudBusy: false,
        cloudError: friendlySyncError(error),
      );
      await _save();
    }
  }

  /// Leaves the household and stops Wi-Fi sharing.
  ///
  /// Scanning a QR code joins the household and turns Wi-Fi on, so leaving
  /// has to undo both. The code is forgotten on this device even when the
  /// broker cannot be reached.
  Future<void> stopAllSharing() async {
    final token = _token;
    final code = state.cloudCode;
    await _shutdown();
    String? warning;
    if (code != null && isHouseholdCode(code)) {
      try {
        await mailbox.forgetDevice(code: code, deviceId: await _deviceId());
      } on Object {
        warning = 'Sharing is off. The stored cloud copy could not be removed.';
      }
    }
    if (token != _token) return;
    state = state.copyWith(
      sharing: false,
      peerNames: const [],
      busy: false,
      clearWifiError: true,
      clearCloud: true,
      cloudBusy: false,
      cloudError: warning,
      clearCloudError: warning == null,
    );
    await _save();
    if (token != _token) return;
    _startTimer(token);
  }

  /// Leaves the household. Wi-Fi sharing is turned off with it, because the
  /// two were started together and lists cannot move without the code.
  Future<void> leaveCloud() => stopAllSharing();

  Future<void> _restore(Object token) async {
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } on Object {
      return;
    }
    if (token != _token) return;

    final cloud = prefs.getString(_cloudCodeKey);
    final wifiAt = DateTime.tryParse(prefs.getString(_lastWifiSyncKey) ?? '');
    final cloudAt = DateTime.tryParse(prefs.getString(_lastCloudSyncKey) ?? '');
    if (cloud != null && isHouseholdCode(cloud) ||
        wifiAt != null ||
        cloudAt != null) {
      state = state.copyWith(
        cloudCode: cloud != null && isHouseholdCode(cloud)
            ? cloud.toLowerCase()
            : null,
        lastWifiSync: wifiAt,
        lastCloudSync: cloudAt,
      );
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
    if (!state.sharing) {
      _startTimer(token);
      if (state.cloudLinked) unawaited(_syncCloud(token));
    }
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
    final code = state.cloudCode;
    if (code == null || !isHouseholdCode(code)) return;
    final peers = _discovery.peers;
    if (peers.isEmpty) return;
    _syncing = true;
    try {
      await _oneAtATime(() async {
        final db = ref.read(databaseProvider);
        for (final peer in peers) {
          await syncWithDevice(
            db: db,
            host: peer.host,
            port: peer.port,
            household: code,
          );
          if (token != _token) return;
          state = state.copyWith(
            lastWifiSync: DateTime.now(),
            clearWifiError: true,
          );
          await _save();
        }
      });
    } on Object catch (error) {
      if (token != _token) return;
      state = state.copyWith(wifiError: friendlySyncError(error));
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
      await _oneAtATime(() async {
        final db = ref.read(databaseProvider);
        await mailbox.syncDevice(
          code: code,
          deviceId: await _deviceId(),
          deviceName: thisDeviceName(),
          db: db,
        );
        if (token != _token) return;
        state = state.copyWith(
          lastCloudSync: DateTime.now(),
          clearCloudError: true,
        );
        await _save();
      });
    } on Object catch (error) {
      if (token != _token) return;
      state = state.copyWith(cloudError: friendlySyncError(error));
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
      final wifiAt = state.lastWifiSync;
      if (wifiAt != null) {
        await prefs.setString(_lastWifiSyncKey, wifiAt.toIso8601String());
      }
      final cloudAt = state.lastCloudSync;
      if (cloudAt != null) {
        await prefs.setString(_lastCloudSyncKey, cloudAt.toIso8601String());
      }
    } on Object {
      // Sharing still works this session if the choice cannot be saved.
    }
  }

  /// Runs [action] after the previous list merge finishes.
  ///
  /// Wi-Fi and cloud sync both write the database. Overlapping merges were
  /// throwing, and that failure was shown as a generic sync error.
  Future<void> _oneAtATime(Future<void> Function() action) {
    final next = _turn.then((_) => action());
    _turn = next.then((_) {}, onError: (Object _, StackTrace _) {});
    return next;
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
  // Android holds a Wi-Fi lock. iOS and Mac use the same call to ask for
  // local-network permission, which is required before a phone can see a
  // computer on this Wi-Fi or open its QR sync.
  if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) return;
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
  _AppResumeObserver({required this.onResume, required this.onBackground});
  final void Function() onResume;
  final void Function() onBackground;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
    // Publish before the app is no longer on screen (Android background, or
    // the window hidden on desktop). inactive fires for dialogs, so skip it.
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      onBackground();
    }
  }
}
