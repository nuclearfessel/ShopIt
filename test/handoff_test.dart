import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_it/data/database.dart';
import 'package:shop_it/features/settings/device_link_controller.dart';
import 'package:shop_it/features/settings/list_handoff.dart';

import 'support/harness.dart';

void main() {
  group('stocking the pantry from the cart', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.memory());
    tearDown(() => db.close());

    test(
      'adds a checked item to the only pantry list, and undo removes it',
      () async {
        final groceries = (await db.watchLists().first).single;
        final pantry = (await db.watchPantryLists().first).single;
        await db.addShoppingItem(
          groceries.id,
          'Milk',
          category: 'Dairy & Eggs',
        );
        final milk = (await db.watchShoppingItems(groceries.id).first).single;
        await db.setChecked(milk.id, true);
        final checked =
            (await db.watchShoppingItems(groceries.id).first).single;

        final undo = await db.stockShoppingInPantry([checked], pantry.id);
        final stored = (await db.watchPantry(listId: pantry.id).first).single;
        expect(stored.name, 'Milk');
        expect(stored.level, 'full');
        expect(stored.quantityMode, 'level');

        await db.undoPantryStock(undo);
        expect(await db.watchPantry(listId: pantry.id).first, isEmpty);
      },
    );

    test('a low item becomes full, and undo puts it back to low', () async {
      final groceries = (await db.watchLists().first).single;
      final pantry = (await db.watchPantryLists().first).single;
      await db.addPantryItem('Milk', listId: pantry.id);
      final held = (await db.watchPantry(listId: pantry.id).first).single;
      await db.setPantryLevel(held.id, 'low');
      await db.addShoppingItem(groceries.id, 'Milk');
      final bought = (await db.watchShoppingItems(groceries.id).first).single;

      final undo = await db.stockShoppingInPantry([bought], pantry.id);
      expect(
        (await db.watchPantry(listId: pantry.id).first).single.level,
        'full',
      );
      expect(undo.createdIds, isEmpty);

      await db.undoPantryStock(undo);
      expect(
        (await db.watchPantry(listId: pantry.id).first).single.level,
        'low',
      );
    });

    test('an exact amount increases by what was bought', () async {
      final groceries = (await db.watchLists().first).single;
      final pantry = (await db.watchPantryLists().first).single;
      await db.setPantryQuantityMode(pantry.id, 'number');
      await db.addPantryItem('Rice', quantity: 1, listId: pantry.id);
      await db.addShoppingItem(groceries.id, 'Rice', quantity: 2);
      final bought = (await db.watchShoppingItems(groceries.id).first).single;

      final undo = await db.stockShoppingInPantry([bought], pantry.id);
      expect(
        (await db.watchPantry(listId: pantry.id).first).single.quantity,
        3,
      );
      await db.undoPantryStock(undo);
      expect(
        (await db.watchPantry(listId: pantry.id).first).single.quantity,
        1,
      );
    });

    test('a name already on the shopping list is not added again', () async {
      final groceries = (await db.watchLists().first).single;
      final first = await db.addNameToShoppingList(groceries.id, 'Milk');
      final second = await db.addNameToShoppingList(groceries.id, 'milk');
      expect(first, isNotNull);
      expect(second, isNull);
      expect(await db.watchShoppingItems(groceries.id).first, hasLength(1));
    });
  });

  group('the sync line', () {
    test('stays quiet until lists are shared', () {
      expect(const DeviceLinkState().listLine, '');
    });

    test('says waiting, just now, or the short error', () {
      expect(const DeviceLinkState(sharing: true).listLine, 'Waiting to sync.');
      expect(
        DeviceLinkState(sharing: true, lastWifiSync: DateTime.now()).listLine,
        'Synced just now.',
      );
      expect(
        const DeviceLinkState(
          cloudCode: 'ab.cd',
          cloudError: 'The other device did not answer.',
        ).listLine,
        'The other device did not answer.',
      );
    });
  });

  test('the shopping and pantry offers stay off until turned on', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await loadListHandoff(), isFalse);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(listHandoffProvider), isFalse);
    await container.read(listHandoffProvider.notifier).set(true);
    expect(container.read(listHandoffProvider), isTrue);
    expect(await loadListHandoff(), isTrue);
  });

  testWidgets('the offers stay hidden until Settings turns them on', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pumpShopIt(tester);
    expect(find.text('Add to pantry'), findsNothing);
    expect(find.byTooltip('Add to pantry'), findsNothing);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    SwitchListTile tile() => tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Shopping and pantry'),
    );
    expect(tile().value, isFalse);
    await tester.ensureVisible(find.text('Shopping and pantry'));
    await tester.tap(find.text('Shopping and pantry'));
    await tester.pumpAndSettle();
    expect(tile().value, isTrue);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Add to pantry'), findsOneWidget);
  });

  testWidgets('the cart offers to add checked items to the one pantry', (
    tester,
  ) async {
    await pumpShopIt(tester, listHandoff: true);
    await tester.ensureVisible(find.text('Add to pantry'));
    await tester.tap(find.text('Add to pantry'));
    await tester.pump();
    expect(find.text('Added Eggs to the pantry.'), findsOneWidget);
  });

  testWidgets('more than one pantry list asks which one', (tester) async {
    await pumpShopIt(
      tester,
      listHandoff: true,
      pantryLists: [
        fakeList('p1', 'Kitchen', kind: 'pantry'),
        fakeList('p2', 'Garage', kind: 'pantry'),
      ],
    );
    await tester.ensureVisible(find.text('Add to pantry'));
    await tester.tap(find.text('Add to pantry'));
    await tester.pumpAndSettle();
    expect(find.text('Add to which pantry?'), findsOneWidget);
    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.text('Garage'), findsOneWidget);
  });

  testWidgets('low, empty, and use soon items offer the shopping list', (
    tester,
  ) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    await pumpShopIt(
      tester,
      listHandoff: true,
      pantry: [
        fakePantryItem('a', 'Beans', mode: 'level', level: 'low'),
        fakePantryItem('b', 'Rice', quantity: 0),
        fakePantryItem('c', 'Yogurt', mode: 'level'),
        fakePantryItem(
          'd',
          'Milk',
          mode: 'level',
          expiryDate: start.add(const Duration(days: 1)),
        ),
      ],
    );
    await tester.tap(find.byTooltip('Go to Pantry'));
    await tester.pumpAndSettle();
    expect(find.text('Add to list'), findsNWidgets(3));
    expect(find.text('Add to shopping list'), findsOneWidget);

    await tester.tap(find.text('Add to list').first);
    await tester.pump();
    expect(find.text('Added Beans to Grocery list.'), findsOneWidget);

    await tester.tap(find.text('Add to shopping list'));
    await tester.pump();
    expect(find.text('Added Milk to Grocery list.'), findsOneWidget);
  });
}
