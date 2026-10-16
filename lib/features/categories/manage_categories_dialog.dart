import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/category_order.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/category_color.dart';
import '../../ui/dialogs.dart';
import '../../ui/keyline/keyline_icon.dart';
import '../../ui/tip.dart';
import 'category_color_dialog.dart';

/// "Manage categories": every category, listed alphabetically. Tap the colour
/// dot to recolour (every list), add new ones, or delete (removes it
/// everywhere). New categories slot into alphabetical order automatically.
class ManageCategoriesDialog extends ConsumerStatefulWidget {
  const ManageCategoriesDialog({
    super.key,
    required this.listId,
    required this.listName,
  });

  final String listId;
  final String listName;

  @override
  ConsumerState<ManageCategoriesDialog> createState() =>
      _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState
    extends ConsumerState<ManageCategoriesDialog> {
  final _newName = TextEditingController();

  @override
  void dispose() {
    _newName.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _newName.text.trim();
    if (name.isEmpty) return;
    await ref.read(databaseProvider).addCategory(name);
    _newName.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.read(databaseProvider);
    final theme = Theme.of(context);
    final all = ref.watch(categoriesProvider).value ?? const <Category>[];
    final names = orderedCategoryNames(all);
    final byName = {for (final c in all) c.name: c};

    Future<void> recolor(Category c) async {
      final choice = await showCategoryColorDialog(
        context,
        category: c.name,
        current: c.color,
      );
      if (choice != null) await db.setCategoryColor(c.name, choice.argb);
    }

    Future<void> remove(Category c) async {
      final ok = await confirmDialog(
        context,
        title: 'Delete "${c.name}"?',
        message:
            'The category is removed from every list. Items in it stay on '
            'their lists without a category.',
        confirmTip: 'Delete this category everywhere',
      );
      if (ok) await db.deleteCategory(c.name);
    }

    return AlertDialog(
      title: const Text('Manage categories'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Categories stay in alphabetical order on every list. Tap a '
                'color dot to change its color everywhere.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newName,
                      decoration: const InputDecoration(
                        labelText: 'New category',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add category',
                    icon: const KeylineIcon(KeylineIcons.plus),
                    onPressed: _add,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (MediaQuery.sizeOf(context).height * 0.45).clamp(
                    140.0,
                    460.0,
                  ),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final name in names)
                      _row(context, byName[name], name, recolor, remove),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Tip(
          'Close manage categories',
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    Category? category,
    String name,
    Future<void> Function(Category) recolor,
    Future<void> Function(Category) remove,
  ) {
    final c = category;
    final dot = c?.color == null
        ? automaticCategoryColor(name, Theme.of(context).brightness)
        : Color(c!.color!);
    return ListTile(
      key: ValueKey(name),
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Tip(
            'Change the color of "$name"',
            child: InkResponse(
              onTap: c == null ? null : () => recolor(c),
              radius: 18,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
        ],
      ),
      trailing: name == 'Other' || c == null
          ? null
          : IconButton(
              tooltip: 'Delete category',
              icon: const KeylineIcon(KeylineIcons.bin),
              onPressed: () => remove(c),
            ),
    );
  }
}
