import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  test('seeds a default list', () async {
    final lists = await db.watchLists().first;
    expect(lists.map((l) => l.name), ['Groceries']);
  });

  test('shopping items: add, check, sort, soft-delete, clear checked',
      () async {
    final list = (await db.watchLists().first).single;
    await db.addShoppingItem(list.id, 'Milk');
    await db.addShoppingItem(list.id, 'Apples');

    var items = await db.watchShoppingItems(list.id).first;
    expect(items.map((i) => i.name), ['Apples', 'Milk']);

    await db.setChecked(items.first.id, true);
    items = await db.watchShoppingItems(list.id).first;
    expect(items.map((i) => i.name), ['Milk', 'Apples']); // checked sinks

    await db.clearChecked(list.id);
    items = await db.watchShoppingItems(list.id).first;
    expect(items.map((i) => i.name), ['Milk']);

    await db.deleteShoppingItem(items.single.id);
    expect(await db.watchShoppingItems(list.id).first, isEmpty);
    // soft delete: the rows still exist for future sync
    expect(await db.select(db.shoppingItems).get(), hasLength(2));
  });

  test('deleting a list hides its items', () async {
    await db.addList('Party');
    final party =
        (await db.watchLists().first).firstWhere((l) => l.name == 'Party');
    await db.addShoppingItem(party.id, 'Chips');
    await db.deleteList(party.id);
    expect((await db.watchLists().first).map((l) => l.name), ['Groceries']);
    expect(await db.watchShoppingItems(party.id).first, isEmpty);
  });

  test('pantry sorts by soonest expiry, undated last', () async {
    final now = DateTime.now();
    await db.addPantryItem('Rice');
    await db.addPantryItem('Yogurt',
        expiryDate: now.add(const Duration(days: 2)));
    await db.addPantryItem('Milk',
        expiryDate: now.add(const Duration(days: 1)));
    final items = await db.watchPantry().first;
    expect(items.map((i) => i.name), ['Milk', 'Yogurt', 'Rice']);

    await db.updatePantryQuantity(items.first.id, 3);
    expect((await db.watchPantry().first).first.quantity, 3);

    await db.deletePantryItem(items.first.id);
    expect(
        (await db.watchPantry().first).map((i) => i.name), ['Yogurt', 'Rice']);
  });
}
