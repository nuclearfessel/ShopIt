import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/data/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<ShoppingList> firstList() async => (await db.watchLists().first).first;

  group('lists', () {
    test('new lists go at the end, in creation order', () async {
      await db.addList('Costco');
      await db.addList('Party');
      expect((await db.watchLists().first).map((l) => l.name), [
        'Groceries',
        'Costco',
        'Party',
      ]);
    });

    test('a list can be renamed', () async {
      final l = await firstList();
      await db.renameList(l.id, 'Weekly shop');
      expect((await firstList()).name, 'Weekly shop');
    });

    test('lists can be reordered and the order is remembered', () async {
      await db.addList('B');
      await db.addList('C');
      final ids = {for (final l in await db.watchLists().first) l.name: l.id};
      await db.reorderLists([ids['C']!, ids['Groceries']!, ids['B']!]);
      expect((await db.watchLists().first).map((l) => l.name), [
        'C',
        'Groceries',
        'B',
      ]);
    });

    test('list settings default on/on/off and change independently', () async {
      var l = await firstList();
      expect(
        (l.useCategories, l.autoCategorize, l.showEmptyCategories),
        (true, true, false),
      );
      await db.updateListSettings(l.id, autoCategorize: false);
      l = await firstList();
      expect(
        (l.useCategories, l.autoCategorize, l.showEmptyCategories),
        (true, false, false),
      );
      await db.updateListSettings(l.id, showEmptyCategories: true);
      await db.updateListSettings(l.id, useCategories: false);
      l = await firstList();
      expect(
        (l.useCategories, l.autoCategorize, l.showEmptyCategories),
        (false, false, true),
      );
    });

    test('check all puts every open item in the cart', () async {
      final l = await firstList();
      await db.addShoppingItem(l.id, 'Milk', category: 'Dairy & Eggs');
      await db.addShoppingItem(l.id, 'Bread', category: 'Bakery');
      await db.checkAll(l.id);
      expect(
        (await db.watchShoppingItems(l.id).first).every((i) => i.checked),
        isTrue,
      );
      await db.uncheckAll(l.id);
      expect(
        (await db.watchShoppingItems(l.id).first).any((i) => i.checked),
        isFalse,
      );
    });
  });

  group('categories', () {
    test('a category can be added once, ignoring case', () async {
      await db.addCategory('Gluten free');
      await db.addCategory('gluten FREE');
      await db.addCategory('   ');
      final names = (await db.watchCategories().first).map((c) => c.name);
      expect(names.where((n) => n.toLowerCase() == 'gluten free'), [
        'Gluten free',
      ]);
      // added at the end of the default order
      expect(names.last, 'Gluten free');
    });

    test('a category colour can be set and cleared', () async {
      await db.setCategoryColor('Produce', 0xFF112233);
      var c = (await db.watchCategories().first).firstWhere(
        (c) => c.name == 'Produce',
      );
      expect(c.color, 0xFF112233);
      await db.setCategoryColor('Produce', null);
      c = (await db.watchCategories().first).firstWhere(
        (c) => c.name == 'Produce',
      );
      expect(c.color, isNull);
    });

    test('deleting a category frees its items and catalog entries', () async {
      final l = await firstList();
      await db.addShoppingItem(l.id, 'Milk', category: 'Dairy & Eggs');
      await db.addPantryItem('Yogurt', category: 'Dairy & Eggs');
      await db.setListCategoryOrder(l.id, ['Dairy & Eggs', 'Produce']);

      await db.deleteCategory('Dairy & Eggs');

      expect(
        (await db.watchCategories().first).map((c) => c.name),
        isNot(contains('Dairy & Eggs')),
      );
      expect((await db.watchShoppingItems(l.id).first).single.category, '');
      expect((await db.watchPantry().first).single.category, '');
      expect((await db.searchCatalog('milk')).first.category, 'Other');
      expect(
        (await db.watchListCategoryOrder(l.id).first).map((o) => o.category),
        ['Produce'],
      );
    });

    test('"Other" cannot be deleted', () async {
      await db.deleteCategory('Other');
      expect(
        (await db.watchCategories().first).map((c) => c.name),
        contains('Other'),
      );
    });

    test('a list keeps its own manual category order', () async {
      final a = await firstList();
      await db.addList('B');
      final b = (await db.watchLists().first).last;
      await db.setListCategoryOrder(a.id, [
        'Bakery',
        'Produce',
        'Dairy & Eggs',
      ]);
      await db.setListCategoryOrder(b.id, ['Produce']);
      expect(
        (await db.watchListCategoryOrder(a.id).first).map((o) => o.category),
        ['Bakery', 'Produce', 'Dairy & Eggs'],
      );
      expect(
        (await db.watchListCategoryOrder(b.id).first).map((o) => o.category),
        ['Produce'],
      );
      // replacing the order replaces it completely
      await db.setListCategoryOrder(a.id, ['Dairy & Eggs']);
      expect((await db.watchListCategoryOrder(a.id).first).length, 1);
    });

    test('assigning a category is remembered for next time', () async {
      final l = await firstList();
      await db.addShoppingItem(l.id, 'Kombucha', category: 'Other');
      await db.assignCategory('kombucha', 'Beverages');
      expect((await db.searchCatalog('kombucha')).single.category, 'Beverages');
      // a built-in item can be re-filed too
      await db.assignCategory('Milk', 'Beverages');
      expect(
        (await db.searchCatalog('milk'))
            .firstWhere((i) => i.name == 'Milk')
            .category,
        'Beverages',
      );
    });
  });

  group('history', () {
    test('adding an item records it, and re-adding bumps it up', () async {
      final l = await firstList();
      await db.addShoppingItem(l.id, 'Milk', category: 'Dairy & Eggs');
      await db.addShoppingItem(l.id, 'Bread', category: 'Bakery');
      await db.addShoppingItem(l.id, 'milk', category: 'Dairy & Eggs');
      final h = await db.watchHistory().first;
      expect(h.map((e) => e.name), ['Milk', 'Bread']); // newest use first
      expect(h.first.useCount, 2);
      expect(h.first.category, 'Dairy & Eggs');
    });

    test('an entry can be removed, and comes back when added again', () async {
      final l = await firstList();
      await db.addShoppingItem(l.id, 'Milk', category: 'Dairy & Eggs');
      final entry = (await db.watchHistory().first).single;
      await db.removeHistory(entry.id);
      expect(await db.watchHistory().first, isEmpty);
      // removing from history does not touch the list itself
      expect(await db.watchShoppingItems(l.id).first, hasLength(1));

      await db.addShoppingItem(l.id, 'Milk', category: 'Dairy & Eggs');
      expect((await db.watchHistory().first).single.name, 'Milk');
    });

    test('pantry items are not part of the shopping history', () async {
      await db.addPantryItem('Rice');
      expect(await db.watchHistory().first, isEmpty);
    });
  });
}
