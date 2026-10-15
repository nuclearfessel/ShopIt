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
        category: 'Dairy & Eggs');

CatalogItem _cat(String name, {String parent = ''}) => CatalogItem(
    id: name,
    updatedAt: _t,
    name: name,
    category: 'Produce',
    defaultUnit: '',
    isCustom: false,
    parentName: parent);

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
                    category: 'Dairy & Eggs'),
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

      await tester.tap(find.text('Pantry').last);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'pantry screen');

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'add pantry dialog');
    });
  }
}
