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

  /// Which saved tax rate applies to this list; null means no tax.
  TextColumn get taxRateId => text().nullable()();

  /// List settings (Out of Milk's "List settings"): group items by category,
  /// file new items into a category automatically, and show category headers
  /// that have no items.
  BoolColumn get useCategories => boolean().withDefault(const Constant(true))();
  BoolColumn get autoCategorize =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showEmptyCategories =>
      boolean().withDefault(const Constant(false))();

  /// Position among the lists (Manage lists lets the user reorder them).
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

/// User-defined sales tax rates. Rates differ by country, state and region, so
/// none are built in: the user names and enters their own (e.g. "Home 8.25").
class TaxRates extends Table with SyncColumns {
  TextColumn get name => text()();
  RealColumn get percent => real()();

  /// Which rules say what is taxed: 'everything' or a state like 'US-WA'
  /// (see tax_rules.dart).
  TextColumn get ruleSet => text().withDefault(const Constant('everything'))();

  /// Rate for groceries where it differs from [percent]: reduced or local
  /// grocery taxes, or a city that taxes food in a state that exempts it.
  RealColumn get groceryPercent => real().nullable()();
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

  /// "Item has sales tax" and "I have a coupon" flags from the item editor.
  BoolColumn get taxable => boolean().withDefault(const Constant(false))();
  BoolColumn get hasCoupon => boolean().withDefault(const Constant(false))();

  /// True when the user ticked or unticked "has sales tax" themselves; otherwise
  /// taxability comes from the list's tax rules and [taxable] is ignored.
  BoolColumn get taxManual => boolean().withDefault(const Constant(false))();
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

  /// The header colour as an ARGB value; null means the automatic colour.
  IntColumn get color => integer().nullable()();

  @override
  Set<Column> get primaryKey => {name};
}

/// The user's manual order of categories within one list.
class ListCategoryOrders extends Table {
  TextColumn get listId => text()();
  TextColumn get category => text()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {listId, category};
}

