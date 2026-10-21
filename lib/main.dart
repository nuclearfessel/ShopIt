import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/form_factor.dart';
import 'app/theme_mode.dart';
import 'data/database.dart';
import 'data/providers.dart';
import 'features/settings/list_handoff.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Phones stay portrait, including the barcode camera. Tablets rotate.
  if ((Platform.isAndroid || Platform.isIOS) && hostIsPhone()) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  if (Platform.isWindows || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        title: 'ShopIt',
        size: const Size(1000, 720),
        // Narrower than this the layouts can't fit.
        minimumSize: const Size(360, 520),
        // Windows draws its own title bar. Mac keeps the system one.
        titleBarStyle: Platform.isWindows
            ? TitleBarStyle.hidden
            : TitleBarStyle.normal,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
  final db = await openAppDatabase();
  final themeMode = await loadThemeMode();
  final listHandoff = await loadListHandoff();
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialThemeModeProvider.overrideWithValue(themeMode),
        initialListHandoffProvider.overrideWithValue(listHandoff),
      ],
      child: const ShopItApp(),
    ),
  );
}
