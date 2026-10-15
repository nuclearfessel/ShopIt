/// One item read from a shopping-list CSV file.
class ShoppingCsvRow {
  const ShoppingCsvRow({
    required this.name,
    this.quantity = 1,
    this.unit = '',
    this.category = '',
    this.price,
    this.note = '',
    this.coupon = false,
    this.checked = false,
  });

  final String name;
  final double quantity;
  final String unit;
  final String category;
  final double? price;
  final String note;
  final bool coupon;
  final bool checked;
}

/// One item read from a pantry-list CSV file.
class PantryCsvRow {
  const PantryCsvRow({
    required this.name,
    this.quantity = 1,
    this.unit = '',
    this.category = '',
    this.location = '',
    this.expiry,
    this.note = '',
    this.mode = 'level',
    this.level = 'full',
  });

  final String name;
  final double quantity;
  final String unit;
  final String category;
  final String location;
  final DateTime? expiry;
  final String note;

  /// 'level' (Low/Full) or 'number'.
  final String mode;

  /// 'low' or 'full'.
  final String level;
}
