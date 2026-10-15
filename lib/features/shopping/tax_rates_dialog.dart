import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tax_rules.dart';
import '../../services/tax_lookup.dart';

String formatPercent(double p) {
  final text = p.toStringAsFixed(3);
  // Trim trailing zeros: 8.250 -> 8.25, 7.000 -> 7
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Pick the sales tax rate for a list, and add, edit or delete saved rates.
///
/// No rates are built in: tax differs by country, state and region, so you
/// enter the ones that apply where you shop (e.g. "Home 8.25%"), or tap "Use my
/// location" to fill one in.
class TaxRatesDialog extends ConsumerStatefulWidget {
  const TaxRatesDialog({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<TaxRatesDialog> createState() => _TaxRatesDialogState();
}

class _TaxRatesDialogState extends ConsumerState<TaxRatesDialog> {
  bool _busy = false;
  String? _status;

  /// "Use my location": read the position once, name the place (OpenStreetMap)
  /// and, in the US, look up the combined rate (Ziptax, with the user's key).
  /// The result pre-fills the add-rate form so the user confirms it.
  Future<void> _useLocation() async {
    final db = ref.read(databaseProvider);
    setState(() {
      _busy = true;
      _status = 'Finding your location...';
    });
    try {
      final pos = await currentPosition();
      if (!mounted) return;
      setState(() => _status = 'Looking up your area...');
      final place = await reversePlace(pos.latitude, pos.longitude);

      double? percent;
      String? note;
      if (place?.isUs ?? false) {
        var key = await loadZiptaxKey();
        if (key == null && mounted) {
          key = await _askForKey(context);
        }
        if (key == null) {
          note =
              'Add a Ziptax API key to look up the exact rate '
              'automatically.';
        } else {
          if (!mounted) return;
          setState(() => _status = 'Looking up the sales tax rate...');
          percent = await ziptaxPercent(pos.latitude, pos.longitude, key);
        }
      } else {
        note =
            'Automatic rates are only available in the US. Enter the rate '
            'that applies here.';
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
      });
      final id = await _editRate(
        context,
        db,
        initialName: place?.label ?? '',
        initialPercent: percent,
        initialRuleId: place?.isUs == true
            ? TaxRuleSet.forStateName(place!.region)?.id
            : null,
        note: percent != null
            ? 'Rate found for your location. Local rates change, so check it '
                  'against a receipt.'
            : note,
      );
      if (id != null) await db.setListTaxRate(widget.listId, id);
    } on LookupException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.read(databaseProvider);
    final rates = ref.watch(taxRatesProvider).value ?? const <TaxRate>[];
    final lists = ref.watch(listsProvider).value ?? const <ShoppingList>[];
    final selected = lists
        .where((l) => l.id == widget.listId)
        .firstOrNull
        ?.taxRateId;
    final theme = Theme.of(context);

    Widget option({
      required String title,
      String? subtitle,
      required bool isSelected,
      required VoidCallback onTap,
      Widget? trailing,
    }) => ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 4, right: 0),
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
      ),
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
                'Tax rates differ by country, state and region, so use the '
                'rate that applies where you shop. Only items marked "has '
                'sales tax" are taxed.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              option(
                title: 'No tax',
                isSelected: selected == null,
                onTap: () => db.setListTaxRate(widget.listId, null),
              ),
              for (final r in rates)
                option(
                  title: r.name,
                  subtitle: _rateSubtitle(r),
                  isSelected: selected == r.id,
                  onTap: () => db.setListTaxRate(widget.listId, r.id),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final id = await _editRate(context, db);
                            if (id != null) {
                              await db.setListTaxRate(widget.listId, id);
                            }
                          },
                    icon: const Icon(Icons.add),
                    label: const Text('Add a tax rate'),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : _useLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Use my location'),
                  ),
                ],
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_status!, style: theme.textTheme.bodySmall),
                ),
              const SizedBox(height: 8),
              Text(
                'Using your location sends your coordinates to OpenStreetMap '
                '(to name the place) and, in the US, to Ziptax (to find the '
                'rate). Nothing is sent until you tap the button.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : () => _askForKey(context),
                child: const Text('Ziptax API key...'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Asks for (or clears) the user's own Ziptax API key. Returns the saved key,
/// or null if there is none.
Future<String?> _askForKey(BuildContext context) async {
  final controller = TextEditingController(text: await loadZiptaxKey() ?? '');
  if (!context.mounted) return null;
  final saved = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Ziptax API key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'For automatic US tax rates. Create a free account at '
            'platform.zip.tax and paste your own key here (the free plan '
            'allows 100 lookups a month). It is kept on this device only.',
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'API key'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ''),
          child: const Text('Remove key'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (saved == null) return loadZiptaxKey(); // cancelled: keep what we had
  await saveZiptaxKey(saved);
  return saved.isEmpty ? null : saved;
}

/// Asks for a rate name, percentage, tax rules and optional grocery rate;
/// returns the saved rate's id, or null if cancelled. [initialName],
/// [initialPercent], [initialRuleId] and [note] pre-fill the form when the
/// values come from a location lookup.
Future<String?> _editRate(
  BuildContext context,
  AppDatabase db, {
  TaxRate? existing,
  String initialName = '',
  double? initialPercent,
  String? initialRuleId,
  String? note,
}) {
  final name = TextEditingController(text: existing?.name ?? initialName);
  final percent = TextEditingController(
    text: existing != null
        ? formatPercent(existing.percent)
        : (initialPercent == null ? '' : formatPercent(initialPercent)),
  );
  final grocery = TextEditingController(
    text: existing?.groceryPercent == null
        ? ''
        : formatPercent(existing!.groceryPercent!),
  );
  var ruleId = existing?.ruleSet ?? initialRuleId ?? 'everything';
  String? error;
  String? groceryError;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final rules = TaxRuleSet.fromId(ruleId);
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text(existing == null ? 'Add tax rate' : 'Edit tax rate'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (note != null) ...[
                    Text(note, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'Home, Seattle, Ontario HST...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: percent,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Full rate (%)',
                      hintText: '10.25',
                      errorText: error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: ruleId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'What is taxed',
                    ),
                    items: [
                      for (final r in TaxRuleSet.all)
                        DropdownMenuItem(
                          value: r.id,
                          child: Text(r.title, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => ruleId = v ?? ruleId),
                  ),
                  const SizedBox(height: 6),
                  Text(rules.description, style: theme.textTheme.bodySmall),
                  if (rules.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      rules.note,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: grocery,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: rules.groceryRateNeeded
                          ? 'Grocery rate (%) - needed for this state'
                          : 'Grocery rate (%) - optional',
                      hintText: rules.foodTaxedFully
                          ? 'blank = same as the full rate'
                          : 'blank = groceries not taxed',
                      errorText: groceryError,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Only fill this in if groceries are taxed at a different '
                    'rate where you shop, for example a city or county grocery '
                    'tax. Tax rules are an estimate based on published '
                    'summaries; check your state revenue department.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final n = name.text.trim();
                final p = double.tryParse(
                  percent.text.trim().replaceAll(',', '.'),
                );
                final gText = grocery.text.trim().replaceAll(',', '.');
                final g = gText.isEmpty ? null : double.tryParse(gText);
                if (n.isEmpty) return;
                if (p == null || p < 0 || p > 100) {
                  setState(() => error = 'Enter a number from 0 to 100');
                  return;
                }
                if (gText.isNotEmpty && (g == null || g < 0 || g > 100)) {
                  setState(() => groceryError = 'Enter a number from 0 to 100');
                  return;
                }
                String id;
                if (existing == null) {
                  id = await db.addTaxRate(
                    n,
                    p,
                    ruleSet: ruleId,
                    groceryPercent: g,
                  );
                } else {
                  await db.updateTaxRate(
                    existing.id,
                    n,
                    p,
                    ruleSet: ruleId,
                    groceryPercent: g,
                  );
                  id = existing.id;
                }
                if (ctx.mounted) Navigator.pop(ctx, id);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );
}

String _rateSubtitle(TaxRate r) {
  final rules = TaxRuleSet.fromId(r.ruleSet);
  final parts = [
    '${formatPercent(r.percent)}%',
    if (rules.id != 'everything') '${rules.title} rules',
    if (r.groceryPercent != null)
      'groceries ${formatPercent(r.groceryPercent!)}%',
  ];
  return parts.join(' - ');
}
