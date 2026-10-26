import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a sideways swipe does to an item.
enum ItemSwipeAction {
  check,
  delete;

  static ItemSwipeAction fromStored(String? raw, ItemSwipeAction fallback) {
    return switch (raw) {
      'check' => ItemSwipeAction.check,
      'delete' => ItemSwipeAction.delete,
      _ => fallback,
    };
  }

  String get stored => switch (this) {
    ItemSwipeAction.check => 'check',
    ItemSwipeAction.delete => 'delete',
  };

  String get label => switch (this) {
    ItemSwipeAction.check => 'Check or uncheck',
    ItemSwipeAction.delete => 'Delete',
  };
}

/// Swipe right and swipe left, set separately for a phone and a desktop.
class SwipeActions {
  const SwipeActions({
    required this.phoneRight,
    required this.phoneLeft,
    required this.desktopRight,
    required this.desktopLeft,
  });

  final ItemSwipeAction phoneRight;
  final ItemSwipeAction phoneLeft;
  final ItemSwipeAction desktopRight;
  final ItemSwipeAction desktopLeft;

  /// Right checks, left deletes, on both a phone and a desktop.
  static const defaults = SwipeActions(
    phoneRight: ItemSwipeAction.check,
    phoneLeft: ItemSwipeAction.delete,
    desktopRight: ItemSwipeAction.check,
    desktopLeft: ItemSwipeAction.delete,
  );

  ItemSwipeAction rightFor({required bool desktop}) =>
      desktop ? desktopRight : phoneRight;

  ItemSwipeAction leftFor({required bool desktop}) =>
      desktop ? desktopLeft : phoneLeft;

  SwipeActions copyWith({
    ItemSwipeAction? phoneRight,
    ItemSwipeAction? phoneLeft,
    ItemSwipeAction? desktopRight,
    ItemSwipeAction? desktopLeft,
  }) => SwipeActions(
    phoneRight: phoneRight ?? this.phoneRight,
    phoneLeft: phoneLeft ?? this.phoneLeft,
    desktopRight: desktopRight ?? this.desktopRight,
    desktopLeft: desktopLeft ?? this.desktopLeft,
  );
}

const _phoneRightKey = 'swipe_phone_right';
const _phoneLeftKey = 'swipe_phone_left';
const _desktopRightKey = 'swipe_desktop_right';
const _desktopLeftKey = 'swipe_desktop_left';

SwipeActions swipeActionsFromPrefs(Map<String, String?> stored) => SwipeActions(
  phoneRight: ItemSwipeAction.fromStored(
    stored[_phoneRightKey],
    SwipeActions.defaults.phoneRight,
  ),
  phoneLeft: ItemSwipeAction.fromStored(
    stored[_phoneLeftKey],
    SwipeActions.defaults.phoneLeft,
  ),
  desktopRight: ItemSwipeAction.fromStored(
    stored[_desktopRightKey],
    SwipeActions.defaults.desktopRight,
  ),
  desktopLeft: ItemSwipeAction.fromStored(
    stored[_desktopLeftKey],
    SwipeActions.defaults.desktopLeft,
  ),
);

/// Windows, Mac, and Linux use the desktop swipe settings. A phone or tablet
/// uses the phone settings.
bool get swipeActionsUseDesktop =>
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.linux;

class SwipeActionsNotifier extends Notifier<SwipeActions> {
  @override
  SwipeActions build() {
    _load();
    return SwipeActions.defaults;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = swipeActionsFromPrefs({
        _phoneRightKey: prefs.getString(_phoneRightKey),
        _phoneLeftKey: prefs.getString(_phoneLeftKey),
        _desktopRightKey: prefs.getString(_desktopRightKey),
        _desktopLeftKey: prefs.getString(_desktopLeftKey),
      });
      state = next;
    } on Object {
      // Preferences failing only means the defaults stay for this session.
    }
  }

  Future<void> _write(String key, ItemSwipeAction action) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        key,
        action.stored,
      );
    } on Object {
      // The choice still applies until the app closes.
    }
  }

  Future<void> setPhoneRight(ItemSwipeAction action) async {
    state = state.copyWith(phoneRight: action);
    await _write(_phoneRightKey, action);
  }

  Future<void> setPhoneLeft(ItemSwipeAction action) async {
    state = state.copyWith(phoneLeft: action);
    await _write(_phoneLeftKey, action);
  }

  Future<void> setDesktopRight(ItemSwipeAction action) async {
    state = state.copyWith(desktopRight: action);
    await _write(_desktopRightKey, action);
  }

  Future<void> setDesktopLeft(ItemSwipeAction action) async {
    state = state.copyWith(desktopLeft: action);
    await _write(_desktopLeftKey, action);
  }
}

final swipeActionsProvider = NotifierProvider<SwipeActionsNotifier, SwipeActions>(
  SwipeActionsNotifier.new,
);
