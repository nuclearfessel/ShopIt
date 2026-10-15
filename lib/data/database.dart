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

  /// Price of one unit; the line total is price * quantity.
  RealColumn get price => real().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
}

class PantryItems extends Table with SyncColumns {
  TextColumn get name => text()();
  RealColumn get quantity => real().withDefault(const Constant(1))();
  TextColumn get unit => text().withDefault(const Constant(''))();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  TextColumn get location => text().withDefault(const Constant(''))();
  TextColumn get category => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();
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

  /// For a variant (a type, cut or flavour) the group it belongs to, e.g.
  /// "Onions" for "Red onions". Empty for top-level items.
  TextColumn get parentName => text().withDefault(const Constant(''))();
}

@DriftDatabase(
    tables: [ShoppingLists, ShoppingItems, PantryItems, Categories, CatalogItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// In-memory database for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 4;

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
          } else if (from < 3) {
            // v3 adds variants: replace the built-in catalog, keep the user's
            // own remembered items.
            await m.addColumn(catalogItems, catalogItems.parentName);
            await (delete(catalogItems)
                  ..where((t) => t.isCustom.equals(false)))
                .go();
            await delete(categories).go();
            await _seedCatalog();
          }
          if (from < 4) {
            // v4: item details (price, notes).
            await m.addColumn(shoppingItems, shoppingItems.price);
            await m.addColumn(shoppingItems, shoppingItems.note);
            await m.addColumn(pantryItems, pantryItems.note);
          }
        },
      );

  Future<void> _seedCatalog() => batch((b) {
        var order = 0;
        for (final cat in catalogSeed.entries) {
          b.insert(categories,
              CategoriesCompanion.insert(name: cat.key, sortOrder: order++));
          for (final item in cat.value.entries) {
            b.insert(
                catalogItems,
                CatalogItemsCompanion.insert(
                    name: item.key, category: cat.key));
            b.insertAll(catalogItems, [
              for (final variant in item.value)
                CatalogItemsCompanion.insert(
                    name: variant,
                    category: cat.key,
                    parentName: Value(item.key)),
            ]);
          }
        }
      });

  // ---- Catalog ----
  Stream<List<Category>> watchCategories() => (select(categories)
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .watch();

  /// Case-insensitive search over item names and their group names.
  ///
  /// Results come back grouped: each matching top-level item (e.g. "Onions")
  /// is followed by its variants (types, cuts, flavours), then any variants
  /// that matched on their own name. Duplicate names are dropped.
  Future<List<CatalogItem>> searchCatalog(String query, {int limit = 40}) async {
    final q = query.trim().toLowerCase().replaceAll(RegExp(r'[%_\\]'), '');
    if (q.isEmpty) return const [];
    final rows = await (select(catalogItems)
          ..where((t) =>
              t.deletedAt.isNull() &
              (t.name.lower().like('%$q%') | t.parentName.lower().like('%$q%')))
          ..orderBy([
            (t) => OrderingTerm.desc(t.name.lower().like('$q%')),
            (t) => OrderingTerm.desc(t.name.lower().like('% $q%')),
            (t) => OrderingTerm.asc(t.name),
          ])
          ..limit(300))
        .get();

    final out = <CatalogItem>[];
    final seen = <String>{};
    void add(CatalogItem i) {
      if (out.length < limit && seen.add(i.name.toLowerCase())) out.add(i);
    }

    final variants = rows.where((i) => i.parentName.isNotEmpty).toList();
    for (final parent in rows.where((i) => i.parentName.isEmpty)) {
      add(parent);
      for (final v in variants.where((v) => v.parentName == parent.name)) {
        add(v);
      }
    }
    for (final v in variants) {
      add(v);
    }
    return out;
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

  /// Soft-deletes every list and every item on them. Pantry and the item
  /// catalog are untouched.
  Future<void> deleteAllLists() async {
    final now = DateTime.now();
    await transaction(() async {
      await (update(shoppingItems)..where((t) => t.deletedAt.isNull())).write(
          ShoppingItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
      await (update(shoppingLists)..where((t) => t.deletedAt.isNull())).write(
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

  /// Saves everything the item editor can change. [price] null clears it.
  Future<void> updateShoppingItem(String id,
          {required String name,
          required double quantity,
          required String unit,
          required String category,
          double? price,
          required String note}) =>
      (update(shoppingItems)..where((t) => t.id.equals(id))).write(
          ShoppingItemsCompanion(
              name: Value(name),
              quantity: Value(quantity),
              unit: Value(unit),
              category: Value(category),
              price: Value(price),
              note: Value(note),
              updatedAt: Value(DateTime.now())));

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

  /// Saves everything the item editor can change. [expiryDate] null clears it.
  Future<void> updatePantryItem(String id,
          {required String name,
          required double quantity,
          required String unit,
          required String category,
          required String location,
          DateTime? expiryDate,
          required String note}) =>
      (update(pantryItems)..where((t) => t.id.equals(id))).write(
          PantryItemsCompanion(
              name: Value(name),
              quantity: Value(quantity),
              unit: Value(unit),
              category: Value(category),
              location: Value(location),
              expiryDate: Value(expiryDate),
              note: Value(note),
              updatedAt: Value(DateTime.now())));

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
