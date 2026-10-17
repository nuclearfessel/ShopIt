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

/// The pantry lists (kept apart from the shopping lists).
final pantryListsProvider = StreamProvider<List<ShoppingList>>(
  (ref) => ref.watch(databaseProvider).watchPantryLists(),
);

/// The items on one pantry list.
final pantryProvider = StreamProvider.family<List<PantryItem>, String>(
  (ref, listId) => ref.watch(databaseProvider).watchPantry(listId: listId),
);

/// Legacy per-list category order rows (ignored; categories sort A–Z).
final listCategoryOrderProvider =
    StreamProvider.family<List<ListCategoryOrder>, String>(
      (ref, listId) =>
          ref.watch(databaseProvider).watchListCategoryOrder(listId),
    );

/// Previously added items, most recent first.
final historyProvider = StreamProvider<List<HistoryEntry>>(
  (ref) => ref.watch(databaseProvider).watchHistory(),
);

/// The shopping list on screen, so Settings can assign that list's tax rate.
final openShoppingListProvider =
    NotifierProvider<OpenShoppingList, ShoppingList?>(OpenShoppingList.new);

class OpenShoppingList extends Notifier<ShoppingList?> {
  @override
  ShoppingList? build() => null;

  void set(ShoppingList? list) {
    final current = state;
    if (current?.id == list?.id && current?.name == list?.name) return;
    state = list;
  }
}

final recipesProvider = StreamProvider<List<Recipe>>(
  (ref) => ref.watch(databaseProvider).watchRecipes(),
);

final recipeIngredientsProvider =
    StreamProvider.family<List<RecipeIngredient>, String>(
      (ref, recipeId) =>
          ref.watch(databaseProvider).watchRecipeIngredients(recipeId),
    );
