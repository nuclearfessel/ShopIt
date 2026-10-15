import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModePref = 'theme_mode';

/// The saved theme choice ("system", "light" or "dark"); system if none.
Future<ThemeMode> loadThemeMode() async {
  try {
    final saved = (await SharedPreferences.getInstance()).getString(
      _themeModePref,
    );
    return ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  } on Object {
    return ThemeMode.system;
  }
}

/// Overridden in `main()` with the saved choice so the first frame already uses
/// the right theme.
final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(initialThemeModeProvider);

  /// Switches the theme now and remembers it on this device.
  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await (await SharedPreferences.getInstance()).setString(
        _themeModePref,
        mode.name,
      );
    } on Object {
      // Not being able to save only means the choice isn't remembered.
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
