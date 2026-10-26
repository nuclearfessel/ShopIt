import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/data/database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('changing an item category files it under that category header', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    final list = (await db.watchLists().first).single;
    final id = await db.addShoppingItem(
      list.id,
      'Milk',
      category: 'Dairy & Eggs',
    );

    final filed = await db.matchCategoryName('produce');
    expect(filed, 'Produce');
    await db.updateShoppingItem(
      id,
      name: 'Milk',
      quantity: 1,
      unit: '',
      category: filed,
      note: '',
    );

    final item = await (db.select(
      db.shoppingItems,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(item.category, 'Produce');

    final open = await (db.select(
      db.shoppingItems,
    )..where((t) => t.deletedAt.isNull() & t.listId.equals(list.id))).get();
    final produce = [
      for (final row in open)
        if (row.category == 'Produce') row.name,
    ];
    expect(produce, ['Milk']);
  });

  test('filing an Other item puts it in the category it was dropped on', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    final list = (await db.watchLists().first).single;
    final id = await db.addShoppingItem(
      list.id,
      'Crackers',
      category: 'Other',
    );

    await db.fileShoppingItemInCategory(id, 'Produce');

    final item = await (db.select(
      db.shoppingItems,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(item.category, 'Produce');
  });
}
