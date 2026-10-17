import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/dialogs.dart';
import '../../ui/keyline/keyline_icon.dart';
import '../../ui/tip.dart';
import '../settings/settings_dialog.dart';
import 'recipe_editor.dart';

/// Saved recipes. Add one to a shopping list after subtracting pantry stock,
/// or cook it to reduce pantry amounts.
class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recipesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const KeylineIcon(KeylineIcons.settings),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SettingsDialog(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New recipe',
        onPressed: () => _newRecipe(context, ref),
        child: const KeylineIcon(KeylineIcons.bookPlus),
      ),
      body: recipes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(
              child: Text('No recipes yet. Add one to plan a shop.'),
            );
          }
          return ListView(
            children: [
              for (final recipe in rows)
                ListTile(
                  leading: const KeylineIcon(KeylineIcons.bookOpen),
                  title: Tip(
                    'Open ${recipe.name}',
                    child: Text(recipe.name),
                  ),
                  subtitle: Text(
                    '${_servingsLabel(recipe.servings)} servings',
                  ),
                  onTap: () => showRecipeEditor(context, recipe: recipe),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _newRecipe(BuildContext context, WidgetRef ref) async {
    final name = await askNameDialog(context, title: 'New recipe');
    if (name == null) return;
    final id = await ref.read(databaseProvider).addRecipe(name);
    if (!context.mounted) return;
    final recipe = (ref.read(recipesProvider).value ?? const <Recipe>[]).where(
      (row) => row.id == id,
    );
    await showRecipeEditor(
      context,
      recipe: recipe.isEmpty
          ? Recipe(
              id: id,
              updatedAt: DateTime.now(),
              name: name,
              servings: 4,
              note: '',
            )
          : recipe.first,
    );
  }
}

String _servingsLabel(double servings) => servings == servings.roundToDouble()
    ? servings.toInt().toString()
    : servings.toString();
