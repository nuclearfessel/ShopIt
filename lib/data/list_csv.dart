import 'csv.dart';
import 'database.dart';
import 'import_rows.dart';

// ---- Writing ---------------------------------------------------------------

String _num(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// A shopping list as CSV: one row per item, with a header row.
String shoppingItemsToCsv(List<ShoppingItem> items) => encodeCsv([
  [
    'Name',
    'Quantity',
    'Unit',
    'Category',
    'Price',
    'Notes',
    'Coupon',
    'Checked',
  ],
  for (final i in items)
    [
      i.name,
      _num(i.quantity),
      i.unit,
      i.category,
      i.price == null ? '' : i.price!.toStringAsFixed(2),
      i.note,
      i.hasCoupon ? 'yes' : 'no',
      i.checked ? 'yes' : 'no',
    ],
]);

/// A pantry list as CSV: one row per item, with a header row.
String pantryItemsToCsv(List<PantryItem> items) => encodeCsv([
  [
    'Name',
    'Quantity',
    'Unit',
    'Category',
    'Location',
    'Expiry',
    'Notes',
    'Amount',
    'Level',
  ],
  for (final i in items)
    [
      i.name,
      _num(i.quantity),
      i.unit,
      i.category,
      i.location,
      i.expiryDate == null ? '' : _date(i.expiryDate!),
      i.note,
      i.quantityMode == 'level' ? 'Low/Full' : 'Number',
      i.level == 'low' ? 'Low' : 'Full',
    ],
]);

/// A file name that is safe on Windows and Android.
String safeFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_').trim();
  return cleaned.isEmpty ? 'list' : cleaned;
}

// ---- Reading ---------------------------------------------------------------

/// Matches a header cell to the field it names, ignoring case and punctuation.
const _aliases = <String, Set<String>>{
  'name': {'name', 'item', 'itemname', 'title', 'product', 'description'},
  'quantity': {'quantity', 'qty', 'count'},
  'unit': {'unit', 'units', 'uom'},
  'category': {'category', 'aisle', 'section', 'department'},
  'price': {'price', 'unitprice', 'cost'},
  'note': {'note', 'notes', 'comment', 'comments'},
  'coupon': {'coupon', 'hascoupon'},
  'checked': {'checked', 'incart', 'done', 'purchased', 'bought'},
  'location': {'location', 'place', 'shelf', 'storage'},
  'expiry': {'expiry', 'expirydate', 'expires', 'bestby', 'useby'},
  'amount': {'amount', 'amounttype', 'mode', 'quantitytype'},
  'level': {'level', 'status', 'stock'},
};

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

/// Column index for each recognised field in [header].
Map<String, int> _columns(List<String> header) {
  final cols = <String, int>{};
  for (var i = 0; i < header.length; i++) {
    final n = _norm(header[i]);
    for (final e in _aliases.entries) {
      if (e.value.contains(n) && !cols.containsKey(e.key)) cols[e.key] = i;
    }
  }
  return cols;
}

/// Splits CSV into (columns, data rows). Without a recognisable header row,
/// every row is data and the first column is the item name.
(Map<String, int>, List<List<String>>) _table(String text) {
  final rows = decodeCsv(text);
  if (rows.isEmpty) return (const {}, const []);
  final cols = _columns(rows.first);
  if (cols.containsKey('name')) return (cols, rows.skip(1).toList());
  return (const {'name': 0}, rows);
}

String _cell(List<String> row, Map<String, int> cols, String field) {
  final i = cols[field];
  return (i == null || i >= row.length) ? '' : row[i].trim();
}

double? _parseNumber(String s) {
  if (s.isEmpty) return null;
  // "1,5" and "$3.50" both work; thousands separators are rare in item lists.
  final cleaned = s.replaceAll(RegExp(r'[^0-9.,\-]'), '').replaceAll(',', '.');
  return double.tryParse(cleaned);
}

bool _yes(String s) => const {
  'yes',
  'y',
  'true',
  '1',
  'x',
  'checked',
  'done',
}.contains(s.toLowerCase());

DateTime? _parseDate(String s) {
  if (s.isEmpty) return null;
  final iso = DateTime.tryParse(s);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);
  // month/day/year, as typed in a US spreadsheet
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})$').firstMatch(s);
  if (m == null) return null;
  var y = int.parse(m.group(3)!);
  if (y < 100) y += 2000;
  final month = int.parse(m.group(1)!);
  final day = int.parse(m.group(2)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(y, month, day);
}

/// Items from a shopping-list CSV. Rows without a name are skipped.
List<ShoppingCsvRow> parseShoppingCsv(String text) {
  final (cols, rows) = _table(text);
  return [
    for (final r in rows)
      if (_cell(r, cols, 'name').isNotEmpty)
        ShoppingCsvRow(
          name: _cell(r, cols, 'name'),
          quantity: _parseNumber(_cell(r, cols, 'quantity')) ?? 1,
          unit: _cell(r, cols, 'unit'),
          category: _cell(r, cols, 'category'),
          price: _parseNumber(_cell(r, cols, 'price')),
          note: _cell(r, cols, 'note'),
          coupon: _yes(_cell(r, cols, 'coupon')),
          checked: _yes(_cell(r, cols, 'checked')),
        ),
  ];
}

/// Items from a pantry-list CSV. Rows without a name are skipped. A file with a
/// quantity but no "Amount" column keeps showing the quantity.
List<PantryCsvRow> parsePantryCsv(String text) {
  final (cols, rows) = _table(text);
  return [
    for (final r in rows)
      if (_cell(r, cols, 'name').isNotEmpty)
        () {
          final amount = _cell(r, cols, 'amount').toLowerCase();
          final hasQuantity = _cell(r, cols, 'quantity').isNotEmpty;
          final mode = amount.contains('number')
              ? 'number'
              : amount.isNotEmpty
              ? 'level'
              : (hasQuantity ? 'number' : 'level');
          return PantryCsvRow(
            name: _cell(r, cols, 'name'),
            quantity: _parseNumber(_cell(r, cols, 'quantity')) ?? 1,
            unit: _cell(r, cols, 'unit'),
            category: _cell(r, cols, 'category'),
            location: _cell(r, cols, 'location'),
            expiry: _parseDate(_cell(r, cols, 'expiry')),
            note: _cell(r, cols, 'note'),
            mode: mode,
            level: _cell(r, cols, 'level').toLowerCase() == 'low'
                ? 'low'
                : 'full',
          );
        }(),
  ];
}
