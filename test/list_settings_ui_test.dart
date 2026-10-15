import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/data/database.dart';

import 'support/harness.dart';

ListCategoryOrder _order(String list, String category, int position) =>
    ListCategoryOrder(listId: list, category: category, position: position);

List<String> _headers(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text)))
    if (t.data != null && RegExp(r'^[A-Z][A-Z &]+$').hasMatch(t.data!)) t.data!,
];

void main() {
  final items = [
    fakeItem('a', 'Milk', category: 'Dairy & Eggs'),
    fakeItem('b', 'Bread', category: 'Bakery'),
    fakeItem('c', 'Apples', category: 'Produce'),
  ];

  group('category display follows the list settings', () {
    testWidgets('categories on: headers in the default order', (tester) async {
      await pumpShopIt(tester, items: items);
      expect(_headers(tester).where((h) => h != 'IN YOUR CART'), [
        'PRODUCE',
        'BAKERY',
        'DAIRY & EGGS',
      ]);
    });

    testWidgets('a manual order for the list wins', (tester) async {
      await pumpShopIt(
        tester,
        items: items,
        categoryOrder: [
          _order('l1', 'Dairy & Eggs', 0),
          _order('l1', 'Produce', 1),
        ],
      );
      // Ordered ones first, in the user's order; the rest keep the default.
      expect(_headers(tester), ['DAIRY & EGGS', 'PRODUCE', 'BAKERY']);
    });

    testWidgets('a manual order for another list is ignored', (tester) async {
      await pumpShopIt(
        tester,
        items: items,
        categoryOrder: [_order('other', 'Dairy & Eggs', 0)],
      );
      expect(_headers(tester), ['PRODUCE', 'BAKERY', 'DAIRY & EGGS']);
    });

    testWidgets('categories off: one plain alphabetical list', (tester) async {
      await pumpShopIt(
        tester,
        items: items,
        lists: [fakeList('l1', 'Grocery list', useCategories: false)],
      );
      expect(_headers(tester), isEmpty);
      final top = {
        for (final n in ['Apples', 'Bread', 'Milk'])
          n: tester.getTopLeft(find.text(n)).dy,
      };
      expect(top['Apples']! < top['Bread']!, isTrue);
      expect(top['Bread']! < top['Milk']!, isTrue);
    });

    testWidgets('show empty categories: every header appears', (tester) async {
      await pumpShopIt(
        tester,
        items: [fakeItem('a', 'Milk', category: 'Dairy & Eggs')],
        lists: [fakeList('l1', 'Grocery list', showEmptyCategories: true)],
      );
      expect(_headers(tester), ['PRODUCE', 'BAKERY', 'DAIRY & EGGS']);
    });

    testWidgets('without it, empty categories stay hidden', (tester) async {
      await pumpShopIt(
        tester,
        items: [fakeItem('a', 'Milk', category: 'Dairy & Eggs')],
      );
      expect(_headers(tester), ['DAIRY & EGGS']);
    });

    testWidgets('an empty list still shows its headers when asked to', (
      tester,
    ) async {
      await pumpShopIt(
        tester,
        items: const [],
        lists: [fakeList('l1', 'Grocery list', showEmptyCategories: true)],
      );
      expect(find.text('Nothing to buy'), findsNothing);
      expect(_headers(tester), ['PRODUCE', 'BAKERY', 'DAIRY & EGGS']);
    });
  });

  group('the list menu', () {
    testWidgets('has Out-of-Milk-style entries', (tester) async {
      await pumpShopIt(tester);
      await tester.tap(find.byTooltip('List options'));
      await tester.pumpAndSettle();
      for (final entry in [
        'New list',
        'Check all',
        'Uncheck all',
        'List settings',
        'Manage lists',
        'Delete this list',
      ]) {
        // ("Uncheck all" also exists as a button in the cart section.)
        expect(
          find.widgetWithText(PopupMenuItem<String>, entry),
          findsOneWidget,
          reason: entry,
        );
      }
    });

    testWidgets('List settings opens with the list\'s current values', (
      tester,
    ) async {
      await pumpShopIt(
        tester,
        lists: [
          fakeList(
            'l1',
            'Grocery list',
            autoCategorize: false,
            showEmptyCategories: true,
          ),
        ],
      );
      await tester.tap(find.byTooltip('List options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('List settings'));
      await tester.pumpAndSettle();
      expect(find.text('Settings for "Grocery list"'), findsOneWidget);
      bool on(String title) => tester
          .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
          .value;
      expect(on('Enable categories'), isTrue);
      expect(on('Auto-categorize items'), isFalse);
      expect(on('Show empty categories'), isTrue);
    });

    testWidgets('with categories off the other two switches are disabled', (
      tester,
    ) async {
      await pumpShopIt(
        tester,
        lists: [fakeList('l1', 'Grocery list', useCategories: false)],
      );
      await tester.tap(find.byTooltip('List options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('List settings'));
      await tester.pumpAndSettle();
      SwitchListTile tile(String t) =>
          tester.widget(find.widgetWithText(SwitchListTile, t));
      expect(tile('Enable categories').onChanged, isNotNull);
      expect(tile('Auto-categorize items').onChanged, isNull);
      expect(tile('Show empty categories').onChanged, isNull);
    });

    testWidgets(
      'Manage lists shows each list with rename, delete and a handle',
      (tester) async {
        await pumpShopIt(
          tester,
          lists: [fakeList('l1', 'Grocery list'), fakeList('l2', 'Party')],
        );
        await tester.tap(find.byTooltip('List options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Manage lists'));
        await tester.pumpAndSettle();
        expect(find.text('Manage lists'), findsOneWidget);
        expect(find.text('Party'), findsWidgets);
        expect(find.byTooltip('Rename list'), findsNWidgets(2));
        expect(find.byTooltip('Delete list'), findsNWidgets(2));
        expect(find.byTooltip('Drag to reorder'), findsNWidgets(2));
        expect(find.byType(ReorderableListView), findsOneWidget);
      },
    );
  });
}
