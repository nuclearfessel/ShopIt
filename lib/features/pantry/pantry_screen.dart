import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/catalog_seed.dart';
import '../../data/providers.dart';
import '../catalog/catalog_suggestions.dart';
import '../catalog/item_editor.dart';

class PantryScreen extends ConsumerWidget {
  const PantryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(pantryProvider);
    final db = ref.read(databaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pantry')),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rows) => rows.isEmpty
            ? const Center(child: Text('Pantry is empty'))
            : ListView(
                children: [for (final i in rows) _PantryTile(item: i, db: db)],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add pantry item',
        onPressed: () => _showAddDialog(context, db),
        child: const Icon(Icons.add),
      ),
    );
  }
}

String _fmt(double q) => q == q.roundToDouble() ? q.toInt().toString() : '$q';

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _PantryTile extends StatelessWidget {
  const _PantryTile({required this.item, required this.db});
  final PantryItem item;
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final expiry = item.expiryDate;
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final expired = expiry != null && expiry.isBefore(startOfToday);
    final soon =
        expiry != null &&
        !expired &&
        expiry.difference(startOfToday).inDays <= 3;
    final color = expired
        ? Colors.red
        : soon
        ? Colors.orange
        : null;
    return Dismissible(
      key: ValueKey(item.id),
      background: Container(color: Colors.red.shade300),
      onDismissed: (_) => db.deletePantryItem(item.id),
      child: LayoutBuilder(
        builder: (context, box) {
          final theme = Theme.of(context);
          final details = [
            if (item.location.isNotEmpty) item.location,
            if (expiry != null) 'Expires ${_date(expiry)}',
          ].join(' · ');
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.name,
                style: theme.textTheme.bodyLarge?.copyWith(color: color),
              ),
              if (details.isNotEmpty)
                Text(
                  details,
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              if (item.note.isNotEmpty)
                Text(
                  item.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
            ],
          );
          final stepper = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Decrease',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: item.quantity <= 0
                    ? null
                    : () => db.updatePantryQuantity(item.id, item.quantity - 1),
              ),
              Flexible(
                child: Text(
                  '${_fmt(item.quantity)} ${item.unit}'.trim(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Increase',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () =>
                    db.updatePantryQuantity(item.id, item.quantity + 1),
              ),
            ],
          );
          // Narrow windows: put the stepper under the text instead of beside it.
          return InkWell(
            onTap: () => _edit(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: box.maxWidth < 380
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [text, stepper],
                    )
                  : Row(
                      children: [
                        Expanded(child: text),
                        stepper,
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final result = await showItemEditor(
      context,
      title: 'Edit pantry item',
      showPantryFields: true,
      initial: ItemEdit(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        category: item.category,
        note: item.note,
        location: item.location,
        expiry: item.expiryDate,
      ),
    );
    switch (result) {
      case ItemSaved(:final edit):
        await db.updatePantryItem(
          item.id,
          name: edit.name,
          quantity: edit.quantity,
          unit: edit.unit,
          category: edit.category,
          location: edit.location,
          expiryDate: edit.expiry,
          note: edit.note,
        );
      case ItemDeleted():
        await db.deletePantryItem(item.id);
      case ItemMoved() || ItemCopied() || null:
        break; // move/copy only apply to shopping items
    }
  }
}

Future<void> _showAddDialog(BuildContext context, AppDatabase db) {
  final name = TextEditingController();
  final qty = TextEditingController(text: '1');
  final unit = TextEditingController();
  final location = TextEditingController();
  DateTime? expiry;
  var category = '';
  String? pickedName;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Add pantry item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Search or add an item',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              CatalogSuggestions(
                query: pickedName == name.text ? '' : name.text,
                onPick: (i) => setState(() {
                  name.text = i.name;
                  pickedName = i.name;
                  category = i.category;
                  if (unit.text.isEmpty) unit.text = i.defaultUnit;
                }),
              ),
              DropdownButtonFormField<String>(
                initialValue: category.isEmpty ? null : category,
                key: ValueKey(category),
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in catalogSeed.keys)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => category = v ?? ''),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qty,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: location,
                decoration: const InputDecoration(
                  labelText: 'Location (fridge, shelf, ...)',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      expiry == null
                          ? 'No expiry date'
                          : 'Expires ${_date(expiry!)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: expiry ?? now,
                        firstDate: now.subtract(const Duration(days: 365)),
                        lastDate: now.add(const Duration(days: 365 * 10)),
                      );
                      if (d != null) setState(() => expiry = d);
                    },
                    child: const Text('Set date'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final n = name.text.trim();
              if (n.isEmpty) return;
              db.addPantryItem(
                n,
                quantity: double.tryParse(qty.text.trim()) ?? 1,
                unit: unit.text.trim(),
                expiryDate: expiry,
                location: location.text.trim(),
                category: category.isEmpty ? 'Other' : category,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
}
