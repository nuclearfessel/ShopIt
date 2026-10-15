import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../catalog/catalog_suggestions.dart';
import '../../data/totals.dart';
import '../catalog/item_editor.dart';
import 'tax_rates_dialog.dart';

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
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('No lists yet'),
                const SizedBox(height: 12),
                FilledButton.icon(
                    onPressed: _newList,
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Create a list')),
              ]),
            ),
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
                    if (await _confirm(context, 'Delete "${current.name}"?',
                        'The list and all its items will be removed.')) {
                      await db.deleteList(current.id);
                      setState(() => _listId = null);
                    }
                  } else if (v == 'tax') {
                    await showDialog<void>(
                        context: context,
                        builder: (_) => TaxRatesDialog(listId: current.id));
                  } else if (v == 'deleteAll') {
                    if (await _confirm(
                        context,
                        'Delete all lists?',
                        'Every shopping list and all their items will be '
                            'removed so you can start from scratch. Your '
                            'pantry is not affected.')) {
                      await db.deleteAllLists();
                      setState(() => _listId = null);
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'clear', child: Text('Clear checked items')),
                  const PopupMenuItem(value: 'new', child: Text('New list')),
                  const PopupMenuItem(
                      value: 'tax', child: Text('Sales tax rate...')),
                  const PopupMenuItem(
                      value: 'delete', child: Text('Delete this list')),
                  const PopupMenuItem(
                      value: 'deleteAll', child: Text('Delete all lists')),
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
                        ..._grouped(rows, categoryOrder, db, all, current.id),
                      ]),
              ),
            ),
            _TotalBar(
              rows: items.value ?? const [],
              rate: ref
                  .watch(taxRatesProvider)
                  .value
                  ?.where((r) => r.id == current.taxRateId)
                  .firstOrNull,
            ),
          ]),
        );
      },
    );
  }
}

/// Unchecked items under category headers in store-walking order, followed by
/// a "Checked" section.
List<Widget> _grouped(List<ShoppingItem> rows, Map<String, int> order,
    AppDatabase db, List<ShoppingList> lists, String listId) {
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
      for (final i in byCategory[n]!) _ItemTile(item: i, db: db, lists: lists, listId: listId),
    ],
    if (done.isNotEmpty) ...[
      const _Header('Checked'),
      for (final i in done) _ItemTile(item: i, db: db, lists: lists, listId: listId),
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
  const _ItemTile(
      {required this.item,
      required this.db,
      required this.lists,
      required this.listId});
  final ShoppingItem item;
  final AppDatabase db;
  final List<ShoppingList> lists;
  final String listId;

  Future<void> _edit(BuildContext context) async {
    final result = await showItemEditor(
      context,
      title: 'Edit item',
      showPrice: true,
      initial: ItemEdit(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        category: item.category,
        price: item.price,
        note: item.note,
        taxable: item.taxable,
        hasCoupon: item.hasCoupon,
      ),
      lists: [for (final l in lists) (id: l.id, name: l.name)],
      currentListId: listId,
    );
    Future<void> save(ItemEdit edit) => db.updateShoppingItem(item.id,
        name: edit.name,
        quantity: edit.quantity,
        unit: edit.unit,
        category: edit.category,
        price: edit.price,
        note: edit.note,
        taxable: edit.taxable,
        hasCoupon: edit.hasCoupon);
    switch (result) {
      case ItemSaved(:final edit):
        await save(edit);
      case ItemDeleted():
        await db.deleteShoppingItem(item.id);
      case ItemMoved(:final edit, :final listId):
        await save(edit);
        await db.moveShoppingItem(item.id, listId);
      case ItemCopied(:final edit, :final listId):
        await save(edit);
        await db.copyShoppingItem(
            item.copyWith(
                name: edit.name,
                quantity: edit.quantity,
                unit: edit.unit,
                category: edit.category,
                price: Value(edit.price),
                note: edit.note,
                taxable: edit.taxable,
                hasCoupon: edit.hasCoupon),
            listId);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = [
      if (item.quantity != 1 || item.unit.isNotEmpty)
        '${formatQuantity(item.quantity)} ${item.unit}'.trim(),
      if (item.price != null) formatMoney(item.price! * item.quantity),
      if (item.hasCoupon) 'coupon',
      if (item.taxable) 'tax',
    ].join(' · ');
    return Dismissible(
      key: ValueKey(item.id),
      background: Container(color: Colors.red.shade300),
      onDismissed: (_) => db.deleteShoppingItem(item.id),
      child: ListTile(
        onTap: () => _edit(context),
        leading: Checkbox(
            value: item.checked,
            onChanged: (v) => db.setChecked(item.id, v ?? false)),
        title: Text(item.name,
            style: item.checked
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null),
        subtitle: (details.isEmpty && item.note.isEmpty)
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (details.isNotEmpty) Text(details),
                  if (item.note.isNotEmpty)
                    Text(item.note, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
        trailing: IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(context)),
      ),
    );
  }
}

/// Subtotal, tax (at the list's chosen rate) and total, plus what is still to
/// buy. Hidden when nothing has a price.
class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.rows, required this.rate});
  final List<ShoppingItem> rows;
  final TaxRate? rate;

  @override
  Widget build(BuildContext context) {
    final t = computeTotals(rows, rate?.percent);
    if (!t.hasPrices) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 4,
            children: [
              if (rate != null) Text('Subtotal ${formatMoney(t.subtotal)}'),
              if (rate != null)
                Text('Tax ${formatPercent(rate!.percent)}% '
                    '${formatMoney(t.tax)}'),
              Text('Total ${formatMoney(t.total)}',
                  style: theme.textTheme.titleSmall),
              Text('Still to buy ${formatMoney(t.remaining)}'),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> _confirm(BuildContext context, String title, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete')),
      ],
    ),
  );
  return ok ?? false;
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
