import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/data/database.dart';

final _t = DateTime(2026, 1, 1);

RecipeIngredient _line(
  String name, {
  double qty = 1,
  String unit = '',
  String category = 'Produce',
}) => RecipeIngredient(
  id: name,
  updatedAt: _t,
  recipeId: 'r1',
  name: name,
  quantity: qty,
  unit: unit,
  category: category,
  sortOrder: 0,
);

PantryItem _stock(
  String name, {
  double qty = 1,
  String unit = '',
  String mode = 'number',
  String level = 'full',
}) => PantryItem(
  id: name,
  updatedAt: _t,
  name: name,
  quantity: qty,
  unit: unit,
  location: '',
  category: '',
  note: '',
  listId: 'p1',
  quantityMode: mode,
  level: level,
);

void main() {
  test('a parent query scales servings and skips pantry stock', () {
    final plan = planRecipeAgainstPantry(
      ingredients: [
        _line('Milk', qty: 1, unit: 'cup'),
        _line('Onions', qty: 2),
        _line('Butter', qty: 1),
      ],
      baseServings: 2,
      cookServings: 4,
      pantry: [
        _stock('Milk', qty: 1, unit: 'cup'),
        _stock('Onions', mode: 'level', level: 'full'),
      ],
    );
    expect(plan.skipped.map((line) => line.name), containsAll(['Onions']));
    final milk = plan.add.singleWhere((line) => line.name == 'Milk');
    expect(milk.quantity, 1);
    expect(plan.add.map((line) => line.name), contains('Butter'));
    expect(plan.add.singleWhere((line) => line.name == 'Butter').quantity, 2);
  });

  test('a full pantry level covers the ingredient', () {
    final plan = planRecipeAgainstPantry(
      ingredients: [_line('Salt')],
      baseServings: 4,
      cookServings: 4,
      pantry: [_stock('Salt', mode: 'level', level: 'full')],
    );
    expect(plan.add, isEmpty);
    expect(plan.skipped.single.name, 'Salt');
  });
}
