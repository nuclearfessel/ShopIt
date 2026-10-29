import 'import_rows.dart';

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'catalog_seed.dart';
import 'recipe_plan.dart';

export 'recipe_plan.dart';

part 'database.g.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// Columns shared by every synced table. Rows are soft-deleted so a deletion
/// on one device can be applied on the other (see device_sync.dart).
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

  /// Group items by category, file new items into a category automatically,
  /// and show category headers that have no items.
  BoolColumn get useCategories => boolean().withDefault(const Constant(true))();
  BoolColumn get autoCategorize =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showEmptyCategories =>
      boolean().withDefault(const Constant(false))();

  /// Position among the lists (Manage lists lets the user reorder them).
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 'shopping' or 'pantry': both kinds of list live in this table so they
  /// share renaming, ordering and category order.
  TextColumn get kind => text().withDefault(const Constant('shopping'))();

  /// For pantry lists: how new items show their amount, 'level' (Low/Full) or
  /// 'number' (an exact quantity).
  TextColumn get quantityMode => text().withDefault(const Constant('level'))();
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

  /// The pantry list this item is on.
  TextColumn get listId => text().withDefault(const Constant(''))();

  /// 'level' (shows Low/Full, see [level]) or 'number' (shows [quantity]).
  TextColumn get quantityMode => text().withDefault(const Constant('level'))();

  /// 'full' or 'low'.
  TextColumn get level => text().withDefault(const Constant('full'))();
}

/// Categories; [sortOrder] mirrors alphabetical order used to group lists.
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

  /// Package barcode from an Android scan. Empty until a scan is linked.
  TextColumn get barcode => text().withDefault(const Constant(''))();
}

/// A saved recipe: name, how many it serves, and optional notes.
class Recipes extends Table with SyncColumns {
  TextColumn get name => text()();
  RealColumn get servings => real().withDefault(const Constant(4))();
  TextColumn get note => text().withDefault(const Constant(''))();
}

