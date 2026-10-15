import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../catalog/catalog_suggestions.dart';

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

  void _add(String listId, String name, String category) {
    ref
        .read(databaseProvider)
        .addShoppingItem(listId, name, category: category);
    setState(_controller.clear);
  }

  /// Enter key: use the catalog entry with exactly this name if there is one,
  /// otherwise add the text as a new item under "Other".
  Future<void> _submit(String listId) async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final match = (await ref.read(databaseProvider).searchCatalog(name))
        .where((i) => i.name.toLowerCase() == name.toLowerCase());
    if (!mounted) return;
    _add(listId, match.isEmpty ? name : match.first.name,
        match.isEmpty ? 'Other' : match.first.category);
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
        final categoryOrder = {
          for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
            c.name: c.sortOrder,
        };
        return Scaffold(
          appBar: AppBar(
            title: const Text('Shopping'),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'List options',
                icon: const Icon(Icons.more_vert),
                onSelected: (v) async {
                  if (v == 'clear') {
                    await db.clearChecked(current.id);
                  } else if (v == 'new') {
                    await _newList();
                  } else if (v == 'delete') {
                    await db.deleteList(current.id);
                    setState(() => _listId = null);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'clear', child: Text('Clear checked items')),
                  const PopupMenuItem(value: 'new', child: Text('New list')),
                  if (all.length > 1)
                    const PopupMenuItem(
                        value: 'delete', child: Text('Delete this list')),
                ],
              ),
            ],
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: DropdownButton<String>(
                isExpanded: true,
                value: current.id,
                items: [
                  for (final l in all)
                    DropdownMenuItem(
                        value: l.id,
                        child: Text(l.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _listId = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _controller,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search or add an item',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _submit(current.id)),
                ),
                onSubmitted: (_) => _submit(current.id),
              ),
            ),
            CatalogSuggestions(
              query: _controller.text,
              onPick: (i) => _add(current.id, i.name, i.category),
            ),
            Expanded(
              child: items.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (rows) => rows.isEmpty
                    ? const Center(child: Text('Nothing to buy'))
                    : ListView(children: [
                        ..._grouped(rows, categoryOrder, db),
                      ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

/// Unchecked items under category headers in store-walking order, followed by
/// a "Checked" section.
List<Widget> _grouped(
    List<ShoppingItem> rows, Map<String, int> order, AppDatabase db) {
  final open = rows.where((i) => !i.checked);
  final done = rows.where((i) => i.checked);
  final byCategory = <String, List<ShoppingItem>>{};
  for (final i in open) {
    byCategory.putIfAbsent(i.category.isEmpty ? 'Other' : i.category, () => []).add(i);
  }
  final names = byCategory.keys.toList()
    ..sort((a, b) => (order[a] ?? 1 << 20).compareTo(order[b] ?? 1 << 20));
  return [
    for (final n in names) ...[
      _Header(n),
      for (final i in byCategory[n]!) _ItemTile(item: i, db: db),
    ],
    if (done.isNotEmpty) ...[
      const _Header('Checked'),
      for (final i in done) _ItemTile(item: i, db: db),
    ],
  ];
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
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
