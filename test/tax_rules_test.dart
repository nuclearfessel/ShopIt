import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/data/tax_rules.dart';

TaxClass _c(String name, String category) => classifyItem(name, category);

/// Percent charged on [name] under a state's rules at a 10% full rate.
double _rate(String state, String name, String category, {double? grocery}) =>
    TaxRuleSet.fromId('US-$state').rateFor(_c(name, category), 10, grocery);

void main() {
  group('classification', () {
    test(
      'Washington list: prepared food, soda, water, alcohol, supplements, ice',
      () {
        expect(_c('Rotisserie chicken', 'Deli'), TaxClass.preparedFood);
        expect(_c('Prepared salad', 'Deli'), TaxClass.preparedFood);
        expect(_c('Cola', 'Beverages'), TaxClass.softDrink);
        expect(_c('Energy drinks', 'Beverages'), TaxClass.softDrink);
        expect(_c('Bottled water', 'Beverages'), TaxClass.bottledWater);
        expect(_c('Sparkling water', 'Beverages'), TaxClass.bottledWater);
        expect(_c('Red wine', 'Alcohol'), TaxClass.alcohol);
        expect(_c('Vodka', 'Alcohol'), TaxClass.alcohol);
        expect(_c('Multivitamins', 'Health & Pharmacy'), TaxClass.supplement);
        expect(_c('Ice cubes', 'Frozen'), TaxClass.ice);
      },
    );

    test('things that are food stay food', () {
      expect(_c('Milk', 'Dairy & Eggs'), TaxClass.food);
      expect(_c('Orange juice', 'Beverages'), TaxClass.food); // >50% juice
      expect(_c('Smoothies', 'Beverages'), TaxClass.food);
      expect(_c('Oat milk', 'Dairy & Eggs'), TaxClass.food);
      expect(_c('Baby formula', 'Baby'), TaxClass.food);
      expect(_c('Deli ham', 'Deli'), TaxClass.food);
      expect(_c('Hummus', 'Deli'), TaxClass.food);
    });

    test('candy, medicine and non-food', () {
      expect(_c('Chocolate bars', 'Snacks'), TaxClass.candy);
      expect(_c('Gummy bears', 'Snacks'), TaxClass.candy);
      expect(_c('Ibuprofen', 'Health & Pharmacy'), TaxClass.otcMedicine);
      expect(_c('Shampoo', 'Personal Care'), TaxClass.nonFood);
      expect(_c('Diapers', 'Baby'), TaxClass.nonFood);
    });

    test('unknown items fall back on their category', () {
      expect(_c('Kombucha', 'Beverages'), TaxClass.softDrink);
      expect(_c('Kimchi', 'Other'), TaxClass.food);
      expect(_c('Kimchi', ''), TaxClass.food);
      expect(_c('Mystery', 'Household & Cleaning'), TaxClass.nonFood);
    });
  });

  group('Washington rules (RCW 82.08.0293)', () {
    test('taxes exactly what the user listed, exempts groceries and candy', () {
      for (final taxed in [
        ['Rotisserie chicken', 'Deli'],
        ['Cola', 'Beverages'],
        ['Lemonade', 'Beverages'],
        ['Bottled water', 'Beverages'],
        ['Beer', 'Alcohol'],
        ['Vitamin C', 'Health & Pharmacy'],
        ['Ice cubes', 'Frozen'],
        ['Paper towels', 'Paper & Wrap'],
      ]) {
        expect(_rate('WA', taxed[0], taxed[1]), 10, reason: taxed[0]);
      }
      for (final exempt in [
        ['Milk', 'Dairy & Eggs'],
        ['Apples', 'Produce'],
        ['Bread', 'Bakery'],
        ['Orange juice', 'Beverages'],
        ['Oat milk', 'Dairy & Eggs'],
        ['Chocolate bars', 'Snacks'],
        ['Frozen pizza', 'Frozen'],
      ]) {
        expect(_rate('WA', exempt[0], exempt[1]), 0, reason: exempt[0]);
      }
    });
  });

  group('all states', () {
    test('every state and DC has a rule set', () {
      expect(taxStates.length, 51);
      expect(taxStates.map((s) => s.code).toSet().length, 51);
      for (final s in taxStates) {
        final r = TaxRuleSet.fromId('US-${s.code}');
        expect(r.id, 'US-${s.code}');
        expect(r.title, s.name);
        expect(r.description, isNotEmpty);
      }
    });

    test('unknown ids fall back to taxing everything', () {
      expect(TaxRuleSet.fromId(null).id, 'everything');
      expect(TaxRuleSet.fromId('US-ZZ').id, 'everything');
    });

    test('state names map to rules', () {
      expect(TaxRuleSet.forStateName('Washington')?.id, 'US-WA');
      expect(TaxRuleSet.forStateName(' texas ')?.id, 'US-TX');
      expect(TaxRuleSet.forStateName('Atlantis'), isNull);
      expect(TaxRuleSet.forStateName(null), isNull);
    });

    test('grocery-exempt states do not tax milk; fully-taxing states do', () {
      for (final st in ['CA', 'TX', 'NY', 'FL', 'WA', 'PA', 'OH']) {
        expect(_rate(st, 'Milk', 'Dairy & Eggs'), 0, reason: st);
      }
      for (final st in ['HI', 'ID', 'SD']) {
        expect(_rate(st, 'Milk', 'Dairy & Eggs'), 10, reason: st);
      }
    });

    test('no-state-tax states tax everything at the entered local rate', () {
      for (final st in ['AK', 'DE', 'MT', 'NH', 'OR']) {
        expect(_rate(st, 'Milk', 'Dairy & Eggs'), 10, reason: st);
      }
    });

    test('states where candy and soda are taxed despite a food exemption', () {
      for (final st in ['CO', 'NJ', 'MN', 'KY', 'MD', 'FL']) {
        expect(_rate(st, 'Milk', 'Dairy & Eggs'), 0, reason: '$st milk');
        expect(_rate(st, 'Cola', 'Beverages'), 10, reason: '$st soda');
        expect(_rate(st, 'Chocolate bars', 'Snacks'), 10, reason: '$st candy');
      }
    });

    test('reduced-grocery states ask for a grocery rate', () {
      for (final st in ['AL', 'IL', 'MS', 'MO', 'TN', 'UT', 'VA']) {
        expect(
          TaxRuleSet.fromId('US-$st').groceryRateNeeded,
          isTrue,
          reason: st,
        );
      }
      expect(TaxRuleSet.fromId('US-WA').groceryRateNeeded, isFalse);
    });

    test('supplements: taxed in WA/CA/CO, exempt as food in NY', () {
      expect(_rate('WA', 'Vitamin D', 'Health & Pharmacy'), 10);
      expect(_rate('CA', 'Vitamin D', 'Health & Pharmacy'), 10);
      expect(_rate('NY', 'Vitamin D', 'Health & Pharmacy'), 0);
    });

    test('bottled water is taxed in WA, NY and LA only', () {
      for (final st in ['WA', 'NY', 'LA']) {
        expect(_rate(st, 'Bottled water', 'Beverages'), 10, reason: st);
      }
      expect(_rate('TX', 'Bottled water', 'Beverages'), 0);
    });
  });
}
