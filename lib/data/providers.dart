import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

/// Overridden in `main()` once the database has been opened.
final databaseProvider = Provider<AppDatabase>(
    (ref) => throw UnimplementedError('databaseProvider must be overridden'));

final listsProvider = StreamProvider<List<ShoppingList>>(
    (ref) => ref.watch(databaseProvider).watchLists());

final shoppingItemsProvider =
    StreamProvider.family<List<ShoppingItem>, String>((ref, listId) =>
        ref.watch(databaseProvider).watchShoppingItems(listId));

final categoriesProvider = StreamProvider<List<Category>>(
    (ref) => ref.watch(databaseProvider).watchCategories());

final catalogSearchProvider = FutureProvider.autoDispose
    .family<List<CatalogItem>, String>(
        (ref, query) => ref.watch(databaseProvider).searchCatalog(query));

final pantryProvider = StreamProvider<List<PantryItem>>(
    (ref) => ref.watch(databaseProvider).watchPantry());
