import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import 'form_factor.dart';
import '../features/pantry/pantry_screen.dart';
import '../features/recipes/recipes_screen.dart';
import '../features/settings/device_link_controller.dart';
import '../features/settings/settings_dialog.dart';
import 'theme_mode.dart';
import 'title_bar.dart';
import '../features/shopping/shopping_screen.dart';
import '../ui/keyline/keyline_icon.dart';
import '../ui/tip.dart';

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
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/recipes', builder: (_, _) => const RecipesScreen()),
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
        // Deepest tone of the palette: used for the totals bar so it differs
        // from the navigation (surfaceContainer) and the cart panel.
        surfaceContainerHighest: dark
            ? const Color(0xFF363B2D)
            : const Color(0xFFE2D9BD),
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
      // Titles sit 16px from the left. An action button's drawn shape is
      // 40px inside a 48px tap target, so 12px of bar padding puts that
      // shape 16px from the right edge.
      actionsPadding: const EdgeInsets.only(right: 12),
      iconTheme: IconThemeData(color: lime),
      actionsIconTheme: IconThemeData(color: lime),
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

class ShopItApp extends ConsumerStatefulWidget {
  const ShopItApp({super.key, this.windowChrome = true});

  /// Draw the custom title bar (Windows only). Tests turn this off because it
  /// needs the window_manager plugin.
  final bool windowChrome;

  @override
  ConsumerState<ShopItApp> createState() => _ShopItAppState();
}

class _ShopItAppState extends ConsumerState<ShopItApp> {
  final _router = _createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps a saved link to the other device alive while the app is open.
    ref.watch(deviceLinkProvider);
    return MaterialApp.router(
      title: 'ShopIt',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: _router,
      // On Windows the native title bar is hidden; draw our own.
      builder: (context, child) => widget.windowChrome && Platform.isWindows
          ? WindowFrame(child: child ?? const SizedBox.shrink())
          : child ?? const SizedBox.shrink(),
    );
  }
}

/// Side rail when the window is not a phone. A phone uses the bottom bar.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _sections = [
    (KeylineIcons.shoppingCart, 'Shopping'),
    (KeylineIcons.archive, 'Pantry'),
    (KeylineIcons.bookOpen, 'Recipes'),
  ];

  /// Switches screen. A message (like "Deleted 2 items - UNDO") belongs to the
  /// screen that showed it, so it is dismissed rather than following you.
  void _go(BuildContext context, int i) {
    ScaffoldMessenger.of(context).clearSnackBars();
    shell.goBranch(i, initialLocation: i == shell.currentIndex);
  }

  /// Opens settings over the current section. From Shopping, it can assign
  /// that list's tax rate.
  void _openSettings(BuildContext context, WidgetRef ref) {
    final list = shell.currentIndex == 0
        ? ref.read(openShoppingListProvider)
        : null;
    showAppSettings(context, listId: list?.id, listName: list?.name);
  }

  void _select(BuildContext context, WidgetRef ref, int i) {
    if (i == _sections.length) {
      _openSettings(context, ref);
      return;
    }
    _go(context, i);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lime = Theme.of(context).brightness == Brightness.dark
        ? keyLimeOnDark
        : keyLimeOnLight;
    final wide = !isPhoneSize(MediaQuery.sizeOf(context));
    final Widget page;
    if (wide) {
      page = Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (i) => _go(context, i),
              labelType: NavigationRailLabelType.all,
              trailingAtBottom: true,
              destinations: [
                for (final d in _sections)
                  NavigationRailDestination(
                    icon: Tip('Go to ${d.$2}', child: KeylineIcon(d.$1)),
                    selectedIcon: Tip(
                      'Go to ${d.$2}',
                      child: KeylineIcon(d.$1),
                    ),
                    label: Text(d.$2),
                  ),
              ],
              trailing: _SettingsRailButton(
                color: lime,
                onPressed: () => _openSettings(context, ref),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      );
    } else {
      page = Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => _select(context, ref, i),
          destinations: [
            for (final d in _sections)
              NavigationDestination(
                icon: KeylineIcon(d.$1),
                selectedIcon: KeylineIcon(d.$1),
                label: d.$2,
                tooltip: 'Go to ${d.$2}',
              ),
            NavigationDestination(
              icon: KeylineIcon(KeylineIcons.settings, color: lime),
              selectedIcon: KeylineIcon(KeylineIcons.settings, color: lime),
              label: 'Settings',
              tooltip: 'Settings',
            ),
          ],
        ),
      );
    }
    final shortcut = settingsShortcut;
    if (shortcut == null) return page;
    return CallbackShortcuts(
      bindings: {shortcut: () => _openSettings(context, ref)},
      child: Focus(autofocus: true, child: page),
    );
  }
}

/// Settings pinned to the bottom of the side rail.
///
/// The press and hover mark is the same 56×32 stadium the rail draws behind
/// Shopping, Pantry, and Recipes, not a shape around the icon and the label.
class _SettingsRailButton extends StatelessWidget {
  const _SettingsRailButton({required this.color, required this.onPressed});

  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final label =
        NavigationRailTheme.of(context).unselectedLabelTextStyle ??
        theme.textTheme.labelMedium;
    final splash = colors.primary.a < 1
        ? colors.primary
        : colors.primary.withValues(alpha: 0.12);
    final hover = colors.primary.a < 1
        ? colors.primary
        : colors.primary.withValues(alpha: 0.04);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _RailIconInk(
        onTap: onPressed,
        splashColor: splash,
        hoverColor: hover,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: _RailIconInk.indicatorWidth,
                height: _RailIconInk.indicatorHeight,
                child: Center(
                  child: Tip(
                    'Settings',
                    child: KeylineIcon(KeylineIcons.settings, color: color),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text('Settings', style: label),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ink highlight limited to the rail's icon stadium (56 wide, 32 tall).
class _RailIconInk extends InkResponse {
  const _RailIconInk({
    required super.child,
    required super.onTap,
    required super.splashColor,
    required super.hoverColor,
  }) : super(
         containedInkWell: true,
         highlightShape: BoxShape.rectangle,
         customBorder: const StadiumBorder(),
       );

  static const indicatorWidth = 56.0;
  static const indicatorHeight = 32.0;

  @override
  RectCallback getRectCallback(RenderBox referenceBox) {
    return () {
      final boxWidth = referenceBox.size.width;
      return Rect.fromLTWH(
        (boxWidth - indicatorWidth) / 2,
        0,
        indicatorWidth,
        indicatorHeight,
      );
    };
  }
}
