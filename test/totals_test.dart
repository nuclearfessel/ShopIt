import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/data/database.dart';
import 'package:shop_it/data/tax_rules.dart';
import 'package:shop_it/data/totals.dart';

final _t = DateTime(2026, 1, 1);

ShoppingItem _item(
  double? price, {
  String name = 'x',
  String category = '',
  double qty = 1,
  bool checked = false,
  bool manual = false,
  bool taxable = false,
}) => ShoppingItem(
  id: '$name$price$qty$checked$manual$taxable',
  updatedAt: _t,
  listId: 'l',
  name: name,
  quantity: qty,
  unit: '',
  checked: checked,
  category: category,
  price: price,
  note: '',
  taxable: taxable,
  hasCoupon: false,
  taxManual: manual,
);

TaxContext _ctx(String ruleId, double percent, {double? grocery}) => TaxContext(
  rules: TaxRuleSet.fromId(ruleId),
  percent: percent,
  groceryPercent: grocery,
);

void main() {
  test('no prices means no totals', () {
    expect(
      computeTotals([_item(null)], _ctx('everything', 8)).hasPrices,
      false,
    );
    expect(computeTotals(const [], null).hasPrices, isFalse);
  });

  test('no tax context means no tax', () {
    final t = computeTotals([_item(10)], null);
    expect((t.subtotal, t.tax, t.total), (10.0, 0.0, 10.0));
  });

  test('"everything" rules tax every item at the full rate', () {
    final t = computeTotals([
      _item(10, name: 'Milk', category: 'Dairy & Eggs'),
      _item(5, qty: 2, name: 'Soap', category: 'Personal Care'),
    ], _ctx('everything', 10));
    expect(t.subtotal, 20.0);
    expect(t.tax, 2.0);
  });

  test('Washington: groceries exempt, soda/water/alcohol/vitamins taxed', () {
    final seattle = _ctx('US-WA', 10.25);
    final t = computeTotals([
      _item(10, name: 'Milk', category: 'Dairy & Eggs'), // exempt
      _item(5, name: 'Bread', category: 'Bakery'), // exempt
      _item(2, name: 'Cola', category: 'Beverages'), // taxed
      _item(3, name: 'Bottled water', category: 'Beverages'), // taxed
      _item(8, name: 'Red wine', category: 'Alcohol'), // taxed
      _item(9, name: 'Vitamin D', category: 'Health & Pharmacy'), // taxed
      _item(4, name: 'Chocolate bars', category: 'Snacks'), // candy exempt
    ], seattle);
    expect(t.subtotal, 41.0);
    // taxed lines: 2 + 3 + 8 + 9 = 22 * 10.25% = 2.255 -> 2.26
    expect(t.tax, 2.26);
    expect(t.anyTaxed, isTrue);
  });

  test('Washington taxes juice only when it is not mostly juice', () {
    final seattle = _ctx('US-WA', 10);
    // Orange juice is food (exempt); lemonade is a soft drink (taxed).
    final t = computeTotals([
      _item(10, name: 'Orange juice', category: 'Beverages'),
      _item(10, name: 'Lemonade', category: 'Beverages'),
    ], seattle);
    expect(t.tax, 1.0);
  });

  test('a manual override beats the rules, both ways', () {
    final seattle = _ctx('US-WA', 10);
    final t = computeTotals([
      _item(
        10,
        name: 'Milk',
        category: 'Dairy & Eggs',
        manual: true,
        taxable: true,
      ),
      _item(
        10,
        name: 'Cola',
        category: 'Beverages',
        manual: true,
        taxable: false,
      ),
    ], seattle);
    expect(t.tax, 1.0); // only the milk, taxed by hand
  });

  test('a grocery rate applies to groceries in a state that exempts them', () {
    // e.g. a Georgia county with a 3% local grocery tax on a 7% total rate.
    final ctx = _ctx('US-GA', 7, grocery: 3);
    final t = computeTotals([
      _item(100, name: 'Milk', category: 'Dairy & Eggs'),
      _item(100, name: 'Paper towels', category: 'Paper & Wrap'),
    ], ctx);
    expect(t.tax, 10.0); // 3 on groceries + 7 on paper towels
  });

  test('reduced-grocery states tax groceries only at the grocery rate', () {
    final tn = _ctx('US-TN', 9.75, grocery: 4);
    expect(
      computeTotals([
        _item(50, name: 'Eggs', category: 'Dairy & Eggs'),
      ], tn).tax,
      2.0,
    );
    // Without a grocery rate entered, groceries are untaxed.
    expect(
      computeTotals([
        _item(50, name: 'Eggs', category: 'Dairy & Eggs'),
      ], _ctx('US-TN', 9.75)).tax,
      0.0,
    );
  });

  test('cart total covers only checked items, tax included', () {
    final ctx = _ctx('everything', 10);
    final t = computeTotals([
      _item(10, checked: true), // in the cart: 11.00 with tax
      _item(20), // still to buy
    ], ctx);
    expect(t.cartTotal, 11.0);
    expect(t.total, 33.0);
    expect(t.remaining, 22.0);
    expect(computeTotals([_item(20)], ctx).cartTotal, 0.0);
  });

  test(
    '"still to buy" excludes checked items and includes their tax share',
    () {
      final ctx = _ctx('everything', 10);
      final t = computeTotals([_item(10, checked: true), _item(20)], ctx);
      expect(t.subtotal, 30);
      expect(t.tax, 3);
      expect(t.remaining, 22);
    },
  );
}
