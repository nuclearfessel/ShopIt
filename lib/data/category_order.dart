import 'database.dart';

/// Alphabetical rank for each category name (case-insensitive).
Map<String, int> categoryOrderMap(List<Category> all) {
  final names = orderedCategoryNames(all);
  return {for (var i = 0; i < names.length; i++) names[i]: i};
}

/// All category names in alphabetical order (case-insensitive).
List<String> orderedCategoryNames(List<Category> all) {
  final names = [for (final c in all) c.name];
  names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return names;
}
