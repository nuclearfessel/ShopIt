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

/// Original Tangerine. Material 3 builds primary, secondary, outline, and
/// error from this seed; the surfaces below replace the generated ones.
const shopItSeed = Color(0xFFEF7008);

/// Icons on neutral surfaces: deeper tangerine on light, gold on dark.
const iconOnDark = Color(0xFFFEC256);
const iconOnLight = Color(0xFFA8430A);

const _lightBackground = Color(0xFFF8F1E7);
const _lightCards = Color(0xFFF1E7D8);
const _lightRaised = Color(0xFFFFF8EA);
const _lightTotals = Color(0xFFE8D8C1);
const _lightText = Color(0xFF24342D);

const _darkBackground = Color(0xFF171E1A);
const _darkCards = Color(0xFF202B25);
const _darkRaised = Color(0xFF26372F);
const _darkTotals = Color(0xFF304238);
const _darkText = Color(0xFFFFF8EA);

/// Placeholders such as "0.00" tell the user what to type, so they are not
/// the 40% used for disabled content. 75% is the lightest step that stays
/// at least 4.5:1 on every surface in the palette. Resting labels are a
/// step stronger, and a floating label uses the full text color.
const _hintOpacity = 0.75;
const _labelOpacity = 0.85;

ThemeData shopItTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final icon = dark ? iconOnDark : iconOnLight;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: shopItSeed,
        brightness: brightness,
      ).copyWith(
        surface: dark ? _darkBackground : _lightBackground,
        onSurface: dark ? _darkText : _lightText,
        // Keep elevation from washing the fixed surfaces with the orange seed.
        surfaceTint: Colors.transparent,
        surfaceContainerLowest: dark ? _darkBackground : _lightBackground,
        surfaceContainerLow: dark ? _darkCards : _lightCards,
        surfaceContainer: dark ? _darkCards : _lightCards,
        surfaceContainerHigh: dark ? _darkRaised : _lightRaised,
        // Totals bar. Separate from navigation (surfaceContainer) and the
        // cart panel (surfaceContainerHigh).
        surfaceContainerHighest: dark ? _darkTotals : _lightTotals,
      );
  final base = ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    useMaterial3: true,
    // Bundled Roboto: the same clean sans-serif everywhere, not Windows' font.
    fontFamily: 'Roboto',
  );

  IconThemeData iconFor(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return IconThemeData(color: icon.withValues(alpha: 0.4));
    }
    // The selected pill is a generated fill, so its icon uses that fill's
    // own foreground. Unselected icons sit on the neutral navigation surface.
    if (states.contains(WidgetState.selected)) {
      return IconThemeData(color: scheme.onSecondaryContainer);
    }
    return IconThemeData(color: icon);
  }

  return base.copyWith(
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(
        fontSize: 14,
        color: scheme.onSurface.withValues(alpha: _hintOpacity),
      ),
      labelStyle: TextStyle(
        fontSize: 14,
        color: scheme.onSurface.withValues(alpha: _labelOpacity),
      ),
      floatingLabelStyle: TextStyle(fontSize: 12, color: scheme.onSurface),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      // Titles sit 16px from the left. An action button's drawn shape is
      // 40px inside a 48px tap target, so 12px of bar padding puts that
      // shape 16px from the right edge.
      actionsPadding: const EdgeInsets.only(right: 12),
      iconTheme: IconThemeData(color: icon),
      actionsIconTheme: IconThemeData(color: icon),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
    ),
    iconTheme: base.iconTheme.copyWith(color: icon),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: icon,
        disabledForegroundColor: icon.withValues(alpha: 0.4),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      foregroundColor: icon,
      backgroundColor: scheme.surfaceContainerHigh,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      iconTheme: WidgetStateProperty.resolveWith(iconFor),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
      unselectedIconTheme: IconThemeData(color: icon),
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
      theme: shopItTheme(Brightness.light),
      darkTheme: shopItTheme(Brightness.dark),
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
    final icon = Theme.of(context).brightness == Brightness.dark
        ? iconOnDark
        : iconOnLight;
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
                color: icon,
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
              icon: KeylineIcon(KeylineIcons.settings, color: icon),
              selectedIcon: KeylineIcon(KeylineIcons.settings, color: icon),
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
