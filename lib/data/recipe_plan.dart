import 'database.dart';

/// One ingredient after scaling a recipe, either to add or to skip.
class RecipeShopLine {
  const RecipeShopLine({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    this.reason = '',
  });

  final String name;
  final double quantity;
  final String unit;
  final String category;
  final String reason;
}

/// Ingredients to buy, and those the pantry already covers.
class RecipeShopPlan {
  const RecipeShopPlan({this.add = const [], this.skipped = const []});

  final List<RecipeShopLine> add;
  final List<RecipeShopLine> skipped;
}

bool unitsMatch(String a, String b) {
  final left = a.trim().toLowerCase();
  final right = b.trim().toLowerCase();
  return left.isEmpty || right.isEmpty || left == right;
}

/// Scales [ingredients] to [cookServings] and subtracts matching pantry stock.
RecipeShopPlan planRecipeAgainstPantry({
  required List<RecipeIngredient> ingredients,
  required double baseServings,
  required double cookServings,
  required List<PantryItem> pantry,
}) {
  final scale = cookServings <= 0 || baseServings <= 0
      ? 1.0
      : cookServings / baseServings;
  final add = <RecipeShopLine>[];
  final skipped = <RecipeShopLine>[];
  for (final line in ingredients) {
    final needed = line.quantity * scale;
    final have = _pantryHave(pantry, line.name, line.unit);
    if (have >= needed && have > 0) {
      skipped.add(
        RecipeShopLine(
          name: line.name,
          quantity: needed,
          unit: line.unit,
          category: line.category,
          reason: 'Already in the pantry',
        ),
      );
      continue;
    }
    final buy = have > 0 ? needed - have : needed;
    add.add(
      RecipeShopLine(
        name: line.name,
        quantity: buy,
        unit: line.unit,
        category: line.category,
      ),
    );
  }
  return RecipeShopPlan(add: add, skipped: skipped);
}

double _pantryHave(List<PantryItem> pantry, String name, String unit) {
  final key = name.toLowerCase();
  var have = 0.0;
  for (final row in pantry) {
    if (row.name.toLowerCase() != key) continue;
    if (row.quantityMode == 'level') {
      if (row.level == 'full') return 1e9;
      continue;
    }
    if (!unitsMatch(row.unit, unit)) {
      return 1e9;
    }
    have += row.quantity;
  }
  return have;
}
