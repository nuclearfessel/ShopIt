import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/data/database.dart';
import 'package:shop_it/data/device_sync.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('adding a recipe to a list skips pantry stock', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final list = (await db.watchLists().first).first;
    final pantry = (await db.watchPantryLists().first).first;
    await db.addPantryItem('Onions', quantity: 4, listId: pantry.id);
    final recipeId = await db.addRecipe('Soup', servings: 2);
    await db.addRecipeIngredient(recipeId, 'Onions', quantity: 1);
    await db.addRecipeIngredient(recipeId, 'Carrots', quantity: 2);
    final plan = await db.planRecipeShop(recipeId, cookServings: 4);
    expect(plan.skipped.map((line) => line.name), contains('Onions'));
    expect(plan.add.single.name, 'Carrots');
    expect(plan.add.single.quantity, 4);
    await db.applyRecipeShopPlan(list.id, plan, recipeName: 'Soup');
    final items = await db.watchShoppingItems(list.id).first;
    expect(items.map((item) => item.name), contains('Carrots'));
    expect(items.map((item) => item.name), isNot(contains('Onions')));
    expect(items.singleWhere((item) => item.name == 'Carrots').note, 'For Soup');
  });

  test('cooking a recipe reduces pantry amounts', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final pantry = (await db.watchPantryLists().first).first;
    await db.setPantryQuantityMode(pantry.id, 'number');
    await db.addPantryItem('Milk', quantity: 4, unit: 'cup', listId: pantry.id);
    final recipeId = await db.addRecipe('Pudding', servings: 4);
    await db.addRecipeIngredient(
      recipeId,
      'Milk',
      quantity: 2,
      unit: 'cup',
    );
    await db.cookRecipe(recipeId, cookServings: 4);
    final stock = await db.watchPantry(listId: pantry.id).first;
    expect(stock.singleWhere((item) => item.name == 'Milk').quantity, 2);
  });

  test('a barcode is remembered and found again', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await db.linkBarcode('012345678905', 'Cheerios', category: 'Breakfast & Cereal');
    final hit = await db.catalogByBarcode('012345678905');
    expect(hit?.name, 'Cheerios');
  });

  test('recipes sync to the other device', () async {
    final host = AppDatabase.memory();
    final client = AppDatabase.memory();
    addTearDown(host.close);
    addTearDown(client.close);
    final id = await client.addRecipe('Chili', servings: 6);
    await client.addRecipeIngredient(id, 'Beans', quantity: 2);
    await host.applySnapshot(await client.exportSnapshot());
    final recipes = await host.watchRecipes().first;
    expect(recipes.map((row) => row.name), contains('Chili'));
    final ingredients = await host.recipeIngredientsFor(
      recipes.firstWhere((row) => row.name == 'Chili').id,
    );
    expect(ingredients.single.name, 'Beans');
  });
}
