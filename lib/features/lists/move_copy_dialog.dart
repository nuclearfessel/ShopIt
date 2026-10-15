import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/tip.dart';

/// What a move or copy did, so the caller can say so and offer Undo.
class MoveCopyOutcome {
  const MoveCopyOutcome(this.message, this.undo);

  final String message;
  final Future<void> Function() undo;
}

/// The pantry as a destination (the lists are identified by their ids).
const String kPantryTarget = 'pantry';

String _items(int n) => '$n ${n == 1 ? 'item' : 'items'}';

/// "Move/Copy items": tick items on a shopping list, choose another shopping
/// list or the pantry, then Move (they leave this list) or Copy (they stay).
/// Pops a [MoveCopyOutcome] when done, or null if cancelled.
class MoveCopyDialog extends ConsumerStatefulWidget {
  const MoveCopyDialog({super.key, required this.list, required this.items});

  final ShoppingList list;
  final List<ShoppingItem> items;

  @override
  ConsumerState<MoveCopyDialog> createState() => _MoveCopyDialogState();
}

class _MoveCopyDialogState extends ConsumerState<MoveCopyDialog> {
  final _selected = <String>{};
  String? _target;
  bool _busy = false;

  Future<void> _run({required bool move}) async {
    final target = _target;
    if (target == null || _selected.isEmpty || _busy) return;
    setState(() => _busy = true);
    final db = ref.read(databaseProvider);
    final chosen = [
      for (final i in widget.items)
        if (_selected.contains(i.id)) i,
    ];
    final ids = [for (final i in chosen) i.id];
    final n = _items(chosen.length);
    final lists = ref.read(listsProvider).value ?? const <ShoppingList>[];
    final targetName = target == kPantryTarget
        ? 'the pantry'
        : '"${lists.firstWhere((l) => l.id == target).name}"';

    final MoveCopyOutcome outcome;
    if (target == kPantryTarget) {
      final created = await db.copyShoppingToPantry(chosen);
      if (move) {
        await db.deleteShoppingItems(ids);
        outcome = MoveCopyOutcome('Moved $n to $targetName', () async {
          await db.deletePantryItems(created);
          await db.restoreItems(ids);
        });
      } else {
        outcome = MoveCopyOutcome(
          'Copied $n to $targetName',
          () => db.deletePantryItems(created),
        );
      }
    } else if (move) {
      final before = await db.moveShoppingItems(ids, target);
      outcome = MoveCopyOutcome(
        'Moved $n to $targetName',
        () => db.restoreShoppingLists(before),
      );
    } else {
      final created = await db.copyShoppingItems(chosen, target);
      outcome = MoveCopyOutcome(
        'Copied $n to $targetName',
        () => db.deleteShoppingItems(created),
      );
    }
    if (mounted) Navigator.pop(context, outcome);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lists = ref.watch(listsProvider).value ?? const <ShoppingList>[];
    final destinations = <(String, String)>[
      for (final l in lists)
        if (l.id != widget.list.id) (l.id, l.name),
      (kPantryTarget, 'Pantry'),
    ];
    final ready = _selected.isNotEmpty && _target != null && !_busy;
    final all = widget.items.length;

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
                'Tick the items from "${widget.list.name}", choose where they '
                'should go, then Move (they leave this list) or Copy (they stay '
                'too).',
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
                                widget.items.map((i) => i.id),
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
                          for (final i in widget.items)
                            Tip(
                              _selected.contains(i.id)
                                  ? 'Leave "${i.name}" out'
                                  : 'Include "${i.name}"',
                              child: CheckboxListTile(
                                key: ValueKey(i.id),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(
                                  i.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: i.category.isEmpty
                                    ? null
                                    : Text(i.category),
                                value: _selected.contains(i.id),
                                onChanged: (v) => setState(() {
                                  if (v ?? false) {
                                    _selected.add(i.id);
                                  } else {
                                    _selected.remove(i.id);
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
                    for (final (id, name) in destinations)
                      DropdownMenuItem(
                        value: id,
                        child: Text(name, overflow: TextOverflow.ellipsis),
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
