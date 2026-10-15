import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  test('seeds a default list', () async {
    final lists = await db.watchLists().first;
    expect(lists.map((l) => l.name), ['Groceries']);
  });

  test('shopping items: add, check, sort, soft-delete, clear checked',
      () async {
    final list = (await db.watchLists().first).single;
    await db.addShoppingItem(list.id, 'Milk');
    await db.addShoppingItem(list.id, 'Apples');

    var items = await db.watchShoppingItems(list.id).first;
    expect(items.map((i) => i.name), ['Apples', 'Milk']);

    await db.setChecked(items.first.id, true);
    items = await db.watchShoppingItems(list.id).first;
    expect(items.map((i) => i.name), ['Milk', 'Apples']); // checked sinks

    await db.clearChecked(list.id);
    items = await db.watchShoppingItems(list.id).first;
    expect(items.map((i) => i.name), ['Milk']);

    await db.deleteShoppingItem(items.single.id);
    expect(await db.watchShoppingItems(list.id).first, isEmpty);
    // soft delete: the rows still exist for future sync
    expect(await db.select(db.shoppingItems).get(), hasLength(2));
  });

  test('deleting a list hides its items', () async {
    await db.addList('Party');
    final party =
        (await db.watchLists().first).firstWhere((l) => l.name == 'Party');
    await db.addShoppingItem(party.id, 'Chips');
    await db.deleteList(party.id);
    expect((await db.watchLists().first).map((l) => l.name), ['Groceries']);
    expect(await db.watchShoppingItems(party.id).first, isEmpty);
  });

  test('delete all lists empties shopping but keeps pantry, then can restart',
      () async {
    final list = (await db.watchLists().first).single;
    await db.addList('Party');
    await db.addShoppingItem(list.id, 'Milk', category: 'Dairy & Eggs');
    await db.addPantryItem('Rice');

    await db.deleteAllLists();
    expect(await db.watchLists().first, isEmpty);
    expect(await db.watchShoppingItems(list.id).first, isEmpty);
    expect(await db.watchPantry().first, hasLength(1));

    await db.addList('Fresh start');
    expect((await db.watchLists().first).map((l) => l.name), ['Fresh start']);
  });

  test('item details can be edited and cleared', () async {
    final list = (await db.watchLists().first).single;
    await db.addShoppingItem(list.id, 'Milk', category: 'Dairy & Eggs');
    final milk = (await db.watchShoppingItems(list.id).first).single;
    expect(milk.price, isNull);
    expect(milk.note, '');

    await db.updateShoppingItem(milk.id,
        name: 'Oat milk',
        quantity: 2,
        unit: 'cartons',
        category: 'Dairy & Eggs',
        price: 1.75,
        note: 'Barista edition');
    var m = (await db.watchShoppingItems(list.id).first).single;
    expect((m.name, m.quantity, m.unit, m.price, m.note),
        ('Oat milk', 2.0, 'cartons', 1.75, 'Barista edition'));

    await db.updateShoppingItem(m.id,
        name: m.name,
        quantity: m.quantity,
        unit: m.unit,
        category: m.category,
        price: null,
        note: '');
    m = (await db.watchShoppingItems(list.id).first).single;
    expect(m.price, isNull);

    await db.addPantryItem('Rice',
        expiryDate: DateTime(2030, 1, 1), location: 'Shelf');
    final rice = (await db.watchPantry().first).single;
    await db.updatePantryItem(rice.id,
        name: 'Basmati rice',
        quantity: 3,
        unit: 'kg',
        category: 'Pasta, Rice & Grains',
        location: 'Cupboard',
        expiryDate: null,
        note: 'Open bag on top');
    final r = (await db.watchPantry().first).single;
    expect((r.name, r.location, r.expiryDate, r.note),
        ('Basmati rice', 'Cupboard', null, 'Open bag on top'));
  });

  test('items can be moved and copied between lists, keeping their details',
      () async {
    final groceries = (await db.watchLists().first).single;
    await db.addList('Party');
    final party =
        (await db.watchLists().first).firstWhere((l) => l.name == 'Party');
    await db.addShoppingItem(groceries.id, 'Chips', category: 'Snacks');
    final chips = (await db.watchShoppingItems(groceries.id).first).single;
    await db.updateShoppingItem(chips.id,
        name: 'Chips',
        quantity: 3,
        unit: 'bag',
        category: 'Snacks',
        price: 2.5,
        note: 'Salted',
        taxable: true,
        hasCoupon: true);
    final edited = (await db.watchShoppingItems(groceries.id).first).single;
    expect((edited.taxable, edited.hasCoupon), (true, true));

    await db.copyShoppingItem(edited, party.id);
    var copy = (await db.watchShoppingItems(party.id).first).single;
    expect((copy.name, copy.quantity, copy.price, copy.hasCoupon),
        ('Chips', 3.0, 2.5, true));
    expect(copy.id, isNot(edited.id));
    expect(await db.watchShoppingItems(groceries.id).first, hasLength(1));

    await db.moveShoppingItem(edited.id, party.id);
    expect(await db.watchShoppingItems(groceries.id).first, isEmpty);
    expect(await db.watchShoppingItems(party.id).first, hasLength(2));
  });

  test('tax rates: user-defined, chosen per list, deleting resets lists', () async {
    final list = (await db.watchLists().first).single;
    expect(list.taxRateId, isNull);
    expect(await db.watchTaxRates().first, isEmpty); // none built in

    final id = await db.addTaxRate('Home', 8.25);
    await db.setListTaxRate(list.id, id);
    expect((await db.watchLists().first).single.taxRateId, id);

    await db.updateTaxRate(id, 'Home (county)', 8.5);
    final rate = (await db.watchTaxRates().first).single;
    expect((rate.name, rate.percent), ('Home (county)', 8.5));

    await db.deleteTaxRate(id);
    expect(await db.watchTaxRates().first, isEmpty);
    expect((await db.watchLists().first).single.taxRateId, isNull);
  });

  test('catalog is seeded with ordered categories', () async {
    final cats = await db.watchCategories().first;
    expect(cats.first.name, 'Produce');
    expect(cats.map((c) => c.name), contains('Dairy & Eggs'));
    final milk = await db.searchCatalog('milk');
    expect(milk.map((i) => i.name), contains('Milk'));
    expect(milk.firstWhere((i) => i.name == 'Milk').category, 'Dairy & Eggs');
  });

  test('catalog search ranks prefix matches first and ignores case', () async {
    final r = await db.searchCatalog('BUT');
    expect(r.first.name.toLowerCase().startsWith('but'), isTrue);
    expect(await db.searchCatalog('%'), isEmpty);
    expect(await db.searchCatalog('   '), isEmpty);
  });

  test('searching a group lists its types and cuts', () async {
    final onion = (await db.searchCatalog('onion')).map((i) => i.name).toList();
    expect(onion.first, 'Onions');
    expect(onion, containsAll(['Red onions', 'Shallots', 'Spring onions']));

    final bread = (await db.searchCatalog('bread')).map((i) => i.name);
    expect(bread, containsAll(['Bread', 'Sourdough', 'Baguette', 'Rye bread']));

    final beef = (await db.searchCatalog('beef')).map((i) => i.name);
    expect(beef, containsAll(['Beef', 'Ribeye steak', 'Brisket']));

    // No duplicate names in one result list.
    final names = (await db.searchCatalog('sausage')).map((i) => i.name.toLowerCase());
    expect(names.toSet().length, names.length);
  });

  test('typed items are remembered once, with their category', () async {
    final list = (await db.watchLists().first).single;
    await db.addShoppingItem(list.id, 'Kombucha', category: 'Beverages');
    await db.addShoppingItem(list.id, 'kombucha', category: 'Beverages');
    final r = await db.searchCatalog('kombucha');
    expect(r, hasLength(1));
    expect(r.single.isCustom, isTrue);
    expect(r.single.category, 'Beverages');
  });

  test('pantry sorts by soonest expiry, undated last', () async {
    final now = DateTime.now();
    await db.addPantryItem('Rice');
    await db.addPantryItem('Yogurt',
        expiryDate: now.add(const Duration(days: 2)));
    await db.addPantryItem('Milk',
        expiryDate: now.add(const Duration(days: 1)));
    final items = await db.watchPantry().first;
    expect(items.map((i) => i.name), ['Milk', 'Yogurt', 'Rice']);

    await db.updatePantryQuantity(items.first.id, 3);
    expect((await db.watchPantry().first).first.quantity, 3);

    await db.deletePantryItem(items.first.id);
    expect(
        (await db.watchPantry().first).map((i) => i.name), ['Yogurt', 'Rice']);
  });
}
