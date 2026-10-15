import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../ui/tip.dart';

/// What a move or copy did, so the caller can say so and offer Undo.
class MoveCopyOutcome {
  const MoveCopyOutcome(this.message, this.undo);

  final String message;
  final Future<void> Function() undo;
}

/// One row to tick in the dialog.
class MoveCopyEntry {
  const MoveCopyEntry(this.id, this.name, this.category);
  final String id;
  final String name;
  final String category;
}

/// Somewhere the items can go.
class MoveCopyDestination {
  const MoveCopyDestination(this.id, this.label);
  final String id;
  final String label;
}

/// Does the move or copy of the items with [ids] to [target].
typedef MoveCopyRun = Future<MoveCopyOutcome> Function(
  String target,
  List<String> ids, {
  required bool move,
});

String _items(int n) => '$n ${n == 1 ? 'item' : 'items'}';

/// "Move/Copy items": tick items, choose where they should go, then Move (they
/// leave this list) or Copy (they stay too). Pops a [MoveCopyOutcome] when
/// done, or null if cancelled.
class MoveCopyDialog extends StatefulWidget {
  const MoveCopyDialog({
    super.key,
    required this.listName,
    required this.entries,
    required this.destinations,
    required this.onRun,
  });

  final String listName;
  final List<MoveCopyEntry> entries;
  final List<MoveCopyDestination> destinations;
  final MoveCopyRun onRun;

  @override
  State<MoveCopyDialog> createState() => _MoveCopyDialogState();
}

class _MoveCopyDialogState extends State<MoveCopyDialog> {
  final _selected = <String>{};
  String? _target;
  bool _busy = false;

