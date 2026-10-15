import 'database.dart';

/// What kind of thing an item is, for deciding whether and how it is taxed.
enum TaxClass {
  food('groceries'),
  preparedFood('prepared food'),
  candy('candy'),
  softDrink('soft drinks'),
  bottledWater('bottled water'),
  alcohol('alcohol'),
  supplement('dietary supplements'),
  otcMedicine('non-prescription medicine'),
  ice('bulk ice'),
  nonFood('non-food items');

  const TaxClass(this.label);
  final String label;
}

/// How a rule set treats one [TaxClass].
enum ClassTax {
  /// Never taxed.
  exempt,

  /// Taxed at the grocery rate: nothing, the tax rate's own grocery rate, or
  /// the full rate in the few states that tax groceries fully.
  likeFood,

  /// Taxed at the full rate.
  full,
}

/// Tax rules for one place: which kinds of items are taxed. Tax rules differ by
/// state, so a rule set is chosen per tax rate.
class TaxRuleSet {
  const TaxRuleSet({
    required this.id,
    required this.title,
    required this.treatment,
    this.foodTaxedFully = false,
    this.groceryRateNeeded = false,
    this.note = '',
  });

  /// Stored on the tax rate: "everything" or "US-WA".
  final String id;
  final String title;
  final Map<TaxClass, ClassTax> treatment;

  /// Groceries are taxed at the full rate (HI, ID, SD, or "everything").
  final bool foodTaxedFully;

  /// The state taxes groceries at a reduced or local-only rate that varies by
  /// place, so the user should enter their grocery rate.
  final bool groceryRateNeeded;

  /// Extra caution or detail to show the user.
  final String note;

  /// What the grocery rate is when the tax rate has no grocery rate of its own.
  double foodRate(double percent, double? groceryPercent) =>
      groceryPercent ?? (foodTaxedFully ? percent : 0);

  /// The percent that applies to an item of class [c].
  double rateFor(TaxClass c, double percent, double? groceryPercent) =>
      switch (treatment[c] ?? ClassTax.full) {
        ClassTax.exempt => 0,
        ClassTax.likeFood => foodRate(percent, groceryPercent),
        ClassTax.full => percent,
      };

  /// Plain-language summary of what is taxed.
  String get description {
    final taxed = [
      for (final c in TaxClass.values)
        if (treatment[c] == ClassTax.full) c.label,
    ];
    final food = foodTaxedFully
        ? 'Groceries are taxed.'
        : 'Groceries are exempt.';
    final likeFood = [
      for (final c in TaxClass.values)
        if (c != TaxClass.food && treatment[c] == ClassTax.likeFood) c.label,
    ];
    return [
      food,
      if (likeFood.isNotEmpty)
        '${_cap(likeFood.join(', '))} follow the grocery rule.',
      if (taxed.isNotEmpty) 'Always taxed: ${taxed.join(', ')}.',
    ].join(' ');
  }

  static final TaxRuleSet everything = TaxRuleSet(
    id: 'everything',
    title: 'Everything is taxed',
    foodTaxedFully: true,
    treatment: {for (final c in TaxClass.values) c: ClassTax.full},
  );

  /// Every rule set: "everything" followed by the states, in name order.
  static final List<TaxRuleSet> all = [
    everything,
    for (final s in _states) s.build(),
  ];

  static TaxRuleSet fromId(String? id) =>
      all.firstWhere((r) => r.id == id, orElse: () => everything);

  /// The rule set for a US state name ("Washington"), or null.
  static TaxRuleSet? forStateName(String? name) {
    if (name == null) return null;
    final n = name.trim().toLowerCase();
    for (final s in _states) {
      if (s.name.toLowerCase() == n) return s.build();
    }
    return null;
  }
}

