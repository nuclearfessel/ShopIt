import 'package:flutter/material.dart';

import '../../data/catalog_seed.dart';

/// Values edited in [showItemEditor]. Fields that don't apply to an item kind
/// (price for pantry items, expiry/location for shopping items) stay unused.
class ItemEdit {
  ItemEdit({
    required this.name,
    this.quantity = 1,
    this.unit = '',
    this.category = '',
    this.price,
    this.note = '',
    this.location = '',
    this.expiry,
  });

  String name;
  double quantity;
  String unit;
  String category;
  double? price;
  String note;
  String location;
  DateTime? expiry;
}

String formatQuantity(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toString();

String formatMoney(double v) => v.toStringAsFixed(2);

/// Result of the editor: a saved edit, or a request to delete the item.
sealed class ItemEditorResult {}

class ItemSaved extends ItemEditorResult {
  ItemSaved(this.edit);
  final ItemEdit edit;
}

class ItemDeleted extends ItemEditorResult {}

/// Out-of-Milk-style item details sheet: change quantity, unit, category,
/// price and a note; pantry items also get a location and expiry date.
Future<ItemEditorResult?> showItemEditor(
  BuildContext context, {
  required String title,
  required ItemEdit initial,
  bool showPrice = false,
  bool showPantryFields = false,
}) {
  Widget sheet(BuildContext _) => _ItemEditorSheet(
    title: title,
    initial: initial,
    showPrice: showPrice,
    showPantryFields: showPantryFields,
  );
  // Wide windows (side navigation visible): a dialog centered in the window.
  // Narrow windows (bottom navigation): a bottom sheet.
  if (MediaQuery.sizeOf(context).width >= 700) {
    return showDialog<ItemEditorResult>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: sheet(ctx),
        ),
      ),
    );
  }
  return showModalBottomSheet<ItemEditorResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: sheet,
  );
}

class _ItemEditorSheet extends StatefulWidget {
  const _ItemEditorSheet({
    required this.title,
    required this.initial,
    required this.showPrice,
    required this.showPantryFields,
  });

  final String title;
  final ItemEdit initial;
  final bool showPrice;
  final bool showPantryFields;

  @override
  State<_ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<_ItemEditorSheet> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _qty = TextEditingController(
    text: formatQuantity(widget.initial.quantity),
  );
  late final _unit = TextEditingController(text: widget.initial.unit);
  late final _price = TextEditingController(
    text: widget.initial.price == null
        ? ''
        : formatMoney(widget.initial.price!),
  );
  late final _note = TextEditingController(text: widget.initial.note);
  late final _location = TextEditingController(text: widget.initial.location);
  late String _category = widget.initial.category;
  DateTime? _expiry;

  @override
  void initState() {
    super.initState();
    _expiry = widget.initial.expiry;
  }

  @override
  void dispose() {
    for (final c in [_name, _qty, _unit, _price, _note, _location]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _quantity => double.tryParse(_qty.text.trim()) ?? 1;
  double? get _priceValue => double.tryParse(_price.text.trim());

  void _step(double by) {
    final next = (_quantity + by).clamp(0, 9999).toDouble();
    setState(() => _qty.text = formatQuantity(next));
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      ItemSaved(
        ItemEdit(
          name: name,
          quantity: _quantity,
          unit: _unit.text.trim(),
          category: _category,
          price: _priceValue,
          note: _note.text.trim(),
          location: _location.text.trim(),
          expiry: _expiry,
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (d != null) setState(() => _expiry = d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = {
      ...catalogSeed.keys,
      if (_category.isNotEmpty) _category,
    };
    final price = _priceValue;
    // Compact type for the editor: 14px input text, 13px titles.
    final compact = theme.copyWith(
      textTheme: theme.textTheme.copyWith(
        bodyLarge: theme.textTheme.bodyLarge?.copyWith(fontSize: 14),
        titleLarge: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
      ),
    );
    return Theme(
      data: compact,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.outlined(
                              tooltip: 'Less',
                              icon: const Icon(Icons.remove),
                              onPressed: () => _step(-1),
                            ),
                            SizedBox(
                              width: 72,
                              child: TextField(
                                controller: _qty,
                                textAlign: TextAlign.center,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            IconButton.outlined(
                              tooltip: 'More',
                              icon: const Icon(Icons.add),
                              onPressed: () => _step(1),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _unit,
                            decoration: const InputDecoration(
                              labelText: 'Unit (kg, pack...)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _category.isEmpty ? null : _category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        for (final c in categories)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (v) => setState(() => _category = v ?? ''),
                    ),
                    if (widget.showPrice) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            width: 140,
                            child: TextField(
                              controller: _price,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Price each',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (price != null)
                            Flexible(
                              child: Text(
                                'Total ${formatMoney(price * _quantity)}',
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (widget.showPantryFields) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _location,
                        decoration: const InputDecoration(
                          labelText: 'Location (fridge, shelf, ...)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            _expiry == null
                                ? 'No expiry date'
                                : 'Expires ${_expiry!.year}-${_expiry!.month.toString().padLeft(2, '0')}-${_expiry!.day.toString().padLeft(2, '0')}',
                          ),
                          TextButton(
                            onPressed: _pickDate,
                            child: const Text('Set date'),
                          ),
                          if (_expiry != null)
                            TextButton(
                              onPressed: () => setState(() => _expiry = null),
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _note,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Notes (brand, flavour, coupon...)',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Pinned so Save/Cancel stay reachable on short windows.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context, ItemDeleted()),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(onPressed: _save, child: const Text('Save')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
