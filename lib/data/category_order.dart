import 'database.dart';

/// Where each category sorts on one list: the user's own order for that list
/// first (by position), then every other category in the default order.
Map<String, int> categoryOrderMap(
  List<Category> all,
  List<ListCategoryOrder> manual,
) => {
  for (final c in all) c.name: 1000 + c.sortOrder,
  for (final o in manual) o.category: o.position,
};

/// All category names, in the order they appear on one list.
List<String> orderedCategoryNames(
  List<Category> all,
  List<ListCategoryOrder> manual,
) {
  final order = categoryOrderMap(all, manual);
  return [for (final c in all) c.name]
    ..sort((a, b) => (order[a] ?? 1 << 20).compareTo(order[b] ?? 1 << 20));
}
