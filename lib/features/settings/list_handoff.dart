import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _listHandoffPref = 'list_handoff';

/// Whether offers between the shopping list and the pantry are on.
/// Off when nothing has been saved.
Future<bool> loadListHandoff() async {
  try {
    return (await SharedPreferences.getInstance()).getBool(_listHandoffPref) ??
        false;
  } on Object {
    return false;
  }
}

/// Overridden in `main()` with the saved choice so the first frame matches it.
/// Tests leave this false.
final initialListHandoffProvider = Provider<bool>((ref) => false);

class ListHandoffNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(initialListHandoffProvider);

  /// Turns the offers on or off and remembers the choice on this device.
  Future<void> set(bool enabled) async {
    state = enabled;
    try {
      await (await SharedPreferences.getInstance()).setBool(
        _listHandoffPref,
        enabled,
      );
    } on Object {
      // Not being able to save only means the choice isn't remembered.
    }
  }
}

final listHandoffProvider = NotifierProvider<ListHandoffNotifier, bool>(
  ListHandoffNotifier.new,
);