String _cap(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

// ---- State data ----------------------------------------------------------
//
// Sources: Washington follows RCW 82.08.0293 and the Department of Revenue's
// food guides. Other states use the Tax Foundation's "Sales Taxes on Soda,
// Candy, and Other Groceries" table (state rules as of 1 Jan 2018) updated for
// grocery-tax changes reported for 2024-2026, plus state notes found in tax
// vendor and revenue-department material. Published sources disagree on some
// states, and rules change often, so treat everything except Washington as an
// approximation. Local (city/county) taxes are not modelled: where a locality
// taxes groceries, enter that as the tax rate's grocery rate.

enum _Food { exempt, reduced, full }

class _State {
  const _State(
    this.code,
    this.name,
    this.food, {
    this.candyLikeFood = true,
    this.sodaLikeFood = true,
    this.waterTaxed = false,
    this.supplementTaxed = false,
    this.iceTaxed = false,
    this.noStateTax = false,
    this.note = '',
  });

  final String code;
  final String name;
  final _Food food;

  /// Candy / soda are taxed the same way as groceries (false: taxed in full).
  final bool candyLikeFood;
  final bool sodaLikeFood;
  final bool waterTaxed;
  final bool supplementTaxed;
  final bool iceTaxed;

  /// No state sales tax (a local rate may still apply).
  final bool noStateTax;
  final String note;

  TaxRuleSet build() {
    if (noStateTax) {
      return TaxRuleSet(
        id: 'US-$code',
        title: name,
        foodTaxedFully: true,
        treatment: {for (final c in TaxClass.values) c: ClassTax.full},
        note:
            '$name has no statewide sales tax. Enter any local rate and '
                    'every item is taxed at it. $note'
                .trim(),
      );
    }
    ClassTax like(bool follows) => follows ? ClassTax.likeFood : ClassTax.full;
    return TaxRuleSet(
      id: 'US-$code',
      title: name,
      foodTaxedFully: food == _Food.full,
      groceryRateNeeded: food == _Food.reduced,
      treatment: {
        TaxClass.food: ClassTax.likeFood,
        TaxClass.preparedFood: ClassTax.full,
        TaxClass.candy: like(candyLikeFood),
        TaxClass.softDrink: like(sodaLikeFood),
        TaxClass.bottledWater: waterTaxed ? ClassTax.full : ClassTax.likeFood,
        TaxClass.alcohol: ClassTax.full,
        TaxClass.supplement: supplementTaxed
            ? ClassTax.full
            : ClassTax.likeFood,
        TaxClass.otcMedicine: ClassTax.full,
        TaxClass.ice: iceTaxed ? ClassTax.full : ClassTax.likeFood,
        TaxClass.nonFood: ClassTax.full,
      },
      note: [
        if (food == _Food.reduced)
          '$name taxes groceries at a reduced and/or local rate. Enter the '
              'grocery rate for your area.',
        note,
      ].where((s) => s.isNotEmpty).join(' '),
    );
  }
}

const _states = <_State>[
  _State(
    'AL',
    'Alabama',
    _Food.reduced,
    note: 'State food rate was cut to 2% in Sept 2025; local food taxes apply.',
  ),
  _State('AK', 'Alaska', _Food.full, noStateTax: true),
  _State('AZ', 'Arizona', _Food.exempt),
  _State(
    'AR',
    'Arkansas',
    _Food.exempt,
    candyLikeFood: false,
    sodaLikeFood: false,
    note:
        'The state grocery tax was reported repealed from Jan 2026; local '
        'taxes may remain.',
  ),
  _State(
    'CA',
    'California',
    _Food.exempt,
    sodaLikeFood: false,
    supplementTaxed: true,
    note: 'Carbonated bottled water is taxed; plain bottled water is not.',
  ),
  _State(
    'CO',
    'Colorado',
    _Food.exempt,
    candyLikeFood: false,
    sodaLikeFood: false,
    supplementTaxed: true,
    note: 'Some cities and counties tax groceries.',
  ),
  _State(
    'CT',
    'Connecticut',
    _Food.exempt,
    candyLikeFood: false,
    sodaLikeFood: false,
  ),
  _State('DE', 'Delaware', _Food.full, noStateTax: true),
  _State(
    'DC',
    'District of Columbia',
    _Food.exempt,
    candyLikeFood: false,
    sodaLikeFood: false,
  ),
  _State(
    'FL',
    'Florida',
    _Food.exempt,
    candyLikeFood: false,
    sodaLikeFood: false,
  ),
  _State(
    'GA',
    'Georgia',
    _Food.exempt,
    note: 'Many counties and cities add a local tax on groceries.',
  ),
  _State(
    'HI',
    'Hawaii',
    _Food.full,
    note: 'Hawaii has a general excise tax, which applies to groceries.',
  ),
  _State(
    'ID',
    'Idaho',
    _Food.full,
    note: 'Idaho offers a grocery credit on the income tax return.',
  ),
  _State(
    'IL',
    'Illinois',
    _Food.reduced,
    candyLikeFood: false,
    sodaLikeFood: false,
    note:
        'The 1% state grocery tax was reported ended in Jan 2026, but '
        'localities may keep a 1% grocery tax. Candy, soda and alcohol never '
        'qualified for the low rate.',
  ),
  _State(
    'IN',
    'Indiana',
    _Food.exempt,
    candyLikeFood: false,
    sodaLikeFood: false,
  ),
  _State('IA', 'Iowa', _Food.exempt, candyLikeFood: false, sodaLikeFood: false),
  _State(
    'KS',
    'Kansas',
    _Food.exempt,
    note: 'The state grocery tax ended Jan 2025; local taxes may still apply.',
  ),
  _State(
    'KY',
    'Kentucky',
    _Food.exempt,
    candyLikeFood: false,
    sodaLikeFood: false,
    supplementTaxed: true,
  ),
  _State(
    'LA',
    'Louisiana',
    _Food.exempt,
    waterTaxed: true,
    note: 'Many parishes tax groceries locally. Bottled water is taxed.',
  ),
  _State(
    'ME',
    'Maine',
    _Food.exempt,
    candyLikeFood: false,
    sodaLikeFood: false,
  ),
  _State(
    'MD',
    'Maryland',
    _Food.exempt,
    candyLikeFood: false,
    sodaLikeFood: false,
  ),
  _State('MA', 'Massachusetts', _Food.exempt),
  _State(
    'MI',
    'Michigan',
    _Food.exempt,
    note: 'Sources conflict on candy and soft drinks in Michigan.',
  ),
  _State(
    'MN',
    'Minnesota',
    _Food.exempt,
    candyLikeFood: false,
    sodaLikeFood: false,
    supplementTaxed: true,
  ),
  _State(
    'MS',
    'Mississippi',
    _Food.reduced,
    note:
        'The state grocery rate was reported cut from 7% to 5% in 2025; '
        'local grocery taxes may apply.',
  ),
  _State(
    'MO',
    'Missouri',
    _Food.reduced,
    note: 'The state grocery rate is 1.225% plus local taxes.',
  ),
  _State('MT', 'Montana', _Food.full, noStateTax: true),
  _State('NE', 'Nebraska', _Food.exempt),
  _State('NV', 'Nevada', _Food.exempt),
  _State('NH', 'New Hampshire', _Food.full, noStateTax: true),
  _State(
    'NJ',
    'New Jersey',
    _Food.exempt,
    candyLikeFood: false,
    sodaLikeFood: false,
  ),
  _State('NM', 'New Mexico', _Food.exempt),
  _State(
    'NY',
    'New York',
    _Food.exempt,
    candyLikeFood: false,
    sodaLikeFood: false,
    waterTaxed: true,
    note: 'Bottled water is taxed. Some counties tax groceries locally.',
  ),
  _State(
    'NC',
    'North Carolina',
    _Food.exempt,
    candyLikeFood: false,
    sodaLikeFood: false,
  ),
  _State(
    'ND',
    'North Dakota',
    _Food.exempt,
    candyLikeFood: false,
    sodaLikeFood: false,
    supplementTaxed: true,
  ),
  _State('OH', 'Ohio', _Food.exempt, sodaLikeFood: false),
  _State(
    'OK',
    'Oklahoma',
    _Food.exempt,
    note:
        'The state grocery tax was reported ended; city and county taxes '
        'on groceries remain.',
  ),
  _State('OR', 'Oregon', _Food.full, noStateTax: true),
  _State(
    'PA',
    'Pennsylvania',
    _Food.exempt,
    candyLikeFood: false,
    sodaLikeFood: false,
    note:
        'Sources disagree on candy in Pennsylvania; it is treated as '
        'taxed here.',
  ),
  _State(
    'RI',
    'Rhode Island',
    _Food.exempt,
    candyLikeFood: false,
    sodaLikeFood: false,
    supplementTaxed: true,
  ),
  _State('SC', 'South Carolina', _Food.exempt),
  _State(
    'SD',
    'South Dakota',
    _Food.full,
    note: 'Sources disagree on whether a temporary reduced rate applies.',
  ),
  _State(
    'TN',
    'Tennessee',
    _Food.reduced,
    note: 'The state grocery rate is 4% plus local taxes.',
  ),
  _State(
    'TX',
    'Texas',
    _Food.exempt,
    candyLikeFood: false,
    sodaLikeFood: false,
  ),
  _State(
    'UT',
    'Utah',
    _Food.reduced,
    note: 'Sources disagree on the Utah grocery rate; check yours.',
  ),
  _State('VT', 'Vermont', _Food.exempt),
  _State(
    'VA',
    'Virginia',
    _Food.reduced,
    note: 'Virginia groceries are taxed at a reduced local/regional rate.',
  ),
  _State(
    'WA',
    'Washington',
    _Food.exempt,
    sodaLikeFood: false,
    waterTaxed: true,
    supplementTaxed: true,
    iceTaxed: true,
    note:
        'Washington rules (RCW 82.08.0293): groceries are exempt, but '
        'prepared food, soft drinks, bottled water, dietary supplements, '
        'alcohol and bulk ice are taxed. Candy is exempt.',
  ),
  _State('WV', 'West Virginia', _Food.exempt, sodaLikeFood: false),
  _State(
    'WI',
    'Wisconsin',
    _Food.exempt,
    candyLikeFood: false,
    sodaLikeFood: false,
  ),
  _State('WY', 'Wyoming', _Food.exempt),
];

/// All US states and DC that have rule sets, as (code, name).
List<({String code, String name})> get taxStates => [
  for (final s in _states) (code: s.code, name: s.name),
];

// ---- Classification ------------------------------------------------------

/// Default class for each store category. Items not named below fall back to
/// this; beverages we don't recognise are assumed to be sweetened soft drinks.
const Map<String, TaxClass> _categoryDefaults = {
  'Alcohol': TaxClass.alcohol,
  'Beverages': TaxClass.softDrink,
  'Baby': TaxClass.nonFood,
  'Pet': TaxClass.nonFood,
  'Household & Cleaning': TaxClass.nonFood,
  'Paper & Wrap': TaxClass.nonFood,
  'Personal Care': TaxClass.nonFood,
  'Health & Pharmacy': TaxClass.nonFood,
};

/// Items whose class differs from their category's default (lower-case names).
final Map<String, TaxClass> _nameOverrides = {
  // Prepared by the seller: hot or combined into one item.
  for (final n in [
    'rotisserie chicken',
    'cooked chicken',
    'prepared salad',
    'deli salads',
    'coleslaw',
    'potato salad',
    'pasta salad',
  ])
    n: TaxClass.preparedFood,

  for (final n in [
    'candy',
    'sweets',
    'chocolate',
    'chocolate bars',
    'chocolate buttons',
    'milk chocolate',
    'dark chocolate bar',
    'white chocolate',
    'gummy bears',
    'mints',
    'chewing gum',
    'lollipops',
    'jelly beans',
  ])
    n: TaxClass.candy,

  // Sweetened non-alcoholic drinks that are not milk-based and are not more
  // than 50% fruit or vegetable juice.
  for (final n in [
    'soft drinks',
    'cola',
    'diet cola',
    'lemonade',
    'lemon-lime soda',
    'ginger ale',
    'ginger beer',
    'root beer',
    'orange soda',
    'tonic water',
    'energy & sports',
    'energy drinks',
    'sports drinks',
    'mixers',
    'cocktail mixers',
  ])
    n: TaxClass.softDrink,

  for (final n in [
    'water',
    'bottled water',
    'sparkling water',
    'flavoured water',
    'soda water',
  ])
    n: TaxClass.bottledWater,

  // Drinks that count as food: juice, smoothies and concentrates.
  for (final n in [
    'juice',
    'orange juice',
    'apple juice',
    'cranberry juice',
    'grape juice',
    'pineapple juice',
    'tomato juice',
    'smoothies',
    'coconut water',
    'squash',
    'orange squash',
    'blackcurrant squash',
  ])
    n: TaxClass.food,

  for (final n in ['ice', 'ice cubes']) n: TaxClass.ice,

  for (final n in [
    'vitamins',
    'multivitamins',
    'vitamin c',
    'vitamin d',
    'fish oil',
  ])
    n: TaxClass.supplement,

  for (final n in [
    'pain relief',
    'paracetamol',
    'ibuprofen',
    'aspirin',
    'cold & allergy',
    'allergy tablets',
    'cough syrup',
    'nasal spray',
    'throat lozenges',
  ])
    n: TaxClass.otcMedicine,

  // Baby food and formula are food; diapers and wipes are not.
  for (final n in [
    'baby food',
    'baby cereal',
    'baby purees',
    'baby snacks',
    'formula',
    'baby formula',
    'follow-on milk',
  ])
    n: TaxClass.food,
};

/// Works out the [TaxClass] of an item from its [name] and store [category].
TaxClass classifyItem(String name, String category) =>
    _nameOverrides[name.trim().toLowerCase()] ??
    _categoryDefaults[category] ??
    TaxClass.food;

// ---- Applying rules ------------------------------------------------------

/// A tax rate together with its rules: everything needed to price tax.
class TaxContext {
  const TaxContext({
    required this.rules,
    required this.percent,
    this.groceryPercent,
  });

  factory TaxContext.fromRate(TaxRate rate) => TaxContext(
    rules: TaxRuleSet.fromId(rate.ruleSet),
    percent: rate.percent,
    groceryPercent: rate.groceryPercent,
  );

  final TaxRuleSet rules;

  /// The full rate, e.g. 10.25.
  final double percent;

  /// Rate for groceries where it differs from the full rate (or the state
  /// exempts them but the locality does not).
  final double? groceryPercent;

  /// The percent charged on [item]: the checkbox if the user set it by hand,
  /// otherwise what the rules say for that kind of item.
  double rateFor(ShoppingItem item) {
    final c = classifyItem(item.name, item.category);
    if (item.taxManual) {
      if (!item.taxable) return 0;
      return c == TaxClass.food
          ? rules.foodRate(percent, groceryPercent).clampMin(percent)
          : percent;
    }
    return rules.rateFor(c, percent, groceryPercent);
  }

  bool isTaxed(ShoppingItem item) => rateFor(item) > 0;

  /// The rate for a kind of item, ignoring any manual override.
  double rateForClass(TaxClass c) => rules.rateFor(c, percent, groceryPercent);
}

extension on double {
  /// A hand-ticked grocery item uses the full rate unless a lower grocery rate
  /// is set explicitly.
  double clampMin(double full) => this > 0 ? this : full;
}

/// One line saying why an item is or is not taxed, for the item editor.
String describeTax(
  String name,
  String category,
  TaxContext ctx, {
  required bool manual,
}) {
  final c = classifyItem(name, category);
  final taxed = ctx.rateForClass(c) > 0;
  final why =
      '${_cap(c.label)}: ${taxed ? 'taxed' : 'exempt'} under '
      '${ctx.rules.title == TaxRuleSet.everything.title ? 'this rate' : '${ctx.rules.title} rules'}';
  return manual ? 'Set by hand. $why.' : '$why.';
}
