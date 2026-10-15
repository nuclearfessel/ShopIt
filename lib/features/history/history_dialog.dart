import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/keyline/keyline_icon.dart';
import '../../ui/tip.dart';

/// Everything the user has added before. Tap one to add it to [list] again;
/// the trash can removes it from the history (not from any list).
class HistoryDialog extends ConsumerStatefulWidget {
  const HistoryDialog({super.key, required this.list});

  final ShoppingList list;

  @override
  ConsumerState<HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends ConsumerState<HistoryDialog> {
  final _filter = TextEditingController();

  /// Entries added during this visit, so the row can say so.
  final _added = <String>{};

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  Future<void> _add(HistoryEntry e) async {
    final list = widget.list;
    await ref
        .read(databaseProvider)
        .addShoppingItem(
          list.id,
          e.name,
          category: list.autoCategorize ? e.category : '',
          unit: e.unit,
        );
    if (mounted) setState(() => _added.add(e.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = ref.read(databaseProvider);
    final query = _filter.text.trim().toLowerCase();
    final all = ref.watch(historyProvider).value ?? const <HistoryEntry>[];
    final entries = [
      for (final e in all)
        if (query.isEmpty || e.name.toLowerCase().contains(query)) e,
    ];

    return AlertDialog(
      title: const Text('History'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tap an item to add it to "${widget.list.name}" again.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _filter,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search your history',
                  isDense: true,
                  prefixIcon: const KeylineIcon(KeylineIcons.search),
                  suffixIcon: _filter.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const KeylineIcon(KeylineIcons.x),
                          onPressed: () => setState(_filter.clear),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (MediaQuery.sizeOf(context).height * 0.45).clamp(
                    140.0,
                    460.0,
                  ),
                ),
                child: entries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          all.isEmpty
                              ? 'Nothing here yet. Items you add to a list '
                                    'show up here.'
                              : 'No items match "${_filter.text.trim()}".',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final e in entries)
                            ListTile(
                              key: ValueKey(e.id),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: KeylineIcon(
                                _added.contains(e.id)
                                    ? KeylineIcons.check
                                    : KeylineIcons.plus,
                              ),
                              title: Tip(
                                'Add "${e.name}" to "${widget.list.name}"',
                                child: Text(
                                  e.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              subtitle: e.category.isEmpty
                                  ? null
                                  : Text(e.category),
                              onTap: () => _add(e),
                              trailing: IconButton(
                                tooltip: 'Remove from history',
                                icon: const KeylineIcon(KeylineIcons.bin),
                                onPressed: () => db.removeHistory(e.id),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Tip(
          'Close history',
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}
