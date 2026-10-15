import 'database.dart';

/// Money totals for a shopping list.
class ListTotals {
  const ListTotals({
    required this.subtotal,
    required this.tax,
    required this.remaining,
    required this.hasPrices,
  });

  /// Sum of price * quantity over every priced item.
  final double subtotal;

  /// Tax on the items flagged "has sales tax", at the list's rate.
  final double tax;

  /// Subtotal plus tax for items not yet checked off.
  final double remaining;

  final bool hasPrices;

  double get total => subtotal + tax;
}

double _round2(double v) => (v * 100).round() / 100;

/// Computes totals for [items]. [taxPercent] is the list's tax rate, e.g. 8.25;
/// pass 0 (or null) for no tax. Only items flagged taxable are taxed.
ListTotals computeTotals(List<ShoppingItem> items, double? taxPercent) {
  final rate = (taxPercent ?? 0) / 100;
  final priced = items.where((i) => i.price != null).toList();
  double line(ShoppingItem i) => i.price! * i.quantity;
  double taxOn(Iterable<ShoppingItem> r) =>
      _round2(r.where((i) => i.taxable).fold(0.0, (a, i) => a + line(i)) * rate);
  double sum(Iterable<ShoppingItem> r) => r.fold(0.0, (a, i) => a + line(i));

  final open = priced.where((i) => !i.checked).toList();
  return ListTotals(
    subtotal: _round2(sum(priced)),
    tax: taxOn(priced),
    remaining: _round2(sum(open) + taxOn(open)),
    hasPrices: priced.isNotEmpty,
  );
}
