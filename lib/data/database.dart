import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'catalog_seed.dart';

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
  TextColumn get category => text().withDefault(const Constant(''))();
}

/// Store-aisle categories; [sortOrder] is the walking order used to group lists.
class Categories extends Table {
  TextColumn get name => text()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {name};
}

/// Searchable catalog of known items. Seeded from `catalog_seed.dart`; items
/// the user types in themselves are remembered with [isCustom] set.
class CatalogItems extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get defaultUnit => text().withDefault(const Constant(''))();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(
    tables: [ShoppingLists, ShoppingItems, PantryItems, Categories, CatalogItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// In-memory database for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await into(shoppingLists)
              .insert(ShoppingListsCompanion.insert(name: 'Groceries'));
          await _seedCatalog();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(categories);
            await m.createTable(catalogItems);
            await m.addColumn(pantryItems, pantryItems.category);
            await _seedCatalog();
          }
        },
      );

  Future<void> _seedCatalog() => batch((b) {
        var order = 0;
        for (final entry in catalogSeed.entries) {
          b.insert(categories,
              CategoriesCompanion.insert(name: entry.key, sortOrder: order++));
          b.insertAll(catalogItems, [
            for (final item in entry.value)
              CatalogItemsCompanion.insert(name: item, category: entry.key),
          ]);
        }
      });

  // ---- Catalog ----
  Stream<List<Category>> watchCategories() => (select(categories)
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .watch();

  /// Case-insensitive search; names starting with [query] rank first, then
  /// names containing it as a word, then anywhere.
  Future<List<CatalogItem>> searchCatalog(String query, {int limit = 8}) {
    final q = query.trim().toLowerCase().replaceAll(RegExp(r'[%_\\]'), '');
    if (q.isEmpty) return Future.value(const []);
    return (select(catalogItems)
          ..where((t) => t.deletedAt.isNull() & t.name.lower().like('%$q%'))
          ..orderBy([
            (t) => OrderingTerm.desc(t.name.lower().like('$q%')),
            (t) => OrderingTerm.desc(t.name.lower().like('% $q%')),
            (t) => OrderingTerm.asc(t.name),
          ])
          ..limit(limit))
        .get();
  }

  /// Remembers an item typed by the user so it is suggested next time.
  Future<void> _rememberItem(String name, String category, String unit) async {
    final exists = await (select(catalogItems)
          ..where((t) => t.name.lower().equals(name.toLowerCase()))
          ..limit(1))
        .get();
    if (exists.isNotEmpty) return;
    await into(catalogItems).insert(CatalogItemsCompanion.insert(
        name: name,
        category: category.isEmpty ? 'Other' : category,
        defaultUnit: Value(unit),
        isCustom: const Value(true)));
  }

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
      {double quantity = 1, String unit = '', String category = ''}) async {
    await into(shoppingItems).insert(ShoppingItemsCompanion.insert(
        listId: listId,
        name: name,
        quantity: Value(quantity),
        unit: Value(unit),
        category: Value(category)));
    await _rememberItem(name, category, unit);
  }

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
      String location = '',
      String category = ''}) async {
    await into(pantryItems).insert(PantryItemsCompanion.insert(
        name: name,
        quantity: Value(quantity),
        unit: Value(unit),
        expiryDate: Value(expiryDate),
        location: Value(location),
        category: Value(category)));
    await _rememberItem(name, category, unit);
  }

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
