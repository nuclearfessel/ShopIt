import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

/// Overridden in `main()` once the database has been opened.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final listsProvider = StreamProvider<List<ShoppingList>>(
  (ref) => ref.watch(databaseProvider).watchLists(),
);

final shoppingItemsProvider = StreamProvider.family<List<ShoppingItem>, String>(
  (ref, listId) => ref.watch(databaseProvider).watchShoppingItems(listId),
);

final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(databaseProvider).watchCategories(),
);

final catalogSearchProvider = FutureProvider.autoDispose
    .family<List<CatalogItem>, String>(
      (ref, query) => ref.watch(databaseProvider).searchCatalog(query),
    );

final taxRatesProvider = StreamProvider<List<TaxRate>>(
  (ref) => ref.watch(databaseProvider).watchTaxRates(),
);

final pantryProvider = StreamProvider<List<PantryItem>>(
  (ref) => ref.watch(databaseProvider).watchPantry(),
);

/// The manual category order for one list (empty = use the default order).
final listCategoryOrderProvider =
    StreamProvider.family<List<ListCategoryOrder>, String>(
      (ref, listId) =>
          ref.watch(databaseProvider).watchListCategoryOrder(listId),
    );

/// Previously added items, most recent first.
final historyProvider = StreamProvider<List<HistoryEntry>>(
  (ref) => ref.watch(databaseProvider).watchHistory(),
);
