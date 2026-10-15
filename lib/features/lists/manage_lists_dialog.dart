import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/dialogs.dart';
import '../../ui/keyline/keyline_icon.dart';
import '../../ui/tip.dart';

/// Rename, reorder, add and delete shopping lists ("Manage lists").
class ManageListsDialog extends ConsumerWidget {
  const ManageListsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final lists = ref.watch(listsProvider).value ?? const <ShoppingList>[];
    final theme = Theme.of(context);

    Future<void> rename(ShoppingList l) async {
      final name = await askNameDialog(
        context,
        title: 'Rename list',
        initial: l.name,
        confirmLabel: 'Rename',
        confirmTip: 'Save the new name',
      );
      if (name != null && name != l.name) await db.renameList(l.id, name);
    }

    Future<void> remove(ShoppingList l) async {
      final ok = await confirmDialog(
        context,
        title: 'Delete "${l.name}"?',
        message: 'The list and all its items will be removed.',
        confirmTip: 'Delete this list and its items',
      );
      if (ok) await db.deleteList(l.id);
    }

    return AlertDialog(
      title: const Text('Manage lists'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lists.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Drag a list by its handle to change the order.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (MediaQuery.sizeOf(context).height * 0.45).clamp(
                    120.0,
                    420.0,
                  ),
                ),
                child: lists.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No lists yet.'),
                      )
                    : ReorderableListView(
                        shrinkWrap: true,
                        buildDefaultDragHandles: false,
                        onReorderItem: (oldIndex, newIndex) {
                          final ids = [for (final l in lists) l.id];
                          ids.insert(newIndex, ids.removeAt(oldIndex));
                          db.reorderLists(ids);
                        },
                        children: [
                          for (var i = 0; i < lists.length; i++)
                            ListTile(
                              key: ValueKey(lists[i].id),
                              contentPadding: EdgeInsets.zero,
                              leading: Tip(
                                'Drag to reorder',
                                child: ReorderableDragStartListener(
                                  index: i,
                                  child: const KeylineIcon(
                                    KeylineIcons.gripVertical,
                                  ),
                                ),
                              ),
                              title: Text(
                                lists[i].name,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Rename list',
                                    icon: const KeylineIcon(KeylineIcons.pen),
                                    onPressed: () => rename(lists[i]),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete list',
                                    icon: const KeylineIcon(KeylineIcons.bin),
                                    onPressed: () => remove(lists[i]),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Tip(
              'Start another shopping list',
              child: TextButton.icon(
                onPressed: () async {
                  final name = await askNameDialog(context, title: 'New list');
                  if (name != null) await db.addList(name);
                },
                icon: const KeylineIcon(KeylineIcons.listPlus),
                label: const Text('New list'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Tip(
          'Close manage lists',
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}
