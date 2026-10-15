import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';

class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  String? _listId;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _newList() async {
    final name = await _askName(context, 'New list');
    if (name == null) return;
    await ref.read(databaseProvider).addList(name);
  }

  void _add(String listId) {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    ref.read(databaseProvider).addShoppingItem(listId, name);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(listsProvider);
    return lists.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (all) {
        if (all.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Shopping')),
            body: const Center(child: Text('No lists yet')),
            floatingActionButton: FloatingActionButton(
                onPressed: _newList, child: const Icon(Icons.add)),
          );
        }
        final current =
            all.firstWhere((l) => l.id == _listId, orElse: () => all.first);
        final db = ref.read(databaseProvider);
        final items = ref.watch(shoppingItemsProvider(current.id));
        return Scaffold(
          appBar: AppBar(
            title: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: current.id,
                items: [
                  for (final l in all)
                    DropdownMenuItem(value: l.id, child: Text(l.name)),
                ],
                onChanged: (v) => setState(() => _listId = v),
              ),
            ),
            actions: [
              IconButton(
                  tooltip: 'Clear checked',
                  icon: const Icon(Icons.done_all),
                  onPressed: () => db.clearChecked(current.id)),
              IconButton(
                  tooltip: 'New list',
                  icon: const Icon(Icons.playlist_add),
                  onPressed: _newList),
              if (all.length > 1)
                IconButton(
                    tooltip: 'Delete list',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await db.deleteList(current.id);
                      setState(() => _listId = null);
                    }),
            ],
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Add an item',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _add(current.id)),
                ),
                onSubmitted: (_) => _add(current.id),
              ),
            ),
            Expanded(
              child: items.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (rows) => rows.isEmpty
                    ? const Center(child: Text('Nothing to buy'))
                    : ListView(children: [
                        for (final i in rows) _ItemTile(item: i, db: db),
                      ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.db});
  final ShoppingItem item;
  final AppDatabase db;

  @override
  Widget build(BuildContext context) => Dismissible(
        key: ValueKey(item.id),
        background: Container(color: Colors.red.shade300),
        onDismissed: (_) => db.deleteShoppingItem(item.id),
        child: CheckboxListTile(
          value: item.checked,
          onChanged: (v) => db.setChecked(item.id, v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(item.name,
              style: item.checked
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null),
          secondary: IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.close),
              onPressed: () => db.deleteShoppingItem(item.id)),
        ),
      );
}

Future<String?> _askName(BuildContext context, String title) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim())),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Create')),
      ],
    ),
  ).then((v) => (v == null || v.isEmpty) ? null : v);
}
