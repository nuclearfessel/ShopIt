import 'package:drift/drift.dart';

import 'database.dart';

/// A failure with a message that is safe to show the user.
class SyncException implements Exception {
  const SyncException(this.message);
  final String message;

  @override
  String toString() => message;
}

const syncSnapshotVersion = 1;

/// One device's lists and everything that belongs on them, including rows that
/// have been deleted, so the other device can apply the deletion.
class SyncSnapshot {
  const SyncSnapshot({
    required this.lists,
    required this.shoppingItems,
    required this.pantryItems,
    required this.taxRates,
    required this.history,
    required this.catalog,
    required this.categories,
    required this.categoryOrders,
  });

  final List<Map<String, Object?>> lists;
  final List<Map<String, Object?>> shoppingItems;
  final List<Map<String, Object?>> pantryItems;
  final List<Map<String, Object?>> taxRates;
  final List<Map<String, Object?>> history;
  final List<Map<String, Object?>> catalog;
  final List<Map<String, Object?>> categories;
  final List<Map<String, Object?>> categoryOrders;

  Map<String, Object?> toJson() => {
    'v': syncSnapshotVersion,
    'lists': lists,
    'shoppingItems': shoppingItems,
    'pantryItems': pantryItems,
    'taxRates': taxRates,
    'history': history,
    'catalog': catalog,
    'categories': categories,
    'categoryOrders': categoryOrders,
  };

  factory SyncSnapshot.fromJson(Map<dynamic, dynamic> json) {
    if (json['v'] != syncSnapshotVersion) {
      throw const SyncException(
        'The other device is running a different version of Shop-it.',
      );
    }
    return SyncSnapshot(
      lists: _mapList(json['lists']),
      shoppingItems: _mapList(json['shoppingItems']),
      pantryItems: _mapList(json['pantryItems']),
      taxRates: _mapList(json['taxRates']),
      history: _mapList(json['history']),
      catalog: _mapList(json['catalog']),
      categories: _mapList(json['categories']),
      categoryOrders: _mapList(json['categoryOrders']),
    );
  }
}

/// Reads and merges the shared snapshot. The newer [updatedAt] wins; a row the
/// other device does not have yet is always taken.
extension DeviceSync on AppDatabase {
  Future<SyncSnapshot> exportSnapshot() => transaction(() async {
    final lists = await select(shoppingLists).get();
    final shopping = await select(shoppingItems).get();
    final pantry = await select(pantryItems).get();
    final rates = await select(taxRates).get();
    final history = await select(itemHistory).get();
    final catalog = await (select(
      catalogItems,
    )..where((t) => t.isCustom.equals(true))).get();
    final categories = await select(this.categories).get();
    final orders = await select(listCategoryOrders).get();
    return SyncSnapshot(
      lists: [for (final row in lists) _listJson(row)],
      shoppingItems: [for (final row in shopping) _shoppingJson(row)],
      pantryItems: [for (final row in pantry) _pantryJson(row)],
      taxRates: [for (final row in rates) _taxJson(row)],
      history: [for (final row in history) _historyJson(row)],
      catalog: [for (final row in catalog) _catalogJson(row)],
      categories: [
        for (final row in categories)
          {'name': row.name, 'sortOrder': row.sortOrder, 'color': row.color},
      ],
      categoryOrders: [
        for (final row in orders)
          {
            'listId': row.listId,
            'category': row.category,
            'position': row.position,
          },
      ],
    );
  });

  /// Applies [remote]. Rows already here with a newer [updatedAt] are left as
  /// they are, so an edit made while the sync is in flight is not lost.
  ///
  /// A remote list with the same name and kind as a local list is folded into
  /// that local list instead of creating a second copy. Items on the remote
  /// list are remapped onto it, and an item with the same name on that list is
  /// merged rather than duplicated.
  Future<void> applySnapshot(SyncSnapshot remote) => transaction(() async {
    await _applyTaxRates(remote.taxRates);
    final lists = await _applyLists(remote.lists);
    final itemCategories = <String>{};
    await _applyShoppingItems(
      remote.shoppingItems,
      itemCategories,
      lists.aliases,
    );
    await _applyPantryItems(
      remote.pantryItems,
      itemCategories,
      lists.aliases,
    );
    await _applyCategories(remote.categories, itemCategories);
    await _applyHistory(remote.history);
    await _applyCatalog(remote.catalog);
    await _applyOrders(remote.categoryOrders, lists);
  });

