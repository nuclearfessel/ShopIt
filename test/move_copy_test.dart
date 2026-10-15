import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/data/database.dart';
import 'package:shop_it/ui/choice_field.dart';

import 'support/harness.dart';

Future<void> _openMoveCopy(WidgetTester tester) async {
  await tester.tap(find.byTooltip('List options'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.widgetWithText(PopupMenuItem<String>, 'Move/Copy items'),
  );
  await tester.pumpAndSettle();
}

FilledButton _move(WidgetTester t) =>
    t.widget(find.widgetWithText(FilledButton, 'Move'));
OutlinedButton _copy(WidgetTester t) =>
    t.widget(find.widgetWithText(OutlinedButton, 'Copy'));

final _dialogPicker = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(ChoiceField<String>),
);

void main() {
  group('database: moving and copying', () {
    late AppDatabase db;
    late ShoppingList groceries;
    late ShoppingList party;

    setUp(() async {
      db = AppDatabase.memory();
      groceries = (await db.watchLists().first).single;
      await db.addList('Party');
      party = (await db.watchLists().first).last;
    });
    tearDown(() => db.close());

    Future<ShoppingItem> add(String name, {String cat = 'Snacks'}) async {
      final id = await db.addShoppingItem(
        groceries.id,
        name,
        quantity: 3,
        unit: 'bag',
        category: cat,
      );
      await db.updateShoppingItem(
        id,
        name: name,
        quantity: 3,
        unit: 'bag',
        category: cat,
        price: 2.5,
        note: 'Salted',
        taxable: true,
        hasCoupon: true,
      );
      return (await db.watchShoppingItems(groceries.id).first).firstWhere(
        (i) => i.id == id,
      );
    }

    test('moving changes the list, and undo puts it back', () async {
      final chips = await add('Chips');
      final dip = await add('Dip');
      final before = await db.moveShoppingItems([chips.id, dip.id], party.id);
      expect(before, {chips.id: groceries.id, dip.id: groceries.id});
      expect(await db.watchShoppingItems(groceries.id).first, isEmpty);
      expect(
        (await db.watchShoppingItems(party.id).first)
            .map((i) => i.name)
            .toSet(),
        {'Chips', 'Dip'},
      );

      await db.restoreShoppingLists(before);
      expect(await db.watchShoppingItems(party.id).first, isEmpty);
      expect(await db.watchShoppingItems(groceries.id).first, hasLength(2));
    });

    test('moving keeps every detail of the item', () async {
      final chips = await add('Chips');
      await db.moveShoppingItems([chips.id], party.id);
      final moved = (await db.watchShoppingItems(party.id).first).single;
      expect(
        (moved.id, moved.quantity, moved.unit, moved.price, moved.note),
        (chips.id, 3.0, 'bag', 2.5, 'Salted'),
      );
      expect((moved.taxable, moved.hasCoupon), (true, true));
    });

    test('copying leaves the original and arrives unchecked', () async {
      final chips = await add('Chips');
      await db.setChecked(chips.id, true);
      final checked = (await db.watchShoppingItems(groceries.id).first).single;
      final created = await db.copyShoppingItems([checked], party.id);
      expect(created, hasLength(1));
      expect(await db.watchShoppingItems(groceries.id).first, hasLength(1));
      final copy = (await db.watchShoppingItems(party.id).first).single;
      expect(copy.id, isNot(chips.id));
      expect(copy.checked, isFalse);
      expect(
        (copy.name, copy.quantity, copy.unit, copy.price, copy.note),
        ('Chips', 3.0, 'bag', 2.5, 'Salted'),
      );
      // undoing a copy removes just the copy
      await db.deleteShoppingItems(created);
      expect(await db.watchShoppingItems(party.id).first, isEmpty);
      expect(await db.watchShoppingItems(groceries.id).first, hasLength(1));
    });

    test(
      'moving to the pantry: new pantry item, gone from the list, undoable',
      () async {
        final chips = await add('Chips');
        final created = await db.copyShoppingToPantry([chips]);
        await db.deleteShoppingItems([chips.id]); // the "move" part
        expect(await db.watchShoppingItems(groceries.id).first, isEmpty);
        final p = (await db.watchPantry().first).single;
        expect(
          (p.id, p.name, p.quantity, p.unit, p.category, p.note),
          (created.single, 'Chips', 3.0, 'bag', 'Snacks', 'Salted'),
        );

        // undo
        await db.deletePantryItems(created);
        await db.restoreItems([chips.id]);
        expect(await db.watchPantry().first, isEmpty);
        expect(await db.watchShoppingItems(groceries.id).first, hasLength(1));
      },
    );

    test('pantry items can be copied to a shopping list to restock', () async {
      await db.addPantryItem(
        'Rice',
        quantity: 1,
        unit: 'kg',
        category: 'Pasta, Rice & Grains',
      );
      final rice = (await db.watchPantry().first).single;
      final created = await db.copyPantryToShopping([rice], groceries.id);
      expect(created, hasLength(1));
      final item = (await db.watchShoppingItems(groceries.id).first).single;
      expect(
        (item.name, item.quantity, item.unit, item.category, item.checked),
        ('Rice', 1.0, 'kg', 'Pasta, Rice & Grains', false),
      );
      expect(await db.watchPantry().first, hasLength(1)); // still in the pantry
    });

    test('deleted pantry items can be restored', () async {
      await db.addPantryItem('Rice');
      final rice = (await db.watchPantry().first).single;
      await db.deletePantryItems([rice.id]);
      expect(await db.watchPantry().first, isEmpty);
      await db.restorePantryItems([rice.id]);
      expect(await db.watchPantry().first, hasLength(1));
    });

    test('a list can be moved to even when it holds nothing', () async {
      expect(await db.moveShoppingItems(const [], party.id), isEmpty);
      expect(await db.copyShoppingItems(const [], party.id), isEmpty);
    });
  });

  group('the Move/Copy dialog', () {
    final lists = [fakeList('l1', 'Grocery list'), fakeList('l2', 'Party')];
    final items = [
      fakeItem('a', 'Milk'),
      fakeItem('b', 'Bread', category: 'Bakery'),
      fakeItem('c', 'Eggs', checked: true),
    ];

    testWidgets('lists every item, including ones already in the cart', (
      tester,
    ) async {
      await pumpShopIt(tester, lists: lists, items: items);
      await _openMoveCopy(tester);
      expect(find.text('Move or copy items'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
      expect(find.text('0 of 3 selected'), findsOneWidget);
    });

    testWidgets('Move and Copy wait for a selection and a destination', (
      tester,
    ) async {
      await pumpShopIt(tester, lists: lists, items: items);
      await _openMoveCopy(tester);
      expect(_move(tester).onPressed, isNull);
      expect(_copy(tester).onPressed, isNull);

      // items alone are not enough...
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Milk'));
      await tester.pump();
      expect(_move(tester).onPressed, isNull);

      // ...and neither is a destination alone
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Milk'));
      await tester.pump();
      await tester.tap(_dialogPicker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Party').last);
      await tester.pumpAndSettle();
      expect(_move(tester).onPressed, isNull);

      // both: ready
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Milk'));
      await tester.pump();
      expect(_move(tester).onPressed, isNotNull);
      expect(_copy(tester).onPressed, isNotNull);
      expect(find.text('1 of 3 selected'), findsOneWidget);
    });

    testWidgets('Select all and Select none', (tester) async {
      await pumpShopIt(tester, lists: lists, items: items);
      await _openMoveCopy(tester);
      await tester.tap(find.text('Select all'));
      await tester.pump();
      expect(find.text('3 of 3 selected'), findsOneWidget);
      await tester.tap(find.text('Select none'));
      await tester.pump();
      expect(find.text('0 of 3 selected'), findsOneWidget);
    });

    testWidgets('destinations are the other lists and the pantry', (
      tester,
    ) async {
      await pumpShopIt(
        tester,
        lists: [...lists, fakeList('l3', 'Costco')],
        items: items,
      );
      await _openMoveCopy(tester);
      await tester.tap(_dialogPicker);
      await tester.pumpAndSettle();
      for (final name in ['Party', 'Costco', 'Pantry']) {
        expect(find.text(name), findsWidgets, reason: name);
      }
      // The dialog's own pull-down offers the other lists and the pantry, but
      // not the list you are on.
      final offered = tester
          .widget<ChoiceField<String>>(_dialogPicker)
          .choices
          .map((c) => c.label)
          .toList();
      expect(offered, ['Party', 'Costco', 'Pantry']);
    });

    testWidgets('with only one list the pantry is the destination', (
      tester,
    ) async {
      await pumpShopIt(tester, items: items);
      await _openMoveCopy(tester);
      await tester.tap(_dialogPicker);
      await tester.pumpAndSettle();
      expect(find.text('Pantry'), findsWidgets);
    });

    testWidgets('an empty list says so and offers nothing to select', (
      tester,
    ) async {
      await pumpShopIt(tester, items: const []);
      await _openMoveCopy(tester);
      expect(find.text('This list has no items yet.'), findsOneWidget);
      final selectAll = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Select all'),
      );
      expect(selectAll.onPressed, isNull);
    });

    testWidgets('Cancel closes it', (tester) async {
      await pumpShopIt(tester, lists: lists, items: items);
      await _openMoveCopy(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Move or copy items'), findsNothing);
    });

    testWidgets('fits a narrow window', (tester) async {
      await pumpShopIt(tester, width: 240, lists: lists, items: items);
      await _openMoveCopy(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
