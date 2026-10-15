import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/pantry/pantry_screen.dart';
import '../features/shopping/shopping_screen.dart';

final _router = GoRouter(
  initialLocation: '/shopping',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/shopping', builder: (_, _) => const ShoppingScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/pantry', builder: (_, _) => const PantryScreen()),
        ]),
      ],
    ),
  ],
);

class ShopItApp extends StatelessWidget {
  const ShopItApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Shop-it',
        theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
        darkTheme: ThemeData(
            colorSchemeSeed: Colors.green,
            brightness: Brightness.dark,
            useMaterial3: true),
        routerConfig: _router,
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
        body: Row(children: [
          NavigationRail(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _go,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                    icon: Icon(d.$1),
                    selectedIcon: Icon(d.$2),
                    label: Text(d.$3)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: shell),
        ]),
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
                icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
        ],
      ),
    );
  }
}
