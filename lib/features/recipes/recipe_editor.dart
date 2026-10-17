import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog_seed.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/choice_field.dart';
import '../../ui/keyline/keyline_icon.dart';
import '../../ui/tip.dart';
import '../catalog/catalog_suggestions.dart';

Future<void> showRecipeEditor(BuildContext context, {required Recipe recipe}) {
  return showDialog<void>(
    context: context,
    builder: (_) => RecipeEditorDialog(recipeId: recipe.id, initial: recipe),
  );
}

class RecipeEditorDialog extends ConsumerStatefulWidget {
  const RecipeEditorDialog({
    super.key,
    required this.recipeId,
    required this.initial,
  });

  final String recipeId;
  final Recipe initial;

  @override
  ConsumerState<RecipeEditorDialog> createState() => _RecipeEditorDialogState();
}

class _RecipeEditorDialogState extends ConsumerState<RecipeEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _servings;
  late final TextEditingController _ingredientName;
  late final TextEditingController _ingredientQty;
  late final TextEditingController _ingredientUnit;
  String _ingredientCategory = '';

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name);
    _servings = TextEditingController(
      text: _qtyText(widget.initial.servings),
    );
    _ingredientName = TextEditingController();
    _ingredientQty = TextEditingController(text: '1');
    _ingredientUnit = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _servings.dispose();
    _ingredientName.dispose();
    _ingredientQty.dispose();
    _ingredientUnit.dispose();
    super.dispose();
  }

  double get _servingsValue =>
      double.tryParse(_servings.text.trim()) ?? widget.initial.servings;

  Future<void> _saveHeader() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await ref
        .read(databaseProvider)
        .updateRecipe(widget.recipeId, name: name, servings: _servingsValue);
  }

  Future<void> _addIngredient() async {
    final name = _ingredientName.text.trim();
    if (name.isEmpty) return;
    await _saveHeader();
    await ref
        .read(databaseProvider)
        .addRecipeIngredient(
          widget.recipeId,
          name,
          quantity: double.tryParse(_ingredientQty.text.trim()) ?? 1,
          unit: _ingredientUnit.text.trim(),
          category: _ingredientCategory,
        );
    if (!mounted) return;
    setState(() {
      _ingredientName.clear();
      _ingredientQty.text = '1';
      _ingredientUnit.clear();
      _ingredientCategory = '';
    });
  }

  Future<void> _addToList() async {
    await _saveHeader();
    if (!mounted) return;
    final lists = ref.read(listsProvider).value ?? const <ShoppingList>[];
    if (lists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Make a shopping list first.')),
      );
      return;
    }
    String listId = lists.first.id;
    final cook = TextEditingController(text: _servings.text);
    final chosen = await showDialog<(String, double)?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add to shopping list'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tip(
                'Choose a shopping list',
                child: ChoiceField<String>(
                  value: listId,
                  decoration: const InputDecoration(labelText: 'List'),
                  choices: [for (final list in lists) Choice(list.id, list.name)],
                  onChanged: (v) => setLocal(() => listId = v),
                ),
              ),
              TextField(
                controller: cook,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Servings to shop for',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, (
                listId,
                double.tryParse(cook.text.trim()) ?? _servingsValue,
              )),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    cook.dispose();
    if (chosen == null || !mounted) return;
    final db = ref.read(databaseProvider);
    final plan = await db.planRecipeShop(
      widget.recipeId,
      cookServings: chosen.$2,
    );
    await db.applyRecipeShopPlan(
      chosen.$1,
      plan,
      recipeName: _name.text.trim(),
    );
    if (!mounted) return;
    final skipped = plan.skipped.map((line) => line.name).join(', ');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Added to the list'),
        content: Text(
          plan.add.isEmpty
              ? 'The pantry already covers this recipe.'
              : [
                  'Added ${plan.add.length} '
                      '${plan.add.length == 1 ? 'item' : 'items'}.',
                  if (plan.skipped.isNotEmpty) 'Skipped: $skipped.',
                ].join(' '),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _cook() async {
    await _saveHeader();
    if (!mounted) return;
    final cook = TextEditingController(text: _servings.text);
    final servings = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cook this recipe'),
        content: TextField(
          controller: cook,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Servings cooked',
            helperText: 'Amounts come off the pantry.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              double.tryParse(cook.text.trim()) ?? _servingsValue,
            ),
            child: const Text('Cook'),
          ),
        ],
      ),
    );
    cook.dispose();
    if (servings == null || !mounted) return;
    await ref
        .read(databaseProvider)
        .cookRecipe(widget.recipeId, cookServings: servings);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pantry amounts were updated.')),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_name.text.trim()}?'),
        content: const Text('The recipe is removed. Lists are not changed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(databaseProvider).deleteRecipe(widget.recipeId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ingredients =
        ref.watch(recipeIngredientsProvider(widget.recipeId)).value ??
        const <RecipeIngredient>[];
    final categories = [
      ...catalogSeed.keys,
      if (ref.watch(categoriesProvider).value != null)
        for (final row in ref.watch(categoriesProvider).value!)
          if (!catalogSeed.containsKey(row.name)) row.name,
    ];
    return AlertDialog(
      title: const Text('Recipe'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                onSubmitted: (_) => _saveHeader(),
              ),
              TextField(
                controller: _servings,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Servings'),
                onSubmitted: (_) => _saveHeader(),
              ),
              const SizedBox(height: 16),
              Text('Ingredients', style: Theme.of(context).textTheme.titleSmall),
              if (ingredients.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Add the names you would search for in ShopIt.'),
                ),
              for (final line in ingredients)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(line.name),
                  subtitle: Text(
                    [
                      _qtyText(line.quantity),
                      if (line.unit.isNotEmpty) line.unit,
                      if (line.category.isNotEmpty) line.category,
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove ${line.name}',
                    icon: const KeylineIcon(KeylineIcons.bin),
                    onPressed: () => ref
                        .read(databaseProvider)
                        .deleteRecipeIngredient(line.id),
                  ),
                ),
              TextField(
                controller: _ingredientName,
                decoration: const InputDecoration(
                  labelText: 'Add an ingredient',
                  prefixIcon: KeylineIcon(KeylineIcons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              CatalogSuggestions(
                query: _ingredientName.text,
                onPick: (item) => setState(() {
                  _ingredientName.text = item.name;
                  _ingredientCategory = item.category;
                  if (_ingredientUnit.text.isEmpty) {
                    _ingredientUnit.text = item.defaultUnit;
                  }
                }),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ingredientQty,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _ingredientUnit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                ],
              ),
              Tip(
                'Choose a category',
                child: ChoiceField<String>(
                  value: _ingredientCategory.isEmpty ? null : _ingredientCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  choices: [for (final name in categories) Choice(name, name)],
                  onChanged: (v) => setState(() => _ingredientCategory = v),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Tip(
                  'Add this ingredient to the recipe',
                  child: TextButton(
                    onPressed: _addIngredient,
                    child: const Text('Add ingredient'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Tip(
          'Remove this recipe',
          child: TextButton(onPressed: _delete, child: const Text('Delete')),
        ),
        Tip(
          'Take these amounts off the pantry',
          child: TextButton(onPressed: _cook, child: const Text('Cook')),
        ),
        Tip(
          'Put missing ingredients on a shopping list',
          child: FilledButton(
            onPressed: _addToList,
            child: const Text('Add to list'),
          ),
        ),
      ],
    );
  }
}

String _qtyText(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();
