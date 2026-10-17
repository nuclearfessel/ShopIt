import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../ui/tip.dart';

/// Per-list settings: whether items are grouped under categories, filed into
/// a category automatically when added, and whether category headers with no
/// items are shown.
class ListSettingsDialog extends ConsumerWidget {
  const ListSettingsDialog({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final list = ref
        .watch(listsProvider)
        .value
        ?.where((l) => l.id == listId)
        .firstOrNull;
    final db = ref.read(databaseProvider);
    if (list == null) return const SizedBox.shrink();

    return AlertDialog(
      title: Text('Settings for "${list.name}"'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CATEGORIES',
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 0.6,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Tip(
                'Group the items under category headers',
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable categories'),
                  subtitle: const Text(
                    'Turn off to show this list as one plain list.',
                  ),
                  value: list.useCategories,
                  onChanged: (v) =>
                      db.updateListSettings(listId, useCategories: v),
                ),
              ),
              Tip(
                'File each new item into a category as you add it',
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-categorize items'),
                  subtitle: const Text(
                    'Turn off to add items without a category.',
                  ),
                  value: list.autoCategorize,
                  onChanged: list.useCategories
                      ? (v) => db.updateListSettings(listId, autoCategorize: v)
                      : null,
                ),
              ),
              Tip(
                'Keep category headers visible even when they have no items',
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show empty categories'),
                  subtitle: const Text(
                    'Show every category header, even with nothing in it.',
                  ),
                  value: list.showEmptyCategories,
                  onChanged: list.useCategories
                      ? (v) => db.updateListSettings(
                          listId,
                          showEmptyCategories: v,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'SALES TAX',
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 0.6,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Tip(
                'Let each item follow the tax rules again',
                child: TextButton(
                  onPressed: () => db.resetTaxToAutomatic(listId),
                  child: const Text('Use automatic tax rules'),
                ),
              ),
              Tip(
                'Tax every item on this list',
                child: TextButton(
                  onPressed: () => db.setAllTaxable(listId, true),
                  child: const Text('Mark all items taxable'),
                ),
              ),
              Tip(
                'Tax no item on this list',
                child: TextButton(
                  onPressed: () => db.setAllTaxable(listId, false),
                  child: const Text('Mark all items not taxable'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Tip(
          'Close list settings',
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}
