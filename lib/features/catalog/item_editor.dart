import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/catalog_seed.dart';
import '../../ui/keyline/keyline_icon.dart';
import '../../ui/choice_field.dart';
import '../../ui/tip.dart';

/// Values edited in [showItemEditor]. Fields that don't apply to an item kind
/// (price/tax/coupon for pantry items, expiry/location for shopping items)
/// stay unused.
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
    this.taxable = false,
    this.hasCoupon = false,
    this.quantityMode = 'number',
    this.level = 'full',
  });

  String name;
  double quantity;
  String unit;
  String category;
  double? price;
  String note;
  String location;
  DateTime? expiry;

  /// Pantry items: 'level' shows Low/Full, 'number' shows [quantity].
  String quantityMode;

  /// Pantry items in 'level' mode: 'low' or 'full'.
  String level;
  bool taxable;
  bool hasCoupon;
}

String formatQuantity(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toString();

/// A plain number with two decimals, for text fields ("3.50").
String formatDecimal(double v) => v.toStringAsFixed(2);

/// A price for display, with the currency symbol and separators ("$1,234.50").
/// Uses the system locale's currency, falling back to US dollars.
String formatMoney(double v) {
  try {
    return NumberFormat.simpleCurrency(locale: Platform.localeName).format(v);
  } on Object {
    return NumberFormat.simpleCurrency(locale: 'en_US').format(v);
  }
}

/// Result of the editor. Move and copy carry the edit too, so any unsaved
/// changes are kept.
sealed class ItemEditorResult {}

class ItemSaved extends ItemEditorResult {
  ItemSaved(this.edit);
  final ItemEdit edit;
}

class ItemDeleted extends ItemEditorResult {}

class ItemMoved extends ItemEditorResult {
  ItemMoved(this.edit, this.listId);
  final ItemEdit edit;
  final String listId;
}

class ItemCopied extends ItemEditorResult {
  ItemCopied(this.edit, this.listId);
  final ItemEdit edit;
  final String listId;
}

/// A list an item can be moved or copied to.
typedef ListChoice = ({String id, String name});

/// Common units for the unit dropdown ('' means none).
const _units = [
  '',
  'pcs',
  'pack',
  'can',
  'bottle',
  'box',
  'bag',
  'dozen',
  'kg',
  'g',
  'lb',
  'oz',
  'L',
  'ml',
];

/// Item details editor: Cancel/Save header, name, a quantity row ([-][+]
/// stepper, value, unit), category, unit price with sales-tax and coupon
/// checkboxes, notes, and Delete/Move/Copy along the bottom. Pantry items get
/// location and expiry instead of price.
///
/// Pass [lists] and [currentListId] on shopping items to enable Move and Copy.
Future<ItemEditorResult?> showItemEditor(
  BuildContext context, {
  required String title,
  required ItemEdit initial,
  bool showPrice = false,
  bool showPantryFields = false,
  List<ListChoice> lists = const [],
  String? currentListId,
  String? taxHint,

  /// The categories to choose from (defaults to the built-in ones).
  List<String>? categories,

  /// A new item that is about to be added: no Delete, and Save says Add.
  bool isNew = false,
}) {
  Widget sheet(BuildContext _) => _ItemEditorSheet(
    title: title,
    initial: initial,
    showPrice: showPrice,
    showPantryFields: showPantryFields,
    lists: lists,
    currentListId: currentListId,
    taxHint: taxHint,
    categories: categories,
    isNew: isNew,
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
    required this.lists,
    required this.currentListId,
    required this.taxHint,
    required this.categories,
    required this.isNew,
  });

  final String title;
  final ItemEdit initial;
  final bool showPrice;
  final bool showPantryFields;
  final List<ListChoice> lists;
  final String? currentListId;

  /// Why the item is or is not taxed, shown under the tax checkbox.
  final String? taxHint;
  final List<String>? categories;
  final bool isNew;

  @override
  State<_ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<_ItemEditorSheet> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _qty = TextEditingController(
    text: formatQuantity(widget.initial.quantity),
  );
  late final _price = TextEditingController(
    text: widget.initial.price == null
        ? ''
        : formatDecimal(widget.initial.price!),
  );
  late final _note = TextEditingController(text: widget.initial.note);
  late final _location = TextEditingController(text: widget.initial.location);
  late String _category = widget.initial.category;
  late String _unit = widget.initial.unit;
  late bool _taxable = widget.initial.taxable;
  late bool _coupon = widget.initial.hasCoupon;
  late String _mode = widget.initial.quantityMode;
  late String _level = widget.initial.level;
  DateTime? _expiry;

  @override
  void initState() {
    super.initState();
    _expiry = widget.initial.expiry;
  }

  @override
  void dispose() {
    for (final c in [_name, _qty, _price, _note, _location]) {
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

  ItemEdit _current() => ItemEdit(
    name: _name.text.trim(),
    quantity: _quantity,
    unit: _unit,
    category: _category,
    price: _priceValue,
    note: _note.text.trim(),
    location: _location.text.trim(),
    expiry: _expiry,
    taxable: _taxable,
    hasCoupon: _coupon,
    quantityMode: _mode,
    level: _level,
  );

  void _save() {
    if (_name.text.trim().isEmpty) return;
    Navigator.pop(context, ItemSaved(_current()));
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

  /// Asks which list to move/copy to, then closes the editor with the choice.
  Future<void> _chooseList({required bool move}) async {
    final choices = widget.lists
        .where((l) => !move || l.id != widget.currentListId)
        .toList();
    if (choices.isEmpty || _name.text.trim().isEmpty) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(move ? 'Move to list' : 'Copy to list'),
        children: [
          for (final l in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, l.id),
              child: Tip(
                '${move ? 'Move' : 'Copy'} it to "${l.name}"',
                child: Text(l.name),
              ),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    Navigator.pop(
      context,
      move ? ItemMoved(_current(), picked) : ItemCopied(_current(), picked),
    );
  }

  String _dateText(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
    ),
  );

  /// The [-][+] pair as one joined control.
  Widget _stepper(ColorScheme scheme) => Container(
    height: 48,
    decoration: BoxDecoration(
      border: Border.all(color: scheme.outline),
      borderRadius: BorderRadius.circular(12),
    ),
    clipBehavior: Clip.antiAlias,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: KeylineIcons.minus,
          tooltip: 'Less',
          onPressed: () => _step(-1),
        ),
        VerticalDivider(width: 1, color: scheme.outline),
        _StepButton(
          icon: KeylineIcons.plus,
          tooltip: 'More',
          onPressed: () => _step(1),
        ),
      ],
    ),
  );

  Widget _quantityValue() => SizedBox(
    height: 48,
    child: TextField(
      controller: _qty,
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
      onChanged: (_) => setState(() {}),
    ),
  );

  Widget _unitDropdown() {
    final units = [..._units, if (!_units.contains(_unit)) _unit];
    return Tip(
      'Choose a unit',
      child: ChoiceField<String>(
        value: _unit,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        choices: [for (final u in units) Choice(u, u.isEmpty ? 'No unit' : u)],
        onChanged: (v) => setState(() => _unit = v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final categories = {
      ...(widget.categories ?? catalogSeed.keys),
      if (_category.isNotEmpty) _category,
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final price = _priceValue;
    final valueStyle = theme.textTheme.bodyLarge?.copyWith(fontSize: 14);
    final outline = OutlineInputBorder(borderRadius: BorderRadius.circular(12));
    // Compact type and uniform outlined fields for the editor.
    final compact = theme.copyWith(
      textTheme: theme.textTheme.copyWith(
        bodyLarge: valueStyle,
        titleLarge: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
    const gap = SizedBox(height: 18);
    final canMoveCopy = widget.lists.isNotEmpty;
    final canMove = widget.lists.any((l) => l.id != widget.currentListId);
    return Theme(
      data: compact,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Cancel left, title, Save right. Always visible.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
              child: LayoutBuilder(
                builder: (context, box) {
                  final narrow = box.maxWidth < 330;
                  return Row(
                    children: [
                      narrow
                          ? Tip(
                              'Discard your changes',
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            )
                          : Tip(
                              'Discard your changes',
                              child: TextButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: const KeylineIcon(KeylineIcons.x),
                                label: const Text('Cancel'),
                              ),
                            ),
                      Expanded(
                        child: narrow
                            ? const SizedBox.shrink()
                            : Text(
                                widget.title,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge,
                              ),
                      ),
                      Tip(
                        widget.isNew
                            ? 'Add this item to the list'
                            : 'Save your changes',
                        child: FilledButton(
                          onPressed: _save,
                          child: Text(widget.isNew ? 'Add' : 'Save'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 16),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    gap,
                    if (widget.showPantryFields) ...[
                      _label('Amount'),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: 'level',
                            label: Text('Low / Full'),
                            tooltip: 'Just track whether it is low or full',
                          ),
                          ButtonSegment(
                            value: 'number',
                            label: Text('Number'),
                            tooltip: 'Track an exact quantity',
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (v) =>
                            setState(() => _mode = v.first),
                      ),
                      const SizedBox(height: 10),
                      if (_mode == 'level')
                        SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: 'low',
                              label: Text('Low'),
                              tooltip: 'Running low: time to restock',
                            ),
                            ButtonSegment(
                              value: 'full',
                              label: Text('Full'),
                              tooltip: 'Plenty left',
                            ),
                          ],
                          selected: {_level},
                          onSelectionChanged: (v) =>
                              setState(() => _level = v.first),
                        ),
                    ],
                    if (!widget.showPantryFields || _mode == 'number') ...[
                      if (!widget.showPantryFields) _label('Quantity'),
                      LayoutBuilder(
                        builder: (context, box) {
                          final narrow = box.maxWidth < 340;
                          final stepRow = Row(
                            children: [
                              _stepper(scheme),
                              const SizedBox(width: 10),
                              Expanded(child: _quantityValue()),
                              if (!narrow) ...[
                                const SizedBox(width: 10),
                                Expanded(flex: 2, child: _unitDropdown()),
                              ],
                            ],
                          );
                          return narrow
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    stepRow,
                                    const SizedBox(height: 10),
                                    _unitDropdown(),
                                  ],
                                )
                              : stepRow;
                        },
                      ),
                    ],
                    gap,
                    _label('Category'),
                    Tip(
                      'Choose a category',
                      child: ChoiceField<String>(
                        value: _category.isEmpty ? null : _category,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        choices: [for (final c in categories) Choice(c, c)],
                        onChanged: (v) => setState(() => _category = v),
                      ),
                    ),
                    if (widget.showPrice) ...[
                      gap,
                      _label('Unit price'),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _price,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                hintText: '0.00',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              price == null
                                  ? ''
                                  : 'Total ${formatMoney(price * _quantity)}',
                              style: valueStyle?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Tip(
                        'Add sales tax to this item',
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.trailing,
                          title: const Text('Item has sales tax'),
                          subtitle: widget.taxHint == null
                              ? null
                              : Text(widget.taxHint!),
                          value: _taxable,
                          onChanged: (v) =>
                              setState(() => _taxable = v ?? false),
                        ),
                      ),
                      Tip(
                        'Note that you have a coupon for this item',
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.trailing,
                          title: const Text('I have a coupon for this item'),
                          value: _coupon,
                          onChanged: (v) =>
                              setState(() => _coupon = v ?? false),
                        ),
                      ),
                    ],
                    if (widget.showPantryFields) ...[
                      gap,
                      TextField(
                        controller: _location,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          hintText: 'fridge, shelf, freezer...',
                        ),
                      ),
                      gap,
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Expiry date',
                            suffixIcon: _expiry == null
                                ? const KeylineIcon(KeylineIcons.calendar)
                                : IconButton(
                                    tooltip: 'Clear date',
                                    icon: const KeylineIcon(KeylineIcons.x),
                                    onPressed: () =>
                                        setState(() => _expiry = null),
                                  ),
                          ),
                          child: Tip(
                            'Choose an expiry date',
                            child: Text(
                              _expiry == null ? 'Not set' : _dateText(_expiry!),
                              style: valueStyle?.copyWith(
                                color: _expiry == null
                                    ? scheme.onSurface.withValues(alpha: 0.4)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    gap,
                    TextField(
                      controller: _note,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'brand, flavour, ...',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Bottom actions, evenly spaced.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Wrap(
                alignment: WrapAlignment.spaceEvenly,
                children: [
                  if (!widget.isNew)
                    Tip(
                      'Delete this item',
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context, ItemDeleted()),
                        icon: const KeylineIcon(KeylineIcons.bin),
                        label: const Text('Delete'),
                      ),
                    ),
                  if (canMoveCopy) ...[
                    Tip(
                      'Move this item to another list',
                      child: TextButton.icon(
                        onPressed: canMove
                            ? () => _chooseList(move: true)
                            : null,
                        icon: const KeylineIcon(KeylineIcons.folderArrowRight),
                        label: const Text('Move'),
                      ),
                    ),
                    Tip(
                      'Copy this item to a list',
                      child: TextButton.icon(
                        onPressed: () => _chooseList(move: false),
                        icon: const KeylineIcon(KeylineIcons.copy),
                        label: const Text('Copy'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Half of the joined [-][+] control.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final KeylineIconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 46,
    height: 48,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: KeylineIcon(icon, size: 20),
      style: IconButton.styleFrom(
        shape: const RoundedRectangleBorder(),
        padding: EdgeInsets.zero,
      ),
    ),
  );
}
