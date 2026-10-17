import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/data/database.dart';
import 'package:shop_it/ui/choice_field.dart';

import 'support/harness.dart';

Future<void> _openMenu(WidgetTester tester, String entry) async {
  await tester.tap(find.byTooltip('List options'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(PopupMenuItem<String>, entry));
  await tester.pumpAndSettle();
}

Future<void> _gotoPantry(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Go to Pantry'));
  await tester.pumpAndSettle();
}

final _dialogPicker = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(ChoiceField<String>),
);

void main() {
  group('database: pantry lists', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.memory());
    tearDown(() => db.close());

    Future<ShoppingList> firstPantry() async =>
        (await db.watchPantryLists().first).first;

    test('a new database has one shopping list and one pantry list', () async {
      expect((await db.watchLists().first).map((l) => l.name), ['Groceries']);
      expect((await db.watchPantryLists().first).map((l) => l.name), [
        'Pantry',
      ]);
    });

    test('shopping and pantry lists stay apart', () async {
      await db.addList('Party');
      await db.addList('Garage', kind: 'pantry');
      expect((await db.watchLists().first).map((l) => l.name), [
        'Groceries',
        'Party',
      ]);
      expect((await db.watchPantryLists().first).map((l) => l.name), [
        'Pantry',
        'Garage',
      ]);
    });

    test('"delete all lists" leaves the pantry lists alone', () async {
      await db.addList('Garage', kind: 'pantry');
      await db.deleteAllLists();
      expect(await db.watchLists().first, isEmpty);
      expect(await db.watchPantryLists().first, hasLength(2));
    });

    test('deleting a pantry list removes its items', () async {
      final garage = await db.addList('Garage', kind: 'pantry');
      await db.addPantryItem('Paint', listId: garage);
      await db.addPantryItem('Rice'); // the first pantry list
      await db.deleteList(garage);
      expect((await db.watchPantry().first).map((i) => i.name), ['Rice']);
    });

    test('items go to the first pantry list unless told otherwise', () async {
      final garage = await db.addList('Garage', kind: 'pantry');
      final pantry = await firstPantry();
      await db.addPantryItem('Rice');
      await db.addPantryItem('Paint', listId: garage);
      expect(
        (await db.watchPantry(listId: pantry.id).first).map((i) => i.name),
        ['Rice'],
      );
      expect((await db.watchPantry(listId: garage).first).map((i) => i.name), [
        'Paint',
      ]);
      expect(await db.watchPantry().first, hasLength(2)); // all lists
    });

    test('pantry lists can be renamed and reordered like any list', () async {
      final garage = await db.addList('Garage', kind: 'pantry');
      final pantry = await firstPantry();
      await db.renameList(pantry.id, 'Kitchen');
      await db.reorderLists([garage, pantry.id]);
      expect((await db.watchPantryLists().first).map((l) => l.name), [
        'Garage',
        'Kitchen',
      ]);
    });
  });

  group('database: Low/Full and exact amounts', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.memory());
    tearDown(() => db.close());

    test('new items start as Low/Full, full', () async {
      await db.addPantryItem('Rice');
      final i = (await db.watchPantry().first).single;
      expect((i.quantityMode, i.level), ('level', 'full'));
    });

    test('an item can be marked low and full again', () async {
      await db.addPantryItem('Rice');
      final id = (await db.watchPantry().first).single.id;
      await db.setPantryLevel(id, 'low');
      expect((await db.watchPantry().first).single.level, 'low');
      await db.setPantryLevel(id, 'full');
      expect((await db.watchPantry().first).single.level, 'full');
    });

    test('"Apply to all" changes every item and what new items use', () async {
      final list = (await db.watchPantryLists().first).first;
      await db.addPantryItem('Rice');
      await db.addPantryItem('Beans');
      await db.setPantryQuantityMode(list.id, 'number');
      var items = await db.watchPantry().first;
      expect(items.every((i) => i.quantityMode == 'number'), isTrue);

      await db.addPantryItem('Oats'); // added after the setting
      items = await db.watchPantry().first;
      expect(items.every((i) => i.quantityMode == 'number'), isTrue);

      await db.setPantryQuantityMode(list.id, 'level');
      items = await db.watchPantry().first;
      expect(items.every((i) => i.quantityMode == 'level'), isTrue);
    });

    test('"Apply to all" only touches that list', () async {
      final a = (await db.watchPantryLists().first).first;
      final b = await db.addList('Garage', kind: 'pantry');
      await db.addPantryItem('Rice', listId: a.id);
      await db.addPantryItem('Paint', listId: b);
      await db.setPantryQuantityMode(a.id, 'number');
      expect(
        (await db.watchPantry(listId: a.id).first).single.quantityMode,
        'number',
      );
      expect(
        (await db.watchPantry(listId: b).first).single.quantityMode,
        'level',
      );
    });

    test('one item can differ from its list', () async {
      final list = (await db.watchPantryLists().first).first;
      await db.addPantryItem('Rice');
      await db.addPantryItem('Beans');
      final rice = (await db.watchPantry().first).firstWhere(
        (i) => i.name == 'Rice',
      );
      await db.setPantryItemMode(rice.id, 'number');
      final items = {
        for (final i in await db.watchPantry(listId: list.id).first)
          i.name: i.quantityMode,
      };
      expect(items, {'Rice': 'number', 'Beans': 'level'});
    });

    test('the editor can save the mode and level', () async {
      await db.addPantryItem('Rice');
      final i = (await db.watchPantry().first).single;
      await db.updatePantryItem(
        i.id,
        name: 'Rice',
        quantity: 4,
        unit: 'kg',
        category: 'Pasta, Rice & Grains',
        location: 'Shelf',
        note: '',
        quantityMode: 'level',
        level: 'low',
      );
      final saved = (await db.watchPantry().first).single;
      expect(
        (saved.quantityMode, saved.level, saved.quantity),
        ('level', 'low', 4.0),
      );
    });
  });

  group('database: moving and copying pantry items', () {
    late AppDatabase db;
    late ShoppingList pantry;
    late String garage;
    late ShoppingList groceries;

    setUp(() async {
      db = AppDatabase.memory();
      pantry = (await db.watchPantryLists().first).first;
      garage = await db.addList('Garage', kind: 'pantry');
      groceries = (await db.watchLists().first).first;
      await db.addPantryItem(
        'Rice',
        quantity: 3,
        unit: 'kg',
        category: 'Pasta, Rice & Grains',
        location: 'Shelf',
      );
    });
    tearDown(() => db.close());

    Future<PantryItem> rice() async =>
        (await db.watchPantry(listId: pantry.id).first).single;

    test('moving to another pantry list, and undo', () async {
      final r = await rice();
      final before = await db.movePantryItems([r.id], garage);
      expect(before, {r.id: pantry.id});
      expect(await db.watchPantry(listId: pantry.id).first, isEmpty);
      expect((await db.watchPantry(listId: garage).first).single.id, r.id);
      await db.restorePantryLists(before);
      expect((await db.watchPantry(listId: pantry.id).first).single.id, r.id);
    });

    test('copying keeps every detail, including Low/Full', () async {
      final r = await rice();
      await db.setPantryLevel(r.id, 'low');
      final created = await db.copyPantryItems([await rice()], garage);
      final copy = (await db.watchPantry(listId: garage).first).single;
      expect(copy.id, created.single);
      expect(
        (copy.name, copy.quantity, copy.unit, copy.location, copy.level),
        ('Rice', 3.0, 'kg', 'Shelf', 'low'),
      );
      expect(await db.watchPantry(listId: pantry.id).first, hasLength(1));
    });

    test(
      'moving to a shopping list restocks it, and undo reverses it',
      () async {
        final r = await rice();
        final created = await db.copyPantryToShopping([r], groceries.id);
        await db.deletePantryItems([r.id]);
        expect(await db.watchPantry(listId: pantry.id).first, isEmpty);
        final shop = (await db.watchShoppingItems(groceries.id).first).single;
        expect(
          (shop.id, shop.name, shop.quantity, shop.unit),
          (created.single, 'Rice', 3.0, 'kg'),
        );

        await db.deleteShoppingItems(created);
        await db.restorePantryItems([r.id]);
        expect(await db.watchShoppingItems(groceries.id).first, isEmpty);
        expect(await db.watchPantry(listId: pantry.id).first, hasLength(1));
      },
    );

    test('a shopping item can go to a chosen pantry list', () async {
      final id = await db.addShoppingItem(
        groceries.id,
        'Paint',
        quantity: 2,
        unit: 'cans',
      );
      final item = (await db.watchShoppingItems(groceries.id).first).firstWhere(
        (i) => i.id == id,
      );
      await db.copyShoppingToPantry([item], listId: garage);
      final p = (await db.watchPantry(listId: garage).first).single;
      expect(
        (p.name, p.quantity, p.unit, p.quantityMode),
        (
          'Paint',
          2.0,
          'cans',
          'number', // shopping amounts are exact
        ),
      );
    });
  });

  group('the pantry screen', () {
    final items = [
      fakePantryItem('a', 'Yogurt', mode: 'level'),
      fakePantryItem('b', 'Rice', category: 'Bakery'),
      fakePantryItem('c', 'Beans', mode: 'level', level: 'low'),
    ];

    testWidgets('one list: just its name; two: a pull-down', (tester) async {
      await pumpShopIt(tester, pantry: items);
      await _gotoPantry(tester);
      expect(find.text('Pantry'), findsWidgets);
      expect(find.byTooltip('Choose a pantry list'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpShopIt(
        tester,
        pantry: items,
        pantryLists: [
          fakeList('p1', 'Pantry', kind: 'pantry'),
          fakeList('p2', 'Garage', kind: 'pantry'),
        ],
      );
      await _gotoPantry(tester);
      expect(find.byTooltip('Choose a pantry list'), findsOneWidget);
    });

    testWidgets('only shows the items of the chosen list', (tester) async {
      await pumpShopIt(
        tester,
        pantry: [
          fakePantryItem('a', 'Yogurt'),
          fakePantryItem('b', 'Paint', listId: 'p2'),
        ],
        pantryLists: [
          fakeList('p1', 'Pantry', kind: 'pantry'),
          fakeList('p2', 'Garage', kind: 'pantry'),
        ],
      );
      await _gotoPantry(tester);
      expect(find.text('Yogurt'), findsOneWidget);
      expect(find.text('Paint'), findsNothing);
      await tester.tap(find.byType(ChoiceField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Garage').last);
      await tester.pumpAndSettle();
      expect(find.text('Paint'), findsOneWidget);
      expect(find.text('Yogurt'), findsNothing);
    });

    testWidgets('use soon lists items expiring within a week', (tester) async {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day);
      await pumpShopIt(
        tester,
        pantry: [
          fakePantryItem(
            'a',
            'Yogurt',
            expiryDate: start.add(const Duration(days: 2)),
          ),
          fakePantryItem(
            'b',
            'Rice',
            expiryDate: start.add(const Duration(days: 40)),
          ),
          fakePantryItem(
            'c',
            'Milk',
            expiryDate: start.subtract(const Duration(days: 1)),
          ),
        ],
      );
      await _gotoPantry(tester);
      expect(find.text('USE SOON'), findsOneWidget);
      expect(find.textContaining('Yogurt (in 2 days)'), findsOneWidget);
      expect(find.textContaining('Milk (expired)'), findsOneWidget);
      expect(find.textContaining('Rice ('), findsNothing);
      expect(find.text('Rice'), findsOneWidget);
    });

    testWidgets('groups the items under category headers', (tester) async {
      await pumpShopIt(tester, pantry: items);
      await _gotoPantry(tester);
      expect(find.text('DAIRY & EGGS'), findsOneWidget);
      expect(find.text('BAKERY'), findsOneWidget);
    });

    testWidgets('Low/Full items get a toggle, numbered items a stepper', (
      tester,
    ) async {
      await pumpShopIt(tester, pantry: items);
      await _gotoPantry(tester);
      // two Low/Full items: Yogurt and Beans
      expect(find.byType(SegmentedButton<String>), findsNWidgets(2));
      expect(find.byTooltip('Running low: time to restock'), findsNWidgets(2));
      // one numbered item: Rice
      expect(find.byTooltip('Increase'), findsOneWidget);
      expect(find.byTooltip('Decrease'), findsOneWidget);
    });

    testWidgets('the toggle shows what is low and what is full', (
      tester,
    ) async {
      await pumpShopIt(tester, pantry: items);
      await _gotoPantry(tester);
      final selected = [
        for (final s in tester.widgetList<SegmentedButton<String>>(
          find.byType(SegmentedButton<String>),
        ))
          s.selected.single,
      ];
      expect(selected.toSet(), {'full', 'low'});
    });

    testWidgets('has the pantry list menu entries', (tester) async {
      await pumpShopIt(tester, pantry: items);
      await _gotoPantry(tester);
      await tester.tap(find.byTooltip('List options'));
      await tester.pumpAndSettle();
      for (final e in [
        'Create new list',
        'Move/Copy items',
        'Amounts',
        'Manage categories',
        'Manage lists',
        'Delete this list',
      ]) {
        expect(
          find.widgetWithText(PopupMenuItem<String>, e),
          findsOneWidget,
          reason: e,
        );
      }
    });

    testWidgets('Amounts opens with the list\'s current choice', (
      tester,
    ) async {
      await pumpShopIt(
        tester,
        pantry: items,
        pantryLists: [
          fakeList('p1', 'Pantry', kind: 'pantry', quantityMode: 'number'),
        ],
      );
      await _gotoPantry(tester);
      await _openMenu(tester, 'Amounts');
      expect(find.text('Amounts for "Pantry"'), findsOneWidget);
      expect(find.text('Low or stocked'), findsOneWidget);
      expect(find.text('Exact amounts'), findsOneWidget);
      expect(find.text('Apply to all'), findsOneWidget);
    });

    testWidgets('Manage lists manages the pantry lists', (tester) async {
      await pumpShopIt(
        tester,
        pantry: items,
        pantryLists: [
          fakeList('p1', 'Pantry', kind: 'pantry'),
          fakeList('p2', 'Garage', kind: 'pantry'),
        ],
      );
      await _gotoPantry(tester);
      await _openMenu(tester, 'Manage lists');
      expect(find.text('Manage pantry lists'), findsOneWidget);
      expect(find.byTooltip('Rename list'), findsNWidgets(2));
    });

    testWidgets('Move/Copy offers the shopping lists and other pantry lists', (
      tester,
    ) async {
      await pumpShopIt(
        tester,
        pantry: items,
        lists: [fakeList('l1', 'Grocery list'), fakeList('l2', 'Party')],
        pantryLists: [
          fakeList('p1', 'Pantry', kind: 'pantry'),
          fakeList('p2', 'Garage', kind: 'pantry'),
        ],
      );
      await _gotoPantry(tester);
      await _openMenu(tester, 'Move/Copy items');
      expect(find.text('Move or copy items'), findsOneWidget);
      await tester.tap(_dialogPicker);
      await tester.pumpAndSettle();
      final offered = tester
          .widget<ChoiceField<String>>(_dialogPicker)
          .choices
          .map((c) => c.label)
          .toList();
      expect(offered, ['Grocery list', 'Party', 'Garage']);
    });

    testWidgets('an empty pantry list says so', (tester) async {
      await pumpShopIt(tester, pantry: const []);
      await _gotoPantry(tester);
      expect(find.text('Pantry is empty'), findsOneWidget);
    });

    testWidgets('no pantry lists at all: offers to create one', (tester) async {
      await pumpShopIt(tester, pantryLists: const []);
      await _gotoPantry(tester);
      expect(find.text('No pantry lists yet'), findsOneWidget);
      expect(find.text('Create a pantry list'), findsOneWidget);
    });

    testWidgets('fits the narrowest window with both kinds of amount', (
      tester,
    ) async {
      await pumpShopIt(tester, width: 240, pantry: items);
      await _gotoPantry(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('the item editor for pantry items', () {
    testWidgets('lets you choose Low/Full or a number', (tester) async {
      await pumpShopIt(
        tester,
        pantry: [fakePantryItem('a', 'Yogurt', mode: 'level')],
      );
      await _gotoPantry(tester);
      await tester.tap(find.text('Yogurt'));
      await tester.pumpAndSettle();
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('Low or stocked'), findsOneWidget);
      expect(find.text('Number'), findsOneWidget);
      // Low / Full mode: the Low and Full buttons, not the quantity stepper
      // (the pantry row behind the editor has its own Low/Full toggle)
      Finder inEditor(String t) =>
          find.descendant(of: find.byType(Dialog), matching: find.text(t));
      expect(inEditor('Low'), findsOneWidget);
      expect(inEditor('Full'), findsOneWidget);
      expect(find.byTooltip('More'), findsNothing);
    });

    testWidgets('number mode shows the quantity stepper instead', (
      tester,
    ) async {
      await pumpShopIt(tester, pantry: [fakePantryItem('a', 'Rice')]);
      await _gotoPantry(tester);
      await tester.tap(find.text('Rice'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('More'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text('Low')),
        findsNothing,
      );
    });

    testWidgets('switching to Number reveals the stepper', (tester) async {
      await pumpShopIt(
        tester,
        pantry: [fakePantryItem('a', 'Yogurt', mode: 'level')],
      );
      await _gotoPantry(tester);
      await tester.tap(find.text('Yogurt'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Track an exact quantity'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('More'), findsOneWidget);
    });

    testWidgets('shopping items have no Amount choice', (tester) async {
      await pumpShopIt(tester);
      await tester.tap(find.text('Milk'));
      await tester.pumpAndSettle();
      expect(find.text('Amount'), findsNothing);
      expect(find.byTooltip('More'), findsOneWidget);
    });
  });
}
