import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';

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
            : ListView(children: [
                for (final i in rows) _PantryTile(item: i, db: db),
              ]),
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
    final soon = expiry != null &&
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
      child: ListTile(
        title: Text(item.name),
        subtitle: Text([
          if (item.location.isNotEmpty) item.location,
          if (expiry != null) 'Expires ${_date(expiry)}',
        ].join(' · ')),
        textColor: color,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              tooltip: 'Decrease',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: item.quantity <= 0
                  ? null
                  : () => db.updatePantryQuantity(item.id, item.quantity - 1)),
          Text('${_fmt(item.quantity)} ${item.unit}'.trim()),
          IconButton(
              tooltip: 'Increase',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () =>
                  db.updatePantryQuantity(item.id, item.quantity + 1)),
        ]),
      ),
    );
  }
}

Future<void> _showAddDialog(BuildContext context, AppDatabase db) {
  final name = TextEditingController();
  final qty = TextEditingController(text: '1');
  final unit = TextEditingController();
  final location = TextEditingController();
  DateTime? expiry;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Add pantry item'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name')),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: qty,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Quantity'))),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                      controller: unit,
                      decoration: const InputDecoration(labelText: 'Unit'))),
            ]),
            TextField(
                controller: location,
                decoration: const InputDecoration(
                    labelText: 'Location (fridge, shelf, ...)')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: Text(expiry == null
                      ? 'No expiry date'
                      : 'Expires ${_date(expiry!)}')),
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
            ]),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final n = name.text.trim();
              if (n.isEmpty) return;
              db.addPantryItem(n,
                  quantity: double.tryParse(qty.text.trim()) ?? 1,
                  unit: unit.text.trim(),
                  expiryDate: expiry,
                  location: location.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
}