  Future<void> _run({required bool move}) async {
    final target = _target;
    if (target == null || _selected.isEmpty || _busy) return;
    setState(() => _busy = true);
    final ids = [
      for (final e in widget.entries)
        if (_selected.contains(e.id)) e.id,
    ];
    final outcome = await widget.onRun(target, ids, move: move);
    if (mounted) Navigator.pop(context, outcome);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = _selected.isNotEmpty && _target != null && !_busy;
    final all = widget.entries.length;

    return AlertDialog(
      title: const Text('Move or copy items'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tick the items from "${widget.listName}", choose where they '
                'should go, then Move (they leave this list) or Copy (they '
                'stay too).',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Tip(
                    'Tick every item',
                    child: TextButton(
                      onPressed: all == 0
                          ? null
                          : () => setState(
                              () => _selected.addAll(
                                widget.entries.map((e) => e.id),
                              ),
                            ),
                      child: const Text('Select all'),
                    ),
                  ),
                  Tip(
                    'Untick every item',
                    child: TextButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => setState(_selected.clear),
                      child: const Text('Select none'),
                    ),
                  ),
                  Text(
                    '${_selected.length} of $all selected',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (MediaQuery.sizeOf(context).height * 0.35).clamp(
                    120.0,
                    380.0,
                  ),
                ),
                child: all == 0
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('This list has no items yet.'),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final e in widget.entries)
                            Tip(
                              _selected.contains(e.id)
                                  ? 'Leave "${e.name}" out'
                                  : 'Include "${e.name}"',
                              child: CheckboxListTile(
                                key: ValueKey(e.id),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(
                                  e.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: e.category.isEmpty
                                    ? null
                                    : Text(e.category),
                                value: _selected.contains(e.id),
                                onChanged: (v) => setState(() {
                                  if (v ?? false) {
                                    _selected.add(e.id);
                                  } else {
                                    _selected.remove(e.id);
                                  }
                                }),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              Tip(
                'Choose where the items go',
                child: DropdownButtonFormField<String>(
                  initialValue: _target,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'To',
                    isDense: true,
                  ),
                  items: [
                    for (final d in widget.destinations)
                      DropdownMenuItem(
                        value: d.id,
                        child: Text(d.label, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _target = v),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Tip(
          'Close without moving or copying anything',
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
        Tip(
          'Copy the ticked items; they stay on this list too',
          child: OutlinedButton(
            onPressed: ready ? () => _run(move: false) : null,
            child: const Text('Copy'),
          ),
        ),
        Tip(
          'Move the ticked items off this list',
          child: FilledButton(
            onPressed: ready ? () => _run(move: true) : null,
            child: const Text('Move'),
          ),
        ),
      ],
    );
  }
}

// ---- Destinations are written 'shop:<id>' or 'pantry:<id>' ----------------

String _pantryLabel(List<ShoppingList> pantryLists, ShoppingList l) =>
    pantryLists.length == 1 ? 'Pantry' : 'Pantry: ${l.name}';

/// Move/Copy for a shopping list: other shopping lists and the pantry lists.
Future<MoveCopyOutcome?> showShoppingMoveCopy(
  BuildContext context, {
  required AppDatabase db,
  required ShoppingList list,
  required List<ShoppingItem> items,
  required List<ShoppingList> shoppingLists,
  required List<ShoppingList> pantryLists,
}) {
  String nameOf(String target) {
    final id = target.split(':').last;
    if (target.startsWith('pantry:')) {
      return pantryLists.length == 1
          ? 'the pantry'
          : '"${pantryLists.firstWhere((l) => l.id == id).name}"';
    }
    return '"${shoppingLists.firstWhere((l) => l.id == id).name}"';
  }

  return showDialog<MoveCopyOutcome>(
    context: context,
    builder: (_) => MoveCopyDialog(
      listName: list.name,
      entries: [for (final i in items) MoveCopyEntry(i.id, i.name, i.category)],
      destinations: [
        for (final l in shoppingLists)
          if (l.id != list.id) MoveCopyDestination('shop:${l.id}', l.name),
        for (final l in pantryLists)
          MoveCopyDestination('pantry:${l.id}', _pantryLabel(pantryLists, l)),
      ],
      onRun: (target, ids, {required move}) async {
        final chosen = [
          for (final i in items)
            if (ids.contains(i.id)) i,
        ];
        final n = _items(chosen.length);
        final to = nameOf(target);
        final id = target.split(':').last;
        if (target.startsWith('pantry:')) {
          final created = await db.copyShoppingToPantry(chosen, listId: id);
          if (!move) {
            return MoveCopyOutcome(
              'Copied $n to $to',
              () => db.deletePantryItems(created),
            );
          }
          await db.deleteShoppingItems(ids);
          return MoveCopyOutcome('Moved $n to $to', () async {
            await db.deletePantryItems(created);
            await db.restoreItems(ids);
          });
        }
        if (move) {
          final before = await db.moveShoppingItems(ids, id);
          return MoveCopyOutcome(
            'Moved $n to $to',
            () => db.restoreShoppingLists(before),
          );
        }
        final created = await db.copyShoppingItems(chosen, id);
        return MoveCopyOutcome(
          'Copied $n to $to',
          () => db.deleteShoppingItems(created),
        );
      },
    ),
  );
}

/// Move/Copy for a pantry list: other pantry lists, and the shopping lists
/// (to restock what is running low).
Future<MoveCopyOutcome?> showPantryMoveCopy(
  BuildContext context, {
  required AppDatabase db,
  required ShoppingList list,
  required List<PantryItem> items,
  required List<ShoppingList> shoppingLists,
  required List<ShoppingList> pantryLists,
}) {
  String nameOf(String target) {
    final id = target.split(':').last;
    return target.startsWith('pantry:')
        ? '"${pantryLists.firstWhere((l) => l.id == id).name}"'
        : '"${shoppingLists.firstWhere((l) => l.id == id).name}"';
  }

  return showDialog<MoveCopyOutcome>(
    context: context,
    builder: (_) => MoveCopyDialog(
      listName: list.name,
      entries: [for (final i in items) MoveCopyEntry(i.id, i.name, i.category)],
      destinations: [
        for (final l in shoppingLists)
          MoveCopyDestination('shop:${l.id}', l.name),
        for (final l in pantryLists)
          if (l.id != list.id) MoveCopyDestination('pantry:${l.id}', l.name),
      ],
      onRun: (target, ids, {required move}) async {
        final chosen = [
          for (final i in items)
            if (ids.contains(i.id)) i,
        ];
        final n = _items(chosen.length);
        final to = nameOf(target);
        final id = target.split(':').last;
        if (target.startsWith('shop:')) {
          final created = await db.copyPantryToShopping(chosen, id);
          if (!move) {
            return MoveCopyOutcome(
              'Copied $n to $to',
              () => db.deleteShoppingItems(created),
            );
          }
          await db.deletePantryItems(ids);
          return MoveCopyOutcome('Moved $n to $to', () async {
            await db.deleteShoppingItems(created);
            await db.restorePantryItems(ids);
          });
        }
        if (move) {
          final before = await db.movePantryItems(ids, id);
          return MoveCopyOutcome(
            'Moved $n to $to',
            () => db.restorePantryLists(before),
          );
        }
        final created = await db.copyPantryItems(chosen, id);
        return MoveCopyOutcome(
          'Copied $n to $to',
          () => db.deletePantryItems(created),
        );
      },
    ),
  );
}
