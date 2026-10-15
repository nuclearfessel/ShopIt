import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/data/database.dart';
import 'package:shop_it/data/totals.dart';

final _t = DateTime(2026, 1, 1);

ShoppingItem _item(double? price,
        {double qty = 1, bool taxable = false, bool checked = false}) =>
    ShoppingItem(
        id: '${price}_$qty$taxable$checked',
        updatedAt: _t,
        listId: 'l',
        name: 'x',
        quantity: qty,
        unit: '',
        checked: checked,
        category: '',
        price: price,
        note: '',
        taxable: taxable,
        hasCoupon: false);

void main() {
  test('no prices means no totals', () {
    expect(computeTotals([_item(null)], 8).hasPrices, isFalse);
    expect(computeTotals(const [], 8).hasPrices, isFalse);
  });

  test('tax applies only to taxable items, at the list rate', () {
    final t = computeTotals([
      _item(10, taxable: true), // taxed
      _item(5, qty: 2), // not taxable: 10.00
    ], 8.25);
    expect(t.subtotal, 20.0);
    expect(t.tax, 0.83); // 10 * 8.25% = 0.825 -> 0.83
    expect(t.total, 20.83);
  });

  test('no rate (or 0%) means no tax, even for taxable items', () {
    expect(computeTotals([_item(10, taxable: true)], null).tax, 0);
    expect(computeTotals([_item(10, taxable: true)], 0).tax, 0);
  });

  test('"still to buy" excludes checked items and includes their tax share',
      () {
    final t = computeTotals([
      _item(10, taxable: true, checked: true),
      _item(20, taxable: true),
    ], 10);
    expect(t.subtotal, 30);
    expect(t.tax, 3);
    expect(t.remaining, 22); // 20 + 10% of 20
  });
}
