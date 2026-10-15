import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';

String formatPercent(double p) {
  final text = p.toStringAsFixed(3);
  // Trim trailing zeros: 8.250 -> 8.25, 7.000 -> 7
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Pick the sales tax rate for a list, and add, edit or delete saved rates.
///
/// No rates are built in: tax differs by country, state and region, so you
/// enter the ones that apply where you shop (e.g. "Home 8.25%").
class TaxRatesDialog extends ConsumerWidget {
  const TaxRatesDialog({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final rates = ref.watch(taxRatesProvider).value ?? const <TaxRate>[];
    final lists = ref.watch(listsProvider).value ?? const <ShoppingList>[];
    final selected =
        lists.where((l) => l.id == listId).firstOrNull?.taxRateId;
    final theme = Theme.of(context);

    Widget option({
      required String title,
      String? subtitle,
      required bool isSelected,
      required VoidCallback onTap,
      Widget? trailing,
    }) =>
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 4, right: 0),
          leading: Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off),
          title: Text(title, overflow: TextOverflow.ellipsis),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: trailing,
          onTap: onTap,
        );

    return AlertDialog(
      title: const Text('Sales tax for this list'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tax rates differ by country, state and region, so enter the '
                'rate that applies where you shop. Only items marked "has '
                'sales tax" are taxed.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              option(
                title: 'No tax',
                isSelected: selected == null,
                onTap: () => db.setListTaxRate(listId, null),
              ),
              for (final r in rates)
                option(
                  title: r.name,
                  subtitle: '${formatPercent(r.percent)}%',
                  isSelected: selected == r.id,
                  onTap: () => db.setListTaxRate(listId, r.id),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Edit rate',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editRate(context, db, existing: r),
                    ),
                    IconButton(
                      tooltip: 'Delete rate',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => db.deleteTaxRate(r.id),
                    ),
                  ]),
                ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () async {
                  final id = await _editRate(context, db);
                  if (id != null) await db.setListTaxRate(listId, id);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add a tax rate'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  }
}

/// Asks for a rate name and percentage; returns the saved rate's id, or null if
/// cancelled.
Future<String?> _editRate(BuildContext context, AppDatabase db,
    {TaxRate? existing}) {
  final name = TextEditingController(text: existing?.name ?? '');
  final percent = TextEditingController(
      text: existing == null ? '' : formatPercent(existing.percent));
  String? error;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(existing == null ? 'Add tax rate' : 'Edit tax rate'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: name,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: 'Name', hintText: 'Home, Oregon, Ontario HST...'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: percent,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: 'Rate (%)', hintText: '8.25', errorText: error),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final n = name.text.trim();
              final p = double.tryParse(percent.text.trim().replaceAll(',', '.'));
              if (n.isEmpty) {
                setState(() => error = null);
                return;
              }
              if (p == null || p < 0 || p > 100) {
                setState(() => error = 'Enter a number from 0 to 100');
                return;
              }
              String id;
              if (existing == null) {
                id = await db.addTaxRate(n, p);
              } else {
                await db.updateTaxRate(existing.id, n, p);
                id = existing.id;
              }
              if (ctx.mounted) Navigator.pop(ctx, id);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
