import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

part 'database.g.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// Columns shared by every synced table. Rows are soft-deleted so a future
/// sync can propagate deletions.
mixin SyncColumns on Table {
  TextColumn get id => text().clientDefault(newId)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ShoppingLists extends Table with SyncColumns {
  TextColumn get name => text()();
}

class ShoppingItems extends Table with SyncColumns {
  TextColumn get listId => text().references(ShoppingLists, #id)();
  TextColumn get name => text()();
  RealColumn get quantity => real().withDefault(const Constant(1))();
  TextColumn get unit => text().withDefault(const Constant(''))();
  BoolColumn get checked => boolean().withDefault(const Constant(false))();
  TextColumn get category => text().withDefault(const Constant(''))();
}

class PantryItems extends Table with SyncColumns {
  TextColumn get name => text()();
  RealColumn get quantity => real().withDefault(const Constant(1))();
  TextColumn get unit => text().withDefault(const Constant(''))();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  TextColumn get location => text().withDefault(const Constant(''))();
}

@DriftDatabase(tables: [ShoppingLists, ShoppingItems, PantryItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// In-memory database for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await into(shoppingLists)
              .insert(ShoppingListsCompanion.insert(name: 'Groceries'));
        },
      );

  // ---- Shopping lists ----
  Stream<List<ShoppingList>> watchLists() => (select(shoppingLists)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .watch();

  Future<void> addList(String name) =>
      into(shoppingLists).insert(ShoppingListsCompanion.insert(name: name));

  Future<void> deleteList(String id) async {
    final now = DateTime.now();
    await transaction(() async {
      await (update(shoppingItems)..where((t) => t.listId.equals(id))).write(
          ShoppingItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
      await (update(shoppingLists)..where((t) => t.id.equals(id))).write(
          ShoppingListsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
    });
  }

  // ---- Shopping items ----
  Stream<List<ShoppingItem>> watchShoppingItems(String listId) =>
      (select(shoppingItems)
            ..where((t) => t.listId.equals(listId) & t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.asc(t.checked),
              (t) => OrderingTerm.asc(t.name),
            ]))
          .watch();

  Future<void> addShoppingItem(String listId, String name,
          {double quantity = 1, String unit = ''}) =>
      into(shoppingItems).insert(ShoppingItemsCompanion.insert(
          listId: listId,
          name: name,
          quantity: Value(quantity),
          unit: Value(unit)));

  Future<void> setChecked(String id, bool checked) =>
      (update(shoppingItems)..where((t) => t.id.equals(id))).write(
          ShoppingItemsCompanion(
              checked: Value(checked), updatedAt: Value(DateTime.now())));

  Future<void> deleteShoppingItem(String id) {
    final now = DateTime.now();
    return (update(shoppingItems)..where((t) => t.id.equals(id))).write(
        ShoppingItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  Future<void> clearChecked(String listId) {
    final now = DateTime.now();
    return (update(shoppingItems)
          ..where((t) =>
              t.listId.equals(listId) &
              t.checked.equals(true) &
              t.deletedAt.isNull()))
        .write(
            ShoppingItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  // ---- Pantry ----
  /// Soonest expiry first; items without an expiry date sort last.
  Stream<List<PantryItem>> watchPantry() => (select(pantryItems)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([
          (t) => OrderingTerm(
              expression: t.expiryDate.isNull(), mode: OrderingMode.asc),
          (t) => OrderingTerm.asc(t.expiryDate),
          (t) => OrderingTerm.asc(t.name),
        ]))
      .watch();

  Future<void> addPantryItem(String name,
          {double quantity = 1,
          String unit = '',
          DateTime? expiryDate,
          String location = ''}) =>
      into(pantryItems).insert(PantryItemsCompanion.insert(
          name: name,
          quantity: Value(quantity),
          unit: Value(unit),
          expiryDate: Value(expiryDate),
          location: Value(location)));

  Future<void> updatePantryQuantity(String id, double quantity) =>
      (update(pantryItems)..where((t) => t.id.equals(id))).write(
          PantryItemsCompanion(
              quantity: Value(quantity), updatedAt: Value(DateTime.now())));

  Future<void> deletePantryItem(String id) {
    final now = DateTime.now();
    return (update(pantryItems)..where((t) => t.id.equals(id))).write(
        PantryItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }
}

Future<AppDatabase> openAppDatabase() async {
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, 'shop_it.sqlite'));
  return AppDatabase(NativeDatabase.createInBackground(file));
}