  Future<void> _applyTaxRates(List<Map<String, Object?>> rows) async {
    for (final row in rows) {
      final id = _id(row);
      final at = _updatedAt(row);
      final name = _string(row, 'name');
      if (id == null || at == null || name.isEmpty) continue;
      final local = await (select(
        taxRates,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (local != null &&
          !_take(at, local.updatedAt, _identical(_taxJson(local), row))) {
        continue;
      }
      final values = TaxRatesCompanion(
        name: Value(name),
        percent: Value(_double(row, 'percent')),
        ruleSet: Value(_string(row, 'ruleSet', 'everything')),
        groceryPercent: Value(_doubleOrNull(row, 'groceryPercent')),
        updatedAt: Value(at),
        deletedAt: Value(_date(row, 'deletedAt')),
      );
      if (local == null) {
        await into(taxRates).insert(values.copyWith(id: Value(id)));
      } else {
        await (update(taxRates)..where((t) => t.id.equals(id))).write(values);
      }
    }
  }

  /// Returns the ids of lists that were inserted or updated, which of those
  /// are deleted, and remote-to-local id aliases for same-name merges.
  Future<({Set<String> changed, Set<String> deleted, Map<String, String> aliases})>
  _applyLists(List<Map<String, Object?>> rows) async {
    final changed = <String>{};
    final deleted = <String>{};
    final aliases = <String, String>{};
    for (final row in rows) {
      final id = _id(row);
      final at = _updatedAt(row);
      final name = _string(row, 'name');
      if (id == null || at == null || name.isEmpty) continue;
      final kind = _string(row, 'kind', 'shopping');
      final resolvedKind = kind.isEmpty ? 'shopping' : kind;
      final remoteDeleted = _date(row, 'deletedAt') != null;

      var local = await (select(
        shoppingLists,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      // Same name and kind on this device: keep the oldest twin and fold into
      // it. Extra local copies of that name are soft-deleted so sync does not
      // leave two "Groceries" lists behind.
      if (!remoteDeleted) {
        final twins = await _listsByName(name, resolvedKind);
        if (twins.isNotEmpty) {
          final keeper = twins.first;
          if (local == null || local.id != keeper.id) {
            aliases[id] = keeper.id;
            if (local != null && local.id != keeper.id) {
              aliases[local.id] = keeper.id;
            }
            local = keeper;
          }
          for (final extra in twins.skip(1)) {
            await _foldListInto(extra, keeper);
            aliases[extra.id] = keeper.id;
            changed.add(keeper.id);
            deleted.add(extra.id);
          }
        }
      }

      final targetId = local?.id ?? id;
      if (local != null &&
          !_take(at, local.updatedAt, _identical(_listJson(local), row))) {
        // Still remember the alias so items on the remote id land here.
        if (targetId != id) aliases[id] = targetId;
        continue;
      }
      final mode = _string(row, 'quantityMode', 'level');
      final values = ShoppingListsCompanion(
        name: Value(name),
        taxRateId: Value(_optString(row, 'taxRateId')),
        useCategories: Value(_bool(row, 'useCategories', true)),
        autoCategorize: Value(_bool(row, 'autoCategorize', true)),
        showEmptyCategories: Value(_bool(row, 'showEmptyCategories', false)),
        sortOrder: Value(_int(row, 'sortOrder')),
        kind: Value(resolvedKind),
        quantityMode: Value(mode.isEmpty ? 'level' : mode),
        updatedAt: Value(at),
        deletedAt: Value(_date(row, 'deletedAt')),
      );
      if (local == null) {
        await into(shoppingLists).insert(values.copyWith(id: Value(id)));
      } else {
        await (update(
          shoppingLists,
        )..where((t) => t.id.equals(targetId))).write(values);
      }
      changed.add(targetId);
      if (targetId != id) aliases[id] = targetId;
      if (remoteDeleted) deleted.add(targetId);
    }
    return (changed: changed, deleted: deleted, aliases: aliases);
  }

  Future<List<ShoppingList>> _listsByName(String name, String kind) async {
    final needle = name.trim().toLowerCase();
    final rows = await (select(shoppingLists)..where(
          (t) => t.deletedAt.isNull() & t.kind.equals(kind),
        ))
        .get();
    final matches = [
      for (final row in rows)
        if (row.name.trim().toLowerCase() == needle) row,
    ];
    matches.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return matches;
  }

  /// Moves items from [extra] onto [keeper] and soft-deletes [extra].
  Future<void> _foldListInto(ShoppingList extra, ShoppingList keeper) async {
    final now = DateTime.now().toUtc();
    final shopping = await (select(
      shoppingItems,
    )..where((t) => t.listId.equals(extra.id) & t.deletedAt.isNull())).get();
    for (final item in shopping) {
      final twin = await _shoppingItemByName(keeper.id, item.name);
      if (twin == null) {
        await (update(shoppingItems)..where((t) => t.id.equals(item.id))).write(
          ShoppingItemsCompanion(
            listId: Value(keeper.id),
            updatedAt: Value(now),
          ),
        );
      } else {
        await (update(shoppingItems)..where((t) => t.id.equals(item.id))).write(
          ShoppingItemsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }
    }
    final pantry = await (select(
      pantryItems,
    )..where((t) => t.listId.equals(extra.id) & t.deletedAt.isNull())).get();
    for (final item in pantry) {
      final twin = await _pantryItemByName(keeper.id, item.name);
      if (twin == null) {
        await (update(pantryItems)..where((t) => t.id.equals(item.id))).write(
          PantryItemsCompanion(
            listId: Value(keeper.id),
            updatedAt: Value(now),
          ),
        );
      } else {
        await (update(pantryItems)..where((t) => t.id.equals(item.id))).write(
          PantryItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
      }
    }
    await (update(shoppingLists)..where((t) => t.id.equals(extra.id))).write(
      ShoppingListsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<void> _applyShoppingItems(
    List<Map<String, Object?>> rows,
    Set<String> categories,
    Map<String, String> listAliases,
  ) async {
    for (final row in rows) {
      final id = _id(row);
      final at = _updatedAt(row);
      final rawListId = _string(row, 'listId');
      final name = _string(row, 'name');
      if (id == null || at == null || rawListId.isEmpty || name.isEmpty) {
        continue;
      }
      final listId = listAliases[rawListId] ?? rawListId;
      var local = await (select(
        shoppingItems,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      local ??= await _shoppingItemByName(listId, name);
      if (local != null &&
          !_take(at, local.updatedAt, _identical(_shoppingJson(local), row))) {
        continue;
      }
      final category = _string(row, 'category');
      if (category.isNotEmpty) categories.add(category);
      final values = ShoppingItemsCompanion(
        listId: Value(listId),
        name: Value(name),
        quantity: Value(_double(row, 'quantity', 1)),
        unit: Value(_string(row, 'unit')),
        checked: Value(_bool(row, 'checked', false)),
        category: Value(category),
        price: Value(_doubleOrNull(row, 'price')),
        note: Value(_string(row, 'note')),
        taxable: Value(_bool(row, 'taxable', false)),
        hasCoupon: Value(_bool(row, 'hasCoupon', false)),
        taxManual: Value(_bool(row, 'taxManual', false)),
        updatedAt: Value(at),
        deletedAt: Value(_date(row, 'deletedAt')),
      );
      if (local == null) {
        await into(shoppingItems).insert(values.copyWith(id: Value(id)));
      } else {
        await (update(
          shoppingItems,
        )..where((t) => t.id.equals(local!.id))).write(values);
      }
    }
  }

  Future<ShoppingItem?> _shoppingItemByName(String listId, String name) async {
    final needle = name.trim().toLowerCase();
    final rows = await (select(shoppingItems)..where(
          (t) => t.deletedAt.isNull() & t.listId.equals(listId),
        ))
        .get();
    for (final row in rows) {
      if (row.name.trim().toLowerCase() == needle) return row;
    }
    return null;
  }

  Future<void> _applyPantryItems(
    List<Map<String, Object?>> rows,
    Set<String> categories,
    Map<String, String> listAliases,
  ) async {
    for (final row in rows) {
      final id = _id(row);
      final at = _updatedAt(row);
      final name = _string(row, 'name');
      if (id == null || at == null || name.isEmpty) continue;
      final rawListId = _string(row, 'listId');
      final listId = listAliases[rawListId] ?? rawListId;
      var local = await (select(
        pantryItems,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (local == null && listId.isNotEmpty) {
        local = await _pantryItemByName(listId, name);
      }
      if (local != null &&
          !_take(at, local.updatedAt, _identical(_pantryJson(local), row))) {
        continue;
      }
      final category = _string(row, 'category');
      if (category.isNotEmpty) categories.add(category);
      final mode = _string(row, 'quantityMode', 'level');
      final level = _string(row, 'level', 'full');
      final values = PantryItemsCompanion(
        name: Value(name),
        quantity: Value(_double(row, 'quantity', 1)),
        unit: Value(_string(row, 'unit')),
        expiryDate: Value(_date(row, 'expiryDate')),
        location: Value(_string(row, 'location')),
        category: Value(category),
        note: Value(_string(row, 'note')),
        listId: Value(listId),
        quantityMode: Value(mode.isEmpty ? 'level' : mode),
        level: Value(level.isEmpty ? 'full' : level),
        updatedAt: Value(at),
        deletedAt: Value(_date(row, 'deletedAt')),
      );
      if (local == null) {
        await into(pantryItems).insert(values.copyWith(id: Value(id)));
      } else {
        await (update(
          pantryItems,
        )..where((t) => t.id.equals(local!.id))).write(values);
      }
    }
  }

  Future<PantryItem?> _pantryItemByName(String listId, String name) async {
    final needle = name.trim().toLowerCase();
    final rows = await (select(pantryItems)..where(
          (t) => t.deletedAt.isNull() & t.listId.equals(listId),
        ))
        .get();
    for (final row in rows) {
      if (row.name.trim().toLowerCase() == needle) return row;
    }
    return null;
  }

  Future<void> _applyCategories(
    List<Map<String, Object?>> rows,
    Set<String> extraNames,
  ) async {
    final existing = {
      for (final row in await select(categories).get())
        row.name.toLowerCase(): row,
    };
    for (final row in rows) {
      final name = _string(row, 'name').trim();
      if (name.isEmpty) continue;
      final color = _color(row);
      final local = existing[name.toLowerCase()];
      if (local == null) {
        await into(categories).insert(
          CategoriesCompanion.insert(
            name: name,
            sortOrder: _int(row, 'sortOrder'),
            color: Value(color),
          ),
        );
        continue;
      }
      // No timestamp on a category: only fill a colour the other device has
      // when this one has never chosen one, so the two do not fight.
      if (local.color == null && color != null) {
        await setCategoryColor(local.name, color);
      }
    }
    for (final name in extraNames) {
      await addCategory(name);
    }
  }

  Future<void> _applyHistory(List<Map<String, Object?>> rows) async {
    for (final row in rows) {
      final id = _id(row);
      final at = _updatedAt(row);
      final name = _string(row, 'name');
      if (id == null || at == null || name.isEmpty) continue;
      final local = await (select(
        itemHistory,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (local != null &&
          !_take(at, local.updatedAt, _identical(_historyJson(local), row))) {
        continue;
      }
      final values = ItemHistoryCompanion(
        name: Value(name),
        category: Value(_string(row, 'category')),
        unit: Value(_string(row, 'unit')),
        lastUsed: Value(_date(row, 'lastUsed') ?? at),
        useCount: Value(_int(row, 'useCount', 1)),
        updatedAt: Value(at),
        deletedAt: Value(_date(row, 'deletedAt')),
      );
      if (local == null) {
        await into(itemHistory).insert(values.copyWith(id: Value(id)));
      } else {
        await (update(
          itemHistory,
        )..where((t) => t.id.equals(id))).write(values);
      }
    }
  }

  Future<void> _applyCatalog(List<Map<String, Object?>> rows) async {
    for (final row in rows) {
      if (!_bool(row, 'isCustom', false)) continue;
      final id = _id(row);
      final at = _updatedAt(row);
      final name = _string(row, 'name');
      if (id == null || at == null || name.isEmpty) continue;
      final local = await (select(
        catalogItems,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (local != null &&
          !_take(at, local.updatedAt, _identical(_catalogJson(local), row))) {
        continue;
      }
      final category = _string(row, 'category', 'Other');
      final values = CatalogItemsCompanion(
        name: Value(name),
        category: Value(category.isEmpty ? 'Other' : category),
        defaultUnit: Value(_string(row, 'defaultUnit')),
        isCustom: const Value(true),
        parentName: Value(_string(row, 'parentName')),
        updatedAt: Value(at),
        deletedAt: Value(_date(row, 'deletedAt')),
      );
      if (local == null) {
        await into(catalogItems).insert(values.copyWith(id: Value(id)));
      } else {
        await (update(
          catalogItems,
        )..where((t) => t.id.equals(id))).write(values);
      }
    }
  }

  Future<void> _applyOrders(
    List<Map<String, Object?>> rows,
    ({Set<String> changed, Set<String> deleted, Map<String, String> aliases})
    lists,
  ) async {
    for (final id in lists.changed) {
      await (delete(
        listCategoryOrders,
      )..where((t) => t.listId.equals(id))).go();
      if (lists.deleted.contains(id)) continue;
      final remoteIds = <String>{id};
      for (final entry in lists.aliases.entries) {
        if (entry.value == id) remoteIds.add(entry.key);
      }
      final mine =
          rows
              .where((row) => remoteIds.contains(_string(row, 'listId')))
              .toList()
            ..sort(
              (a, b) => _int(a, 'position').compareTo(_int(b, 'position')),
            );
      for (final row in mine) {
        final category = _string(row, 'category');
        if (category.isEmpty) continue;
        await into(listCategoryOrders).insert(
          ListCategoryOrdersCompanion.insert(
            listId: id,
            category: category,
            position: _int(row, 'position'),
          ),
        );
      }
    }
  }
}

String _iso(DateTime value) => value.toUtc().toIso8601String();

/// Timestamps are stored to the second, so two edits in that second compare
/// equal. The incoming row wins the tie; an identical row is left alone so a
/// later sync does not rewrite it.
bool _take(DateTime remoteAt, DateTime localAt, bool identical) {
  final local = localAt.toUtc();
  if (remoteAt.isAfter(local)) return true;
  return remoteAt.isAtSameMomentAs(local) && !identical;
}

bool _identical(Map<String, Object?> local, Map<String, Object?> remote) {
  for (final entry in local.entries) {
    if (!_equalValue(entry.value, remote[entry.key])) return false;
  }
  return true;
}

bool _equalValue(Object? a, Object? b) {
  if (a == b) return true;
  if (a is num && b is num) return a == b;
  return false;
}

Map<String, Object?> _listJson(ShoppingList row) => {
  'id': row.id,
  'updatedAt': _iso(row.updatedAt),
  'deletedAt': row.deletedAt == null ? null : _iso(row.deletedAt!),
  'name': row.name,
  'taxRateId': row.taxRateId,
  'useCategories': row.useCategories,
  'autoCategorize': row.autoCategorize,
  'showEmptyCategories': row.showEmptyCategories,
  'sortOrder': row.sortOrder,
  'kind': row.kind,
  'quantityMode': row.quantityMode,
};

Map<String, Object?> _shoppingJson(ShoppingItem row) => {
  'id': row.id,
  'updatedAt': _iso(row.updatedAt),
  'deletedAt': row.deletedAt == null ? null : _iso(row.deletedAt!),
  'listId': row.listId,
  'name': row.name,
  'quantity': row.quantity,
  'unit': row.unit,
  'checked': row.checked,
  'category': row.category,
  'price': row.price,
  'note': row.note,
  'taxable': row.taxable,
  'hasCoupon': row.hasCoupon,
  'taxManual': row.taxManual,
};

Map<String, Object?> _pantryJson(PantryItem row) => {
  'id': row.id,
  'updatedAt': _iso(row.updatedAt),
  'deletedAt': row.deletedAt == null ? null : _iso(row.deletedAt!),
  'name': row.name,
  'quantity': row.quantity,
  'unit': row.unit,
  'expiryDate': row.expiryDate == null ? null : _iso(row.expiryDate!),
  'location': row.location,
  'category': row.category,
  'note': row.note,
  'listId': row.listId,
  'quantityMode': row.quantityMode,
  'level': row.level,
};

Map<String, Object?> _taxJson(TaxRate row) => {
  'id': row.id,
  'updatedAt': _iso(row.updatedAt),
  'deletedAt': row.deletedAt == null ? null : _iso(row.deletedAt!),
  'name': row.name,
  'percent': row.percent,
  'ruleSet': row.ruleSet,
  'groceryPercent': row.groceryPercent,
};

Map<String, Object?> _historyJson(HistoryEntry row) => {
  'id': row.id,
  'updatedAt': _iso(row.updatedAt),
  'deletedAt': row.deletedAt == null ? null : _iso(row.deletedAt!),
  'name': row.name,
  'category': row.category,
  'unit': row.unit,
  'lastUsed': _iso(row.lastUsed),
  'useCount': row.useCount,
};

Map<String, Object?> _catalogJson(CatalogItem row) => {
  'id': row.id,
  'updatedAt': _iso(row.updatedAt),
  'deletedAt': row.deletedAt == null ? null : _iso(row.deletedAt!),
  'name': row.name,
  'category': row.category,
  'defaultUnit': row.defaultUnit,
  'isCustom': row.isCustom,
  'parentName': row.parentName,
};

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! List) return const [];
  final out = <Map<String, Object?>>[];
  for (final item in value) {
    if (item is Map) out.add(Map<String, Object?>.from(item));
  }
  return out;
}

String? _id(Map<String, Object?> row) {
  final value = row['id'];
  if (value is String && value.isNotEmpty) return value;
  return null;
}

DateTime? _updatedAt(Map<String, Object?> row) => _date(row, 'updatedAt');

DateTime? _date(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toUtc();
}

String _string(Map<String, Object?> row, String key, [String fallback = '']) {
  final value = row[key];
  return value is String ? value : fallback;
}

String? _optString(Map<String, Object?> row, String key) {
  final value = _string(row, key);
  return value.isEmpty ? null : value;
}

bool _bool(Map<String, Object?> row, String key, bool fallback) {
  final value = row[key];
  if (value is bool) return value;
  return fallback;
}

double _double(Map<String, Object?> row, String key, [double fallback = 0]) {
  final value = row[key];
  if (value is num) return value.toDouble();
  return fallback;
}

double? _doubleOrNull(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is num) return value.toDouble();
  return null;
}

int _int(Map<String, Object?> row, String key, [int fallback = 0]) {
  final value = row[key];
  if (value is num) return value.toInt();
  return fallback;
}

int? _color(Map<String, Object?> row) {
  final value = row['color'];
  if (value is num) return value.toInt();
  return null;
}
