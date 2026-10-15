import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/pantry/pantry_screen.dart';
import 'title_bar.dart';
import '../features/shopping/shopping_screen.dart';

GoRouter _createRouter() => GoRouter(
  initialLocation: '/shopping',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/shopping',
              builder: (_, _) => const ShoppingScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/pantry', builder: (_, _) => const PantryScreen()),
          ],
        ),
      ],
    ),
  ],
);

/// Key lime for all icons: a brighter tone on dark surfaces, a deeper one on
/// light surfaces so icons stay visible.
const keyLimeOnDark = Color(0xFFBFE04F);
const keyLimeOnLight = Color(0xFF86AA12);

// Warm off-white cream (light) and its warm charcoal-green companion (dark).
const _creamBackground = Color(0xFFFAF6EA);
const _creamSurface = Color(0xFFF2ECDA);
const _creamText = Color(0xFF2B2A24);
const _nightBackground = Color(0xFF1A1C17);
const _nightSurface = Color(0xFF242720);
const _nightText = Color(0xFFEDE8D6);

ThemeData _buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final lime = dark ? keyLimeOnDark : keyLimeOnLight;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF4F7A3A),
        brightness: brightness,
      ).copyWith(
        surface: dark ? _nightBackground : _creamBackground,
        onSurface: dark ? _nightText : _creamText,
        surfaceContainerLowest: dark ? _nightBackground : _creamBackground,
        surfaceContainerLow: dark ? _nightSurface : _creamSurface,
        surfaceContainer: dark ? _nightSurface : _creamSurface,
        surfaceContainerHigh: dark
            ? const Color(0xFF2C3026)
            : const Color(0xFFEBE4CF),
      );
  final base = ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    useMaterial3: true,
    // Bundled Roboto: the same clean sans-serif everywhere, not Windows' font.
    fontFamily: 'Roboto',
  );
  return base.copyWith(
    // Quieter, smaller labels and placeholders on every text field.
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(
        fontSize: 14,
        color: scheme.onSurface.withValues(alpha: 0.4),
      ),
      labelStyle: TextStyle(
        fontSize: 14,
        color: scheme.onSurface.withValues(alpha: 0.55),
      ),
      floatingLabelStyle: TextStyle(
        fontSize: 12,
        color: scheme.onSurface.withValues(alpha: 0.65),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(color: scheme.surfaceContainerLow),
    iconTheme: base.iconTheme.copyWith(color: lime),
    primaryIconTheme: base.primaryIconTheme.copyWith(color: lime),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: lime),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      foregroundColor: lime,
      backgroundColor: scheme.surfaceContainerHigh,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: lime)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainer,
      selectedIconTheme: IconThemeData(color: lime),
      unselectedIconTheme: IconThemeData(color: lime.withValues(alpha: 0.7)),
    ),
  );
}

class ShopItApp extends StatefulWidget {
  const ShopItApp({super.key, this.windowChrome = true});

  /// Draw the custom title bar (Windows only). Tests turn this off because it
  /// needs the window_manager plugin.
  final bool windowChrome;

  @override
  State<ShopItApp> createState() => _ShopItAppState();
}

class _ShopItAppState extends State<ShopItApp> {
  final _router = _createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Shop-it',
    theme: _buildTheme(Brightness.light),
    darkTheme: _buildTheme(Brightness.dark),
    routerConfig: _router,
    // On Windows the native title bar is hidden; draw our own.
    builder: (context, child) => widget.windowChrome && Platform.isWindows
        ? Column(
            children: [
              const AppTitleBar(),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          )
        : child ?? const SizedBox.shrink(),
  );
}

/// Side rail on wide windows (Windows), bottom bar on narrow ones (Android).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _destinations = [
    (Icons.shopping_cart_outlined, Icons.shopping_cart, 'Shopping'),
    (Icons.kitchen_outlined, Icons.kitchen, 'Pantry'),
  ];

  void _go(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.$1),
                    selectedIcon: Icon(d.$2),
                    label: Text(d.$3),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _go,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.$1),
              selectedIcon: Icon(d.$2),
              label: d.$3,
            ),
        ],
      ),
    );
  }
}