/// One ingredient on a recipe, using the same names as the catalog.
class RecipeIngredients extends Table with SyncColumns {
  TextColumn get recipeId => text()();
  TextColumn get name => text()();
  RealColumn get quantity => real().withDefault(const Constant(1))();
  TextColumn get unit => text().withDefault(const Constant(''))();
  TextColumn get category => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
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
    Recipes,
    RecipeIngredients,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// In-memory database for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(shoppingLists)
          .insert(ShoppingListsCompanion.insert(name: 'Groceries'));
      await into(shoppingLists).insert(
        ShoppingListsCompanion.insert(
          name: 'Pantry',
          kind: const Value('pantry'),
        ),
      );
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
      if (from < 9) {
        // v9: several pantry lists, Low/Full or exact amounts, per item.
        await m.addColumn(shoppingLists, shoppingLists.kind);
        await m.addColumn(shoppingLists, shoppingLists.quantityMode);
        await m.addColumn(pantryItems, pantryItems.listId);
        await m.addColumn(pantryItems, pantryItems.quantityMode);
        await m.addColumn(pantryItems, pantryItems.level);
        // The existing pantry becomes the first pantry list. Its items keep
        // showing the exact amounts they already had.
        final pantry = await into(shoppingLists).insertReturning(
          ShoppingListsCompanion.insert(
            name: 'Pantry',
            kind: const Value('pantry'),
            quantityMode: const Value('number'),
          ),
        );
        await (update(pantryItems)).write(
          PantryItemsCompanion(
            listId: Value(pantry.id),
            quantityMode: const Value('number'),
          ),
        );
      }
      if (from < 10) {
        // v10: categories are always alphabetical on every list.
        await delete(listCategoryOrders).go();
        await _resortCategoriesAlphabetically();
      }
      if (from < 11) {
        // v11: larger built-in catalog. Add names that are not already there.
        await mergeBuiltinCatalog();
      }
      if (from < 12) {
        // v12: more brand products, including Tillamook and Organic Valley dairy.
        await mergeBuiltinCatalog();
      }
      if (from < 13) {
        final columns = await customSelect('PRAGMA table_info(catalog_items)')
            .get();
        final names = {for (final row in columns) row.read<String>('name')};
        if (!names.contains('barcode')) {
          await m.addColumn(catalogItems, catalogItems.barcode);
        }
        final tables = await customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        ).get();
        final tableNames = {for (final row in tables) row.read<String>('name')};
        if (!tableNames.contains('recipes')) {
          await m.createTable(recipes);
        }
        if (!tableNames.contains('recipe_ingredients')) {
          await m.createTable(recipeIngredients);
        }
      }
      if (from < 14) {
        // v14: more regular and non-organic produce, plus East Asian,
        // Southeast Asian, and South Asian herbs and produce.
        await mergeBuiltinCatalog();
      }
      if (from < 15) {
        // v15: generic grocery names, and Darigold dairy.
        await mergeBuiltinCatalog();
      }
      if (from < 16) {
        // v16: a much larger set of generic grocery names.
        await mergeBuiltinCatalog();
      }
    },
  );

  Future<void> _seedCatalog() => mergeBuiltinCatalog();

  /// Inserts built-in categories and catalog names that this database does not
  /// already have. Custom rows and older built-in names are left in place.
  Future<void> mergeBuiltinCatalog() async {
    final existingNames = {
      for (final row in await select(catalogItems).get())
        row.name.toLowerCase(),
    };
    final existingCategories = {
      for (final row in await select(categories).get()) row.name,
    };
    await batch((b) {
      for (final name in catalogSeed.keys) {
        if (!existingCategories.contains(name)) {
          b.insert(
            categories,
            CategoriesCompanion.insert(name: name, sortOrder: 0),
          );
        }
        final items = catalogSeed[name]!;
        for (final item in items.entries) {
          if (existingNames.add(item.key.toLowerCase())) {
            b.insert(
              catalogItems,
              CatalogItemsCompanion.insert(name: item.key, category: name),
            );
          }
          for (final variant in item.value) {
            if (existingNames.add(variant.toLowerCase())) {
              b.insert(
                catalogItems,
                CatalogItemsCompanion.insert(
                  name: variant,
                  category: name,
                  parentName: Value(item.key),
                ),
              );
            }
          }
        }
      }
    });
    await _resortCategoriesAlphabetically();
  }

  /// Rewrites [categories.sortOrder] so it matches A–Z by name.
  Future<void> _resortCategoriesAlphabetically() async {
    final all = await select(categories).get();
    all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    for (var i = 0; i < all.length; i++) {
      if (all[i].sortOrder == i) continue;
      await (update(categories)..where((t) => t.name.equals(all[i].name)))
          .write(CategoriesCompanion(sortOrder: Value(i)));
    }
  }

  // ---- Catalog ----
  Stream<List<Category>> watchCategories() =>
      (select(categories)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  /// How many variants to show when the query matched their parent, not their
  /// own name. A variant whose name matches is always included.
  static const _unmatchedVariantCap = 8;

  /// Case-insensitive search over item names and their group names.
  ///
  /// Results come back grouped: each matching top-level item (e.g. "Onions")
  /// is followed by its variants (types, cuts, flavours), then any variants
  /// that matched on their own name. Duplicate names are dropped.
  Future<List<CatalogItem>> searchCatalog(
    String query, {
    int limit = 100,
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
              ..limit(1000))
            .get();

    final out = <CatalogItem>[];
    final seen = <String>{};
    void add(CatalogItem i) {
      if (out.length < limit && seen.add(i.name.toLowerCase())) out.add(i);
    }

    final parents = rows.where((i) => i.parentName.isEmpty).toList();
    final parentNames = {for (final parent in parents) parent.name};
    final variants = rows.where((i) => i.parentName.isNotEmpty).toList();
    for (final parent in parents) {
      add(parent);
      final children = variants
          .where((v) => v.parentName == parent.name)
          .toList();
      // Types that do not repeat the search word, such as Sourdough under
      // Bread, are shown before the many names that contain it. Otherwise
      // those names fill the result list and the types never appear.
      var unmatched = 0;
      for (final v in children) {
        if (v.name.toLowerCase().contains(q)) continue;
        if (unmatched >= _unmatchedVariantCap) continue;
        unmatched++;
        add(v);
      }
      for (final v in children) {
        if (!v.name.toLowerCase().contains(q)) continue;
        add(v);
      }
    }
    for (final v in variants) {
      if (parentNames.contains(v.parentName)) continue;
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
            ..where((t) => t.deletedAt.isNull() & t.kind.equals('shopping'))
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

  /// Adds a list of the given [kind] ('shopping' or 'pantry') at the end.
  Future<String> addList(String name, {String kind = 'shopping'}) async {
    final count = (await (select(
      shoppingLists,
    )..where((t) => t.deletedAt.isNull() & t.kind.equals(kind))).get()).length;
    final row = await into(shoppingLists).insertReturning(
      ShoppingListsCompanion.insert(
        name: name,
        sortOrder: Value(count),
        kind: Value(kind),
      ),
    );
    return row.id;
  }

  Stream<List<ShoppingList>> watchPantryLists() =>
      (select(shoppingLists)
            ..where((t) => t.deletedAt.isNull() & t.kind.equals('pantry'))
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.name),
            ]))
          .watch();

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

  // ---- Importing ----

  /// Makes sure every category named in [names] exists, and returns each one's
  /// proper spelling by lower-case name (so "dairy" lands in "Dairy & Eggs"
  /// only if that is what the file said; otherwise a new category is added).
  Future<Map<String, String>> _canonicalCategories(
    Iterable<String> names,
  ) async {
    final existing = {
      for (final c in await select(categories).get())
        c.name.toLowerCase(): c.name,
    };
    for (final raw in names) {
      final n = raw.trim();
      if (n.isEmpty || existing.containsKey(n.toLowerCase())) continue;
      await addCategory(n);
      existing[n.toLowerCase()] = n;
    }
    return existing;
  }

  /// Adds items read from a CSV file to a shopping list. Categories the file
  /// names that do not exist yet are created. Returns how many were added.
  Future<int> importShoppingItems(
    String listId,
    List<ShoppingCsvRow> rows,
  ) async {
    final canon = await _canonicalCategories(rows.map((r) => r.category));
    String cat(String c) => canon[c.trim().toLowerCase()] ?? '';
    await transaction(() async {
      for (final r in rows) {
        await into(shoppingItems).insert(
          ShoppingItemsCompanion.insert(
            listId: listId,
            name: r.name,
            quantity: Value(r.quantity),
            unit: Value(r.unit),
            category: Value(cat(r.category)),
            checked: Value(r.checked),
            price: Value(r.price),
            note: Value(r.note),
            taxable: const Value(true),
            hasCoupon: Value(r.coupon),
          ),
        );
      }
    });
    for (final r in rows) {
      await recordHistory(r.name, cat(r.category), r.unit);
    }
    return rows.length;
  }

  /// Adds items read from a CSV file to a pantry list. Returns how many.
  Future<int> importPantryItems(String listId, List<PantryCsvRow> rows) async {
    final canon = await _canonicalCategories(rows.map((r) => r.category));
    String cat(String c) => canon[c.trim().toLowerCase()] ?? '';
    await transaction(() async {
      for (final r in rows) {
        await into(pantryItems).insert(
          PantryItemsCompanion.insert(
            name: r.name,
            quantity: Value(r.quantity),
            unit: Value(r.unit),
            category: Value(cat(r.category)),
            location: Value(r.location),
            expiryDate: Value(r.expiry),
            note: Value(r.note),
            listId: Value(listId),
            quantityMode: Value(r.mode),
            level: Value(r.level),
          ),
        );
      }
    });
    return rows.length;
  }

  // ---- Moving and copying items between lists ----

  /// Moves shopping items to [listId]. Returns each item's previous list so
  /// the move can be undone with [restoreShoppingLists].
  Future<Map<String, String>> moveShoppingItems(
    List<String> ids,
    String listId,
  ) async {
    final before = <String, String>{};
    await transaction(() async {
      final rows = await (select(
        shoppingItems,
      )..where((t) => t.id.isIn(ids))).get();
      for (final r in rows) {
        before[r.id] = r.listId;
      }
      await (update(shoppingItems)..where((t) => t.id.isIn(ids))).write(
        ShoppingItemsCompanion(
          listId: Value(listId),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
    return before;
  }

  /// Puts items back on the lists they were moved from.
  Future<void> restoreShoppingLists(Map<String, String> before) =>
      transaction(() async {
        for (final e in before.entries) {
          await (update(shoppingItems)..where((t) => t.id.equals(e.key))).write(
            ShoppingItemsCompanion(
              listId: Value(e.value),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      });

  /// Copies shopping items onto [listId] (they arrive unchecked). Returns the
  /// new items' ids.
  Future<List<String>> copyShoppingItems(
    List<ShoppingItem> items,
    String listId,
  ) async {
    final ids = <String>[];
    for (final i in items) {
      final row = await into(shoppingItems).insertReturning(
        ShoppingItemsCompanion.insert(
          listId: listId,
          name: i.name,
          quantity: Value(i.quantity),
          unit: Value(i.unit),
          category: Value(i.category),
          price: Value(i.price),
          note: Value(i.note),
          taxable: Value(i.taxable),
          hasCoupon: Value(i.hasCoupon),
          taxManual: Value(i.taxManual),
        ),
      );
      ids.add(row.id);
    }
    return ids;
  }

  /// Puts checked shopping items into a pantry list.
  ///
  /// A name already on that list is filled (Low becomes Full, or the exact
  /// amount increases). A new name is added in the list's amount style.
  /// The result is what changed, so the screen can undo it.
  Future<PantryStockUndo> stockShoppingInPantry(
    List<ShoppingItem> items,
    String pantryListId,
  ) async {
    final lists =
        await (select(shoppingLists)
              ..where((t) => t.deletedAt.isNull() & t.kind.equals('pantry'))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    final list = lists.where((l) => l.id == pantryListId).firstOrNull;
    final mode = list?.quantityMode ?? 'level';
    final created = <String>[];
    final levels = <String, String>{};
    final quantities = <String, double>{};
    final now = DateTime.now();
    await transaction(() async {
      for (final item in items) {
        final existing =
            await (select(pantryItems)
                  ..where(
                    (t) =>
                        t.deletedAt.isNull() &
                        t.listId.equals(pantryListId) &
                        t.name.lower().equals(item.name.toLowerCase()),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (existing == null) {
          final row = await into(pantryItems).insertReturning(
            PantryItemsCompanion.insert(
              name: item.name,
              quantity: Value(item.quantity <= 0 ? 1 : item.quantity),
              unit: Value(item.unit),
              category: Value(item.category),
              note: Value(item.note),
              listId: Value(pantryListId),
              quantityMode: Value(mode),
              level: const Value('full'),
            ),
          );
          created.add(row.id);
          await _rememberItem(item.name, item.category, item.unit);
          continue;
        }
        if (existing.quantityMode == 'level') {
          if (existing.level == 'full') continue;
          levels[existing.id] = existing.level;
          await (update(
            pantryItems,
          )..where((t) => t.id.equals(existing.id))).write(
            PantryItemsCompanion(
              level: const Value('full'),
              updatedAt: Value(now),
            ),
          );
        } else {
          quantities[existing.id] = existing.quantity;
          final add = item.quantity <= 0 ? 1 : item.quantity;
          await (update(
            pantryItems,
          )..where((t) => t.id.equals(existing.id))).write(
            PantryItemsCompanion(
              quantity: Value(existing.quantity + add),
              updatedAt: Value(now),
            ),
          );
        }
      }
    });
    return PantryStockUndo(
      createdIds: created,
      previousLevels: levels,
      previousQuantities: quantities,
    );
  }

  /// Reverses [stockShoppingInPantry].
  Future<void> undoPantryStock(PantryStockUndo undo) async {
    final now = DateTime.now();
    await transaction(() async {
      if (undo.createdIds.isNotEmpty) {
        await (update(
          pantryItems,
        )..where((t) => t.id.isIn(undo.createdIds))).write(
          PantryItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
      }
      for (final entry in undo.previousLevels.entries) {
        await (update(pantryItems)..where((t) => t.id.equals(entry.key))).write(
          PantryItemsCompanion(
            level: Value(entry.value),
            updatedAt: Value(now),
          ),
        );
      }
      for (final entry in undo.previousQuantities.entries) {
        await (update(pantryItems)..where((t) => t.id.equals(entry.key))).write(
          PantryItemsCompanion(
            quantity: Value(entry.value),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  /// Adds shopping items to a pantry list (the first one if [listId] is not
  /// given). Returns the new pantry items' ids.
  Future<List<String>> copyShoppingToPantry(
    List<ShoppingItem> items, {
    String? listId,
  }) async {
    final lists =
        await (select(shoppingLists)
              ..where((t) => t.deletedAt.isNull() & t.kind.equals('pantry'))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    final list = listId == null
        ? lists.firstOrNull
        : lists.where((l) => l.id == listId).firstOrNull;
    final ids = <String>[];
    for (final i in items) {
      final row = await into(pantryItems).insertReturning(
        PantryItemsCompanion.insert(
          name: i.name,
          quantity: Value(i.quantity),
          unit: Value(i.unit),
          category: Value(i.category),
          note: Value(i.note),
          listId: Value(list?.id ?? listId ?? ''),
          // Shopping quantities are exact, so they stay as numbers.
          quantityMode: const Value('number'),
        ),
      );
      ids.add(row.id);
    }
    return ids;
  }

  /// Adds pantry items to a shopping list (to restock them). Returns the new
  /// shopping items' ids.
  Future<List<String>> copyPantryToShopping(
    List<PantryItem> items,
    String listId,
  ) async {
    final ids = <String>[];
    for (final i in items) {
      final row = await into(shoppingItems).insertReturning(
        ShoppingItemsCompanion.insert(
          listId: listId,
          name: i.name,
          quantity: Value(i.quantity),
          unit: Value(i.unit),
          category: Value(i.category),
          note: Value(i.note),
          taxable: const Value(true),
        ),
      );
      ids.add(row.id);
    }
    return ids;
  }

  Future<void> deleteShoppingItems(List<String> ids) {
    final now = DateTime.now();
    return (update(shoppingItems)..where((t) => t.id.isIn(ids))).write(
      ShoppingItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<void> deletePantryItems(List<String> ids) {
    final now = DateTime.now();
    return (update(pantryItems)..where((t) => t.id.isIn(ids))).write(
      PantryItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<void> restorePantryItems(List<String> ids) =>
      (update(pantryItems)..where((t) => t.id.isIn(ids))).write(
        PantryItemsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  // ---- Categories ----

  /// Adds a category (ignored if one with that name exists, ignoring case).
  /// New names are inserted into alphabetical order automatically.
  Future<void> addCategory(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final all = await select(categories).get();
    if (all.any((c) => c.name.toLowerCase() == clean.toLowerCase())) return;
    await into(categories)
        .insert(CategoriesCompanion.insert(name: clean, sortOrder: all.length));
    await _resortCategoriesAlphabetically();
  }

  /// The stored spelling of [name], creating the category when it is new.
  ///
  /// "produce" and "Produce" are the same header, so an edited item lands in
  /// the category the list already shows.
  Future<String> matchCategoryName(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return '';
    final all = await select(categories).get();
    for (final category in all) {
      if (category.name.toLowerCase() == clean.toLowerCase()) {
        return category.name;
      }
    }
    await addCategory(clean);
    return clean;
  }

  /// Moves one shopping item under [category] and remembers that name there.
  Future<void> fileShoppingItemInCategory(String id, String category) async {
    final filed = await matchCategoryName(category);
    if (filed.isEmpty || filed.toLowerCase() == 'other') return;
    final item = await (select(
      shoppingItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (item == null || item.deletedAt != null) return;
    if (item.category.toLowerCase() == filed.toLowerCase()) return;
    await (update(shoppingItems)..where((t) => t.id.equals(id))).write(
      ShoppingItemsCompanion(
        category: Value(filed),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await assignCategory(item.name, filed);
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
  ///
  /// Touches the list's updated time so the order is included the next time
  /// lists are shared with another device.
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
        await (update(shoppingLists)..where((t) => t.id.equals(listId))).write(
          ShoppingListsCompanion(updatedAt: Value(DateTime.now())),
        );
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

  /// Soft-deletes every history entry (Clear all history). Lists are untouched.
  Future<void> clearAllHistory() {
    final now = DateTime.now();
    return (update(itemHistory)..where((t) => t.deletedAt.isNull())).write(
      ItemHistoryCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

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
      await (update(pantryItems)..where((t) => t.listId.equals(id))).write(
        PantryItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
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
      await (update(
        shoppingLists,
      )..where((t) => t.deletedAt.isNull() & t.kind.equals('shopping'))).write(
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
        // New items are taxed by default; untick per item.
        taxable: const Value(true),
      ),
    );
    await _rememberItem(name, category, unit);
    await recordHistory(name, category, unit);
    return row.id;
  }

  /// Adds [name] to [listId] when that list does not already have it.
  ///
  /// Returns the new id, or null when the name is already on the list.
  Future<String?> addNameToShoppingList(
    String listId,
    String name, {
    String category = '',
    String unit = '',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final existing =
        await (select(shoppingItems)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.listId.equals(listId) &
                    t.name.lower().equals(trimmed.toLowerCase()),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return null;
    return addShoppingItem(listId, trimmed, unit: unit, category: category);
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
  /// Pantry items, from one list or (with no [listId]) every pantry list.
  Stream<List<PantryItem>> watchPantry({String? listId}) =>
      (select(pantryItems)
            ..where(
              (t) =>
                  t.deletedAt.isNull() &
                  (listId == null
                      ? const Constant(true)
                      : t.listId.equals(listId)),
            )
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
    String? listId,
  }) async {
    // Default to the first pantry list; its setting says how amounts show.
    final lists =
        await (select(shoppingLists)
              ..where((t) => t.deletedAt.isNull() & t.kind.equals('pantry'))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    final list = listId == null
        ? lists.firstOrNull
        : lists.where((l) => l.id == listId).firstOrNull;
    await into(pantryItems).insert(
      PantryItemsCompanion.insert(
        name: name,
        quantity: Value(quantity),
        unit: Value(unit),
        expiryDate: Value(expiryDate),
        location: Value(location),
        category: Value(category),
        listId: Value(list?.id ?? listId ?? ''),
        quantityMode: Value(list?.quantityMode ?? 'level'),
      ),
    );
    await _rememberItem(name, category, unit);
  }

  /// Marks a pantry item Low or Full.
  Future<void> setPantryLevel(String id, String level) =>
      (update(pantryItems)..where((t) => t.id.equals(id))).write(
        PantryItemsCompanion(
          level: Value(level),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Sets how every item on a pantry list shows its amount ('level' for
  /// Low/Full, 'number' for exact quantities), and what new items use.
  Future<void> setPantryQuantityMode(
    String listId,
    String mode,
  ) => transaction(() async {
    final now = DateTime.now();
    await (update(shoppingLists)..where((t) => t.id.equals(listId))).write(
      ShoppingListsCompanion(quantityMode: Value(mode), updatedAt: Value(now)),
    );
    await (update(pantryItems)..where((t) => t.listId.equals(listId))).write(
      PantryItemsCompanion(quantityMode: Value(mode), updatedAt: Value(now)),
    );
  });

  /// Changes how a single pantry item shows its amount.
  Future<void> setPantryItemMode(String id, String mode) =>
      (update(pantryItems)..where((t) => t.id.equals(id))).write(
        PantryItemsCompanion(
          quantityMode: Value(mode),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Moves pantry items to another pantry list; returns their previous lists
  /// so it can be undone with [restorePantryLists].
  Future<Map<String, String>> movePantryItems(
    List<String> ids,
    String listId,
  ) async {
    final before = <String, String>{};
    await transaction(() async {
      final rows = await (select(
        pantryItems,
      )..where((t) => t.id.isIn(ids))).get();
      for (final r in rows) {
        before[r.id] = r.listId;
      }
      await (update(pantryItems)..where((t) => t.id.isIn(ids))).write(
        PantryItemsCompanion(
          listId: Value(listId),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
    return before;
  }

  Future<void> restorePantryLists(Map<String, String> before) =>
      transaction(() async {
        for (final e in before.entries) {
          await (update(pantryItems)..where((t) => t.id.equals(e.key))).write(
            PantryItemsCompanion(
              listId: Value(e.value),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      });

  /// Copies pantry items onto another pantry list. Returns the new ids.
  Future<List<String>> copyPantryItems(
    List<PantryItem> items,
    String listId,
  ) async {
    final ids = <String>[];
    for (final i in items) {
      final row = await into(pantryItems).insertReturning(
        PantryItemsCompanion.insert(
          name: i.name,
          quantity: Value(i.quantity),
          unit: Value(i.unit),
          expiryDate: Value(i.expiryDate),
          location: Value(i.location),
          category: Value(i.category),
          note: Value(i.note),
          listId: Value(listId),
          quantityMode: Value(i.quantityMode),
          level: Value(i.level),
        ),
      );
      ids.add(row.id);
    }
    return ids;
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
    String? quantityMode,
    String? level,
  }) => (update(pantryItems)..where((t) => t.id.equals(id))).write(
    PantryItemsCompanion(
      name: Value(name),
      quantity: Value(quantity),
      unit: Value(unit),
      category: Value(category),
      location: Value(location),
      expiryDate: Value(expiryDate),
      note: Value(note),
      quantityMode: quantityMode == null
          ? const Value.absent()
          : Value(quantityMode),
      level: level == null ? const Value.absent() : Value(level),
      updatedAt: Value(DateTime.now()),
    ),
  );

  Future<void> deletePantryItem(String id) {
    final now = DateTime.now();
    return (update(pantryItems)..where((t) => t.id.equals(id))).write(
      PantryItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  // ---- Recipes ----

  Stream<List<Recipe>> watchRecipes() =>
      (select(recipes)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Stream<List<RecipeIngredient>> watchRecipeIngredients(String recipeId) =>
      (select(recipeIngredients)
            ..where((t) => t.recipeId.equals(recipeId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Future<List<RecipeIngredient>> recipeIngredientsFor(String recipeId) =>
      (select(recipeIngredients)
            ..where((t) => t.recipeId.equals(recipeId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Future<String> addRecipe(String name, {double servings = 4}) async {
    final row = await into(recipes).insertReturning(
      RecipesCompanion.insert(name: name, servings: Value(servings)),
    );
    return row.id;
  }

  Future<void> updateRecipe(
    String id, {
    required String name,
    required double servings,
    String note = '',
  }) => (update(recipes)..where((t) => t.id.equals(id))).write(
    RecipesCompanion(
      name: Value(name),
      servings: Value(servings <= 0 ? 1 : servings),
      note: Value(note),
      updatedAt: Value(DateTime.now()),
    ),
  );

  Future<void> deleteRecipe(String id) async {
    final now = DateTime.now();
    await transaction(() async {
      await (update(recipes)..where((t) => t.id.equals(id))).write(
        RecipesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (update(
        recipeIngredients,
      )..where((t) => t.recipeId.equals(id))).write(
        RecipeIngredientsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    });
  }

  Future<String> addRecipeIngredient(
    String recipeId,
    String name, {
    double quantity = 1,
    String unit = '',
    String category = '',
  }) async {
    final existing =
        await (select(recipeIngredients)
              ..where((t) => t.recipeId.equals(recipeId))
              ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
              ..limit(1))
            .getSingleOrNull();
    final row = await into(recipeIngredients).insertReturning(
      RecipeIngredientsCompanion.insert(
        recipeId: recipeId,
        name: name,
        quantity: Value(quantity <= 0 ? 1 : quantity),
        unit: Value(unit),
        category: Value(category),
        sortOrder: Value((existing?.sortOrder ?? -1) + 1),
      ),
    );
    await _rememberItem(name, category, unit);
    return row.id;
  }

  Future<void> updateRecipeIngredient(
    String id, {
    required String name,
    required double quantity,
    required String unit,
    required String category,
  }) => (update(recipeIngredients)..where((t) => t.id.equals(id))).write(
    RecipeIngredientsCompanion(
      name: Value(name),
      quantity: Value(quantity <= 0 ? 1 : quantity),
      unit: Value(unit),
      category: Value(category),
      updatedAt: Value(DateTime.now()),
    ),
  );

  Future<void> deleteRecipeIngredient(String id) {
    final now = DateTime.now();
    return (update(recipeIngredients)..where((t) => t.id.equals(id))).write(
      RecipeIngredientsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// What to put on a shopping list for [recipeId] at [cookServings], after
  /// subtracting what the pantry already covers.
  Future<RecipeShopPlan> planRecipeShop(
    String recipeId, {
    required double cookServings,
  }) async {
    final recipe = await (select(
      recipes,
    )..where((t) => t.id.equals(recipeId))).getSingle();
    final ingredients = await recipeIngredientsFor(recipeId);
    final stock = await (select(
      pantryItems,
    )..where((t) => t.deletedAt.isNull())).get();
    return planRecipeAgainstPantry(
      ingredients: ingredients,
      baseServings: recipe.servings,
      cookServings: cookServings,
      pantry: stock,
    );
  }

  /// Adds the planned lines to [listId]. An item already on that list has its
  /// quantity increased. [recipeName] is stored on a new line's note.
  Future<void> applyRecipeShopPlan(
    String listId,
    RecipeShopPlan plan, {
    String recipeName = '',
  }) async {
    final note = recipeName.isEmpty ? '' : 'For $recipeName';
    for (final line in plan.add) {
      final existing =
          await (select(shoppingItems)
                ..where(
                  (t) =>
                      t.listId.equals(listId) &
                      t.deletedAt.isNull() &
                      t.name.lower().equals(line.name.toLowerCase()),
                )
                ..limit(1))
              .getSingleOrNull();
      if (existing == null) {
        await addShoppingItem(
          listId,
          line.name,
          quantity: line.quantity,
          unit: line.unit,
          category: line.category,
        );
        if (note.isNotEmpty) {
          final rows =
              await (select(shoppingItems)
                    ..where(
                      (t) =>
                          t.listId.equals(listId) &
                          t.name.lower().equals(line.name.toLowerCase()),
                    )
                    ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
                    ..limit(1))
                  .get();
          if (rows.isNotEmpty && rows.first.note.isEmpty) {
            await (update(
              shoppingItems,
            )..where((t) => t.id.equals(rows.first.id))).write(
              ShoppingItemsCompanion(
                note: Value(note),
                updatedAt: Value(DateTime.now()),
              ),
            );
          }
        }
      } else {
        await (update(
          shoppingItems,
        )..where((t) => t.id.equals(existing.id))).write(
          ShoppingItemsCompanion(
            quantity: Value(existing.quantity + line.quantity),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    }
  }

  /// Subtracts a cooked recipe from pantry stock.
  Future<void> cookRecipe(
    String recipeId, {
    required double cookServings,
  }) async {
    final recipe = await (select(
      recipes,
    )..where((t) => t.id.equals(recipeId))).getSingle();
    final ingredients = await recipeIngredientsFor(recipeId);
    final scale = cookServings <= 0 || recipe.servings <= 0
        ? 1.0
        : cookServings / recipe.servings;
    final now = DateTime.now();
    await transaction(() async {
      for (final line in ingredients) {
        final used = line.quantity * scale;
        final rows =
            await (select(pantryItems)..where(
                  (t) =>
                      t.deletedAt.isNull() &
                      t.name.lower().equals(line.name.toLowerCase()),
                ))
                .get();
        for (final row in rows) {
          if (row.quantityMode == 'level') {
            await (update(
              pantryItems,
            )..where((t) => t.id.equals(row.id))).write(
              PantryItemsCompanion(
                level: const Value('low'),
                updatedAt: Value(now),
              ),
            );
          } else if (unitsMatch(row.unit, line.unit)) {
            await (update(
              pantryItems,
            )..where((t) => t.id.equals(row.id))).write(
              PantryItemsCompanion(
                quantity: Value(
                  row.quantity - used < 0 ? 0 : row.quantity - used,
                ),
                updatedAt: Value(now),
              ),
            );
          }
        }
      }
    });
  }

  // ---- Barcodes ----

  Future<CatalogItem?> catalogByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    return (select(catalogItems)
          ..where((t) => t.deletedAt.isNull() & t.barcode.equals(code))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Stores [barcode] on the catalog row for [name], or creates a custom row.
  Future<void> linkBarcode(
    String barcode,
    String name, {
    String category = 'Other',
    String unit = '',
  }) async {
    final code = barcode.trim();
    final trimmed = name.trim();
    if (code.isEmpty || trimmed.isEmpty) return;
    final now = DateTime.now();
    final match =
        await (select(catalogItems)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.name.lower().equals(trimmed.toLowerCase()),
              )
              ..limit(1))
            .getSingleOrNull();
    if (match != null) {
      await (update(catalogItems)..where((t) => t.id.equals(match.id))).write(
        CatalogItemsCompanion(barcode: Value(code), updatedAt: Value(now)),
      );
      return;
    }
    await into(catalogItems).insert(
      CatalogItemsCompanion.insert(
        name: trimmed,
        category: category.isEmpty ? 'Other' : category,
        defaultUnit: Value(unit),
        isCustom: const Value(true),
        barcode: Value(code),
      ),
    );
  }

  /// Adds [name] to the pantry, or increases the count when that name is
  /// already there.
  Future<void> addOrBumpPantry(
    String name, {
    String category = '',
    String unit = '',
    String? listId,
  }) async {
    final existing =
        await (select(pantryItems)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.name.lower().equals(name.toLowerCase()),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing == null) {
      await addPantryItem(name, category: category, unit: unit, listId: listId);
      return;
    }
    if (existing.quantityMode == 'level') {
      await setPantryLevel(existing.id, 'full');
      return;
    }
    await updatePantryQuantity(existing.id, existing.quantity + 1);
  }
}

/// What [AppDatabase.stockShoppingInPantry] changed, so it can be undone.
class PantryStockUndo {
  const PantryStockUndo({
    this.createdIds = const [],
    this.previousLevels = const {},
    this.previousQuantities = const {},
  });

  final List<String> createdIds;
  final Map<String, String> previousLevels;
  final Map<String, double> previousQuantities;

  bool get changed =>
      createdIds.isNotEmpty ||
      previousLevels.isNotEmpty ||
      previousQuantities.isNotEmpty;

  int get count =>
      createdIds.length + previousLevels.length + previousQuantities.length;
}

Future<AppDatabase> openAppDatabase() async {
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, 'shop_it.sqlite'));
  return AppDatabase(NativeDatabase.createInBackground(file));
}
