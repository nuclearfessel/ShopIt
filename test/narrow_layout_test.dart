import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/app/app.dart';
import 'package:shop_it/data/database.dart';
import 'package:shop_it/data/providers.dart';

final _t = DateTime(2026, 1, 1);
const _longName = 'Extra mature cheddar cheese block family size';

final _list = ShoppingList(id: 'l1', updatedAt: _t, name: 'Groceries');

ShoppingItem _item(String id, String name, {bool checked = false}) =>
    ShoppingItem(
        id: id,
        updatedAt: _t,
        listId: 'l1',
        name: name,
        quantity: 1,
        unit: '',
        checked: checked,
        category: 'Dairy & Eggs',
        price: 3.5,
        note: 'Brand X, the blue one, check for a coupon first');

CatalogItem _cat(String name, {String parent = ''}) => CatalogItem(
    id: name,
    updatedAt: _t,
    name: name,
    category: 'Produce',
    defaultUnit: '',
    isCustom: false,
    parentName: parent);

/// Scrolls the (last) list until [finder] is built; rows far below the fold
/// aren't built by the lazy list.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 12 && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).last, const Offset(0, -250));
    await tester.pump();
  }
}

/// Renders the app at several window widths and fails on any layout overflow.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  for (final width in [900.0, 600.0, 420.0, 320.0, 240.0]) {
    testWidgets('no layout overflow at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          // Never opened: the providers below replace every query.
          databaseProvider.overrideWithValue(AppDatabase.memory()),
          listsProvider.overrideWith((_) => Stream.value([_list])),
          categoriesProvider.overrideWith((_) => Stream.value(
              [Category(name: 'Dairy & Eggs', sortOrder: 0)])),
          shoppingItemsProvider.overrideWith((ref, id) => Stream.value([
                _item('a', _longName),
                _item('b', 'Milk'),
                _item('c', 'Eggs', checked: true),
              ])),
          pantryProvider.overrideWith((_) => Stream.value([
                PantryItem(
                    id: 'p1',
                    updatedAt: _t,
                    name: _longName,
                    quantity: 12.5,
                    unit: 'family packets',
                    expiryDate: DateTime.now().add(const Duration(days: 2)),
                    location: 'Fridge, top shelf, at the back',
                    category: 'Dairy & Eggs',
                    note: 'Opened last week, use for the pasta bake'),
              ])),
          catalogSearchProvider.overrideWith((ref, q) async => [
                _cat('Onions'),
                _cat('Yellow onions', parent: 'Onions'),
                _cat('Caramelised extra sweet spring onions', parent: 'Onions'),
              ]),
        ],
        child: const ShopItApp(windowChrome: false),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'shopping screen');

      await tester.enterText(find.byType(TextField).first, 'onion');
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'shopping suggestions');

      // Clear the search so the suggestions don't push the list off screen.
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump(const Duration(milliseconds: 300));

      // Item details sheet from the shopping list.
      await _reveal(tester, find.text('Milk'));
      await tester.tap(find.text('Milk'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'shopping item editor');
      expect(find.text('Edit item'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pantry').last);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500)); // stream emits
      expect(tester.takeException(), isNull, reason: 'pantry screen');

      // Item details sheet from the pantry.
      expect(find.text(_longName), findsOneWidget, reason: 'pantry row shown');
      await tester.tap(find.text(_longName));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'pantry item editor');
      expect(find.text('Edit pantry item'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'add pantry dialog');
    });
  }
}