/// Items the user has added before: the "history" they can re-add from.
@DataClassName('HistoryEntry')
class ItemHistory extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get category => text().withDefault(const Constant(''))();
  TextColumn get unit => text().withDefault(const Constant(''))();
  DateTimeColumn get lastUsed => dateTime().clientDefault(DateTime.now)();
  IntColumn get useCount => integer().withDefault(const Constant(1))();
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
  tables: [
    ShoppingLists,
    ShoppingItems,
    PantryItems,
    Categories,
    CatalogItems,
    TaxRates,
    ListCategoryOrders,
    ItemHistory,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// In-memory database for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 8;

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
        await (delete(
          catalogItems,
        )..where((t) => t.isCustom.equals(false))).go();
        await delete(categories).go();
        await _seedCatalog();
      }
      if (from < 4) {
        // v4: item details (price, notes).
        await m.addColumn(shoppingItems, shoppingItems.price);
        await m.addColumn(shoppingItems, shoppingItems.note);
        await m.addColumn(pantryItems, pantryItems.note);
      }
      if (from < 5) {
        // v5: sales tax and coupon flags.
        await m.addColumn(shoppingItems, shoppingItems.taxable);
        await m.addColumn(shoppingItems, shoppingItems.hasCoupon);
      }
      if (from < 6) {
        // v6: user-defined tax rates, chosen per shopping list.
        await m.createTable(taxRates);
        await m.addColumn(shoppingLists, shoppingLists.taxRateId);
      }
      if (from < 7) {
        // v7: tax rules per rate; items follow the rules unless set by hand.
        await m.addColumn(shoppingItems, shoppingItems.taxManual);
        if (from >= 6) {
          // (older upgrades created tax_rates with these columns already)
          await m.addColumn(taxRates, taxRates.ruleSet);
          await m.addColumn(taxRates, taxRates.groceryPercent);
        }
      }
      if (from < 8) {
        // v8: list settings and order, category colours and per-list order,
        // and item history.
        await m.addColumn(shoppingLists, shoppingLists.useCategories);
        await m.addColumn(shoppingLists, shoppingLists.autoCategorize);
        await m.addColumn(shoppingLists, shoppingLists.showEmptyCategories);
        await m.addColumn(shoppingLists, shoppingLists.sortOrder);
        if (from >= 2) await m.addColumn(categories, categories.color);
        await m.createTable(listCategoryOrders);
        await m.createTable(itemHistory);
        await _backfillHistory();
      }
    },
  );

  Future<void> _seedCatalog() => batch((b) {
    var order = 0;
    for (final cat in catalogSeed.entries) {
      b.insert(
        categories,
        CategoriesCompanion.insert(name: cat.key, sortOrder: order++),
      );
      for (final item in cat.value.entries) {
        b.insert(
          catalogItems,
          CatalogItemsCompanion.insert(name: item.key, category: cat.key),
        );
        b.insertAll(catalogItems, [
          for (final variant in item.value)
            CatalogItemsCompanion.insert(
              name: variant,
              category: cat.key,
              parentName: Value(item.key),
            ),
        ]);
      }
    }
  });

  // ---- Catalog ----
  Stream<List<Category>> watchCategories() => (select(
    categories,
  )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).watch();

  /// Case-insensitive search over item names and their group names.
  ///
  /// Results come back grouped: each matching top-level item (e.g. "Onions")
  /// is followed by its variants (types, cuts, flavours), then any variants
  /// that matched on their own name. Duplicate names are dropped.
  Future<List<CatalogItem>> searchCatalog(
    String query, {
    int limit = 40,
  }) async {
    final q = query.trim().toLowerCase().replaceAll(RegExp(r'[%_\\]'), '');
    if (q.isEmpty) return const [];
    final rows =
        await (select(catalogItems)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    (t.name.lower().like('%$q%') |
                        t.parentName.lower().like('%$q%')),
              )
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
    final exists =
        await (select(catalogItems)
              ..where((t) => t.name.lower().equals(name.toLowerCase()))
              ..limit(1))
            .get();
    if (exists.isNotEmpty) return;
    await into(catalogItems).insert(
      CatalogItemsCompanion.insert(
        name: name,
        category: category.isEmpty ? 'Other' : category,
        defaultUnit: Value(unit),
        isCustom: const Value(true),
      ),
    );
  }

  // ---- Shopping lists ----
  Stream<List<ShoppingList>> watchLists() =>
      (select(shoppingLists)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.name),
            ]))
          .watch();

  // ---- Tax rates ----
  Stream<List<TaxRate>> watchTaxRates() =>
      (select(taxRates)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Future<String> addTaxRate(
    String name,
    double percent, {
    String ruleSet = 'everything',
    double? groceryPercent,
  }) async {
    final row = TaxRatesCompanion.insert(
      name: name,
      percent: percent,
      ruleSet: Value(ruleSet),
      groceryPercent: Value(groceryPercent),
    );
    final created = await into(taxRates).insertReturning(row);
    return created.id;
  }

  Future<void> updateTaxRate(
    String id,
    String name,
    double percent, {
    String ruleSet = 'everything',
    double? groceryPercent,
  }) => (update(taxRates)..where((t) => t.id.equals(id))).write(
    TaxRatesCompanion(
      name: Value(name),
      percent: Value(percent),
      ruleSet: Value(ruleSet),
      groceryPercent: Value(groceryPercent),
      updatedAt: Value(DateTime.now()),
    ),
  );

  /// Deletes a rate; lists that used it go back to "no tax".
  Future<void> deleteTaxRate(String id) async {
    final now = DateTime.now();
    await transaction(() async {
      await (update(shoppingLists)..where((t) => t.taxRateId.equals(id))).write(
        ShoppingListsCompanion(
          taxRateId: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await (update(taxRates)..where((t) => t.id.equals(id))).write(
        TaxRatesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    });
  }

  /// Chooses the tax rate for a list; null means no tax.
  Future<void> setListTaxRate(String listId, String? rateId) =>
      (update(shoppingLists)..where((t) => t.id.equals(listId))).write(
        ShoppingListsCompanion(
          taxRateId: Value(rateId),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> addList(String name) async {
    final count = (await (select(
      shoppingLists,
    )..where((t) => t.deletedAt.isNull())).get()).length;
    await into(shoppingLists).insert(
      ShoppingListsCompanion.insert(name: name, sortOrder: Value(count)),
    );
  }

  Future<void> renameList(String id, String name) =>
      (update(shoppingLists)..where((t) => t.id.equals(id))).write(
        ShoppingListsCompanion(
          name: Value(name),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Saves the order of the lists: [ids] first to last.
  Future<void> reorderLists(List<String> ids) => transaction(() async {
    for (var i = 0; i < ids.length; i++) {
      await (update(shoppingLists)..where((t) => t.id.equals(ids[i]))).write(
        ShoppingListsCompanion(
          sortOrder: Value(i),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  });

  /// Changes list settings; null leaves a setting as it is.
  Future<void> updateListSettings(
    String id, {
    bool? useCategories,
    bool? autoCategorize,
    bool? showEmptyCategories,
  }) => (update(shoppingLists)..where((t) => t.id.equals(id))).write(
    ShoppingListsCompanion(
      useCategories: useCategories == null
          ? const Value.absent()
          : Value(useCategories),
      autoCategorize: autoCategorize == null
          ? const Value.absent()
          : Value(autoCategorize),
      showEmptyCategories: showEmptyCategories == null
          ? const Value.absent()
          : Value(showEmptyCategories),
      updatedAt: Value(DateTime.now()),
    ),
  );

  /// Puts every item on the list into the cart.
  Future<void> checkAll(String listId) =>
      (update(shoppingItems)..where(
            (t) =>
                t.listId.equals(listId) &
                t.checked.equals(false) &
                t.deletedAt.isNull(),
          ))
          .write(
            ShoppingItemsCompanion(
              checked: const Value(true),
              updatedAt: Value(DateTime.now()),
            ),
          );

  // ---- Categories ----

  /// Adds a category (ignored if one with that name exists, ignoring case).
  Future<void> addCategory(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final all = await select(categories).get();
    if (all.any((c) => c.name.toLowerCase() == clean.toLowerCase())) return;
    final next = all.isEmpty
        ? 0
        : all.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    await into(categories)
        .insert(CategoriesCompanion.insert(name: clean, sortOrder: next));
  }

  /// Deletes a category everywhere. Items in it become uncategorised and the
  /// remembered category of catalog items falls back to "Other".
  Future<void> deleteCategory(String name) async {
    if (name == 'Other') return;
    await transaction(() async {
      final now = DateTime.now();
      await (update(
        shoppingItems,
      )..where((t) => t.category.equals(name) & t.deletedAt.isNull())).write(
        ShoppingItemsCompanion(
          category: const Value(''),
          updatedAt: Value(now),
        ),
      );
      await (update(
        pantryItems,
      )..where((t) => t.category.equals(name) & t.deletedAt.isNull())).write(
        PantryItemsCompanion(category: const Value(''), updatedAt: Value(now)),
      );
      await (update(catalogItems)..where((t) => t.category.equals(name))).write(
        CatalogItemsCompanion(
          category: const Value('Other'),
          updatedAt: Value(now),
        ),
      );
      await (delete(
        listCategoryOrders,
      )..where((t) => t.category.equals(name))).go();
      await (delete(categories)..where((t) => t.name.equals(name))).go();
    });
  }

  /// Sets a category's header colour (ARGB), or null for the automatic one.
  Future<void> setCategoryColor(String name, int? argb) =>
      (update(categories)..where((t) => t.name.equals(name))).write(
        CategoriesCompanion(color: Value(argb)),
      );

  Stream<List<ListCategoryOrder>> watchListCategoryOrder(String listId) =>
      (select(listCategoryOrders)
            ..where((t) => t.listId.equals(listId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .watch();

  /// Saves the manual category order for one list: [ordered] first to last.
  Future<void> setListCategoryOrder(String listId, List<String> ordered) =>
      transaction(() async {
        await (delete(
          listCategoryOrders,
        )..where((t) => t.listId.equals(listId))).go();
        for (var i = 0; i < ordered.length; i++) {
          await into(listCategoryOrders).insert(
            ListCategoryOrdersCompanion.insert(
              listId: listId,
              category: ordered[i],
              position: i,
            ),
          );
        }
      });

  /// Remembers that [name] belongs in [category] from now on, so adding it
  /// again (typing it or from history) files it there.
  Future<void> assignCategory(String name, String category) async {
    if (category.isEmpty) return;
    final now = DateTime.now();
    final changed =
        await (update(
          catalogItems,
        )..where((t) => t.name.lower().equals(name.toLowerCase()))).write(
          CatalogItemsCompanion(
            category: Value(category),
            updatedAt: Value(now),
          ),
        );
    if (changed == 0) await _rememberItem(name, category, '');
    await (update(
      itemHistory,
    )..where((t) => t.name.lower().equals(name.toLowerCase()))).write(
      ItemHistoryCompanion(category: Value(category), updatedAt: Value(now)),
    );
  }

  // ---- History ----

  /// Everything the user has added before, most recent first.
  Stream<List<HistoryEntry>> watchHistory() =>
      (select(itemHistory)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.lastUsed)]))
          .watch();

  Future<void> recordHistory(String name, String category, String unit) async {
    final existing =
        await (select(itemHistory)
              ..where((t) => t.name.lower().equals(name.toLowerCase()))
              ..limit(1))
            .getSingleOrNull();
    final now = DateTime.now();
    if (existing == null) {
      await into(itemHistory).insert(
        ItemHistoryCompanion.insert(
          name: name,
          category: Value(category),
          unit: Value(unit),
        ),
      );
    } else {
      await (update(itemHistory)..where((t) => t.id.equals(existing.id))).write(
        ItemHistoryCompanion(
          category: Value(category.isEmpty ? existing.category : category),
          unit: Value(unit.isEmpty ? existing.unit : unit),
          lastUsed: Value(now),
          useCount: Value(existing.useCount + 1),
          deletedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
    }
  }

  /// Removes one entry from the history (the trash can in the history list).
  Future<void> removeHistory(String id) =>
      (update(itemHistory)..where((t) => t.id.equals(id))).write(
        ItemHistoryCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// On upgrade, seeds the history from items already on the user's lists.
  Future<void> _backfillHistory() async {
    final items = await (select(
      shoppingItems,
    )..orderBy([(t) => OrderingTerm.asc(t.updatedAt)])).get();
    final byName = <String, ShoppingItem>{};
    final counts = <String, int>{};
    for (final i in items) {
      final key = i.name.toLowerCase();
      byName[key] = i; // later (newer) rows win
      counts[key] = (counts[key] ?? 0) + 1;
    }
    for (final entry in byName.entries) {
      final i = entry.value;
      await into(itemHistory).insert(
        ItemHistoryCompanion.insert(
          name: i.name,
          category: Value(i.category),
          unit: Value(i.unit),
          lastUsed: Value(i.updatedAt),
          useCount: Value(counts[entry.key] ?? 1),
        ),
      );
    }
  }

  Future<void> deleteList(String id) async {
    final now = DateTime.now();
    await transaction(() async {
      await (update(shoppingItems)..where((t) => t.listId.equals(id))).write(
        ShoppingItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (update(shoppingLists)..where((t) => t.id.equals(id))).write(
        ShoppingListsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    });
  }

  /// Soft-deletes every list and every item on them. Pantry and the item
  /// catalog are untouched.
  Future<void> deleteAllLists() async {
    final now = DateTime.now();
    await transaction(() async {
      await (update(shoppingItems)..where((t) => t.deletedAt.isNull())).write(
        ShoppingItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (update(shoppingLists)..where((t) => t.deletedAt.isNull())).write(
        ShoppingListsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
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

  /// Adds an item and returns its id.
  Future<String> addShoppingItem(
    String listId,
    String name, {
    double quantity = 1,
    String unit = '',
    String category = '',
  }) async {
    final row = await into(shoppingItems).insertReturning(
      ShoppingItemsCompanion.insert(
        listId: listId,
        name: name,
        quantity: Value(quantity),
        unit: Value(unit),
        category: Value(category),
        // New items are taxed by default (like Out of Milk); untick per item.
        taxable: const Value(true),
      ),
    );
    await _rememberItem(name, category, unit);
    await recordHistory(name, category, unit);
    return row.id;
  }

  Future<void> setChecked(String id, bool checked) =>
      (update(shoppingItems)..where((t) => t.id.equals(id))).write(
        ShoppingItemsCompanion(
          checked: Value(checked),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Saves everything the item editor can change. [price] null clears it.
  Future<void> updateShoppingItem(
    String id, {
    required String name,
    required double quantity,
    required String unit,
    required String category,
    double? price,
    required String note,
    bool taxable = false,
    bool hasCoupon = false,
    bool taxManual = false,
  }) => (update(shoppingItems)..where((t) => t.id.equals(id))).write(
    ShoppingItemsCompanion(
      name: Value(name),
      quantity: Value(quantity),
      unit: Value(unit),
      category: Value(category),
      price: Value(price),
      note: Value(note),
      taxable: Value(taxable),
      hasCoupon: Value(hasCoupon),
      taxManual: Value(taxManual),
      updatedAt: Value(DateTime.now()),
    ),
  );

  /// Marks every item on a list as taxable or not, overriding the tax rules.
  Future<void> setAllTaxable(String listId, bool taxable) =>
      (update(
        shoppingItems,
      )..where((t) => t.listId.equals(listId) & t.deletedAt.isNull())).write(
        ShoppingItemsCompanion(
          taxable: Value(taxable),
          taxManual: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Puts every item on a list back on the automatic tax rules.
  Future<void> resetTaxToAutomatic(String listId) =>
      (update(
        shoppingItems,
      )..where((t) => t.listId.equals(listId) & t.deletedAt.isNull())).write(
        ShoppingItemsCompanion(
          taxManual: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Moves an item to another list.
  Future<void> moveShoppingItem(String id, String listId) =>
      (update(shoppingItems)..where((t) => t.id.equals(id))).write(
        ShoppingItemsCompanion(
          listId: Value(listId),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Copies an item (unchecked) onto [listId], which may be the same list.
  Future<void> copyShoppingItem(ShoppingItem item, String listId) =>
      into(shoppingItems).insert(
        ShoppingItemsCompanion.insert(
          listId: listId,
          name: item.name,
          quantity: Value(item.quantity),
          unit: Value(item.unit),
          category: Value(item.category),
          price: Value(item.price),
          note: Value(item.note),
          taxable: Value(item.taxable),
          hasCoupon: Value(item.hasCoupon),
          taxManual: Value(item.taxManual),
        ),
      );

  Future<void> deleteShoppingItem(String id) {
    final now = DateTime.now();
    return (update(shoppingItems)..where((t) => t.id.equals(id))).write(
      ShoppingItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// Soft-deletes every checked item on the list and returns their ids, so
  /// the caller can offer an undo via [restoreItems].
  Future<List<String>> clearChecked(String listId) async {
    final now = DateTime.now();
    final match = select(shoppingItems)
      ..where(
        (t) =>
            t.listId.equals(listId) &
            t.checked.equals(true) &
            t.deletedAt.isNull(),
      );
    final ids = [for (final i in await match.get()) i.id];
    if (ids.isEmpty) return ids;
    await (update(shoppingItems)..where((t) => t.id.isIn(ids))).write(
      ShoppingItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    return ids;
  }

  /// Brings back items deleted by [clearChecked] (still checked).
  Future<void> restoreItems(List<String> ids) =>
      (update(shoppingItems)..where((t) => t.id.isIn(ids))).write(
        ShoppingItemsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Unchecks every checked item on the list (puts them back to be bought).
  Future<void> uncheckAll(String listId) =>
      (update(shoppingItems)..where(
            (t) =>
                t.listId.equals(listId) &
                t.checked.equals(true) &
                t.deletedAt.isNull(),
          ))
          .write(
            ShoppingItemsCompanion(
              checked: const Value(false),
              updatedAt: Value(DateTime.now()),
            ),
          );

  // ---- Pantry ----
  /// Soonest expiry first; items without an expiry date sort last.
  Stream<List<PantryItem>> watchPantry() =>
      (select(pantryItems)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.expiryDate.isNull(),
                mode: OrderingMode.asc,
              ),
              (t) => OrderingTerm.asc(t.expiryDate),
              (t) => OrderingTerm.asc(t.name),
            ]))
          .watch();

  Future<void> addPantryItem(
    String name, {
    double quantity = 1,
    String unit = '',
    DateTime? expiryDate,
    String location = '',
    String category = '',
  }) async {
    await into(pantryItems).insert(
      PantryItemsCompanion.insert(
        name: name,
        quantity: Value(quantity),
        unit: Value(unit),
        expiryDate: Value(expiryDate),
        location: Value(location),
        category: Value(category),
      ),
    );
    await _rememberItem(name, category, unit);
  }

  Future<void> updatePantryQuantity(String id, double quantity) =>
      (update(pantryItems)..where((t) => t.id.equals(id))).write(
        PantryItemsCompanion(
          quantity: Value(quantity),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Saves everything the item editor can change. [expiryDate] null clears it.
  Future<void> updatePantryItem(
    String id, {
    required String name,
    required double quantity,
    required String unit,
    required String category,
    required String location,
    DateTime? expiryDate,
    required String note,
  }) => (update(pantryItems)..where((t) => t.id.equals(id))).write(
    PantryItemsCompanion(
      name: Value(name),
      quantity: Value(quantity),
      unit: Value(unit),
      category: Value(category),
      location: Value(location),
      expiryDate: Value(expiryDate),
      note: Value(note),
      updatedAt: Value(DateTime.now()),
    ),
  );

  Future<void> deletePantryItem(String id) {
    final now = DateTime.now();
    return (update(pantryItems)..where((t) => t.id.equals(id))).write(
      PantryItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}

Future<AppDatabase> openAppDatabase() async {
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, 'shop_it.sqlite'));
  return AppDatabase(NativeDatabase.createInBackground(file));
}
