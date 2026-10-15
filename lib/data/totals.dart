import 'database.dart';
import 'tax_rules.dart';

/// Money totals for a shopping list.
class ListTotals {
  const ListTotals({
    required this.subtotal,
    required this.tax,
    required this.remaining,
    required this.cartTotal,
    required this.hasPrices,
    required this.anyTaxed,
  });

  /// Sum of price * quantity over every priced item.
  final double subtotal;

  /// Tax on the items the rules say are taxed.
  final double tax;

  /// Subtotal plus tax for items not yet checked off.
  final double remaining;

  /// Subtotal plus tax for the checked-off items (what is in the cart).
  final double cartTotal;

  final bool hasPrices;

  /// At least one priced item is taxed (false when tax would be 0 because of
  /// the rules rather than the rate).
  final bool anyTaxed;

  double get total => subtotal + tax;
}

double _round2(double v) => (v * 100).round() / 100;

/// Computes totals for [items]. [tax] holds the list's rate and rules; pass
/// null for no tax. Each item is taxed at the rate its rules give it, or the
/// full rate if the user ticked "has sales tax" by hand.
ListTotals computeTotals(List<ShoppingItem> items, TaxContext? tax) {
  final priced = items.where((i) => i.price != null).toList();
  double line(ShoppingItem i) => i.price! * i.quantity;
  double taxOn(Iterable<ShoppingItem> r) {
    if (tax == null) return 0;
    final raw = r.fold(0.0, (a, i) => a + line(i) * tax.rateFor(i) / 100);
    return _round2(raw);
  }

  double sum(Iterable<ShoppingItem> r) => r.fold(0.0, (a, i) => a + line(i));

  final open = priced.where((i) => !i.checked).toList();
  final cart = priced.where((i) => i.checked).toList();
  return ListTotals(
    subtotal: _round2(sum(priced)),
    tax: taxOn(priced),
    remaining: _round2(sum(open) + taxOn(open)),
    cartTotal: _round2(sum(cart) + taxOn(cart)),
    hasPrices: priced.isNotEmpty,
    anyTaxed: tax != null && priced.any(tax.isTaxed),
  );
}
