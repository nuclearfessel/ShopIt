import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/app/app.dart';
import 'package:shop_it/data/database.dart';
import 'package:shop_it/data/providers.dart';

final _t = DateTime(2026, 1, 1);

ShoppingList fakeList(
  String id,
  String name, {
  bool useCategories = true,
  bool autoCategorize = true,
  bool showEmptyCategories = false,
  int sortOrder = 0,
}) => ShoppingList(
  id: id,
  updatedAt: _t,
  name: name,
  useCategories: useCategories,
  autoCategorize: autoCategorize,
  showEmptyCategories: showEmptyCategories,
  sortOrder: sortOrder,
);

ShoppingItem fakeItem(
  String id,
  String name, {
  String listId = 'l1',
  bool checked = false,
  double? price = 3.5,
  String category = 'Dairy & Eggs',
}) => ShoppingItem(
  id: id,
  updatedAt: _t,
  listId: listId,
  name: name,
  quantity: 1,
  unit: '',
  checked: checked,
  category: category,
  price: price,
  note: '',
  taxable: false,
  hasCoupon: false,
  taxManual: false,
);

PantryItem fakePantryItem(String id, String name) => PantryItem(
  id: id,
  updatedAt: _t,
  name: name,
  quantity: 2,
  unit: 'packs',
  expiryDate: DateTime(2030, 1, 1),
  location: 'Fridge',
  category: 'Dairy & Eggs',
  note: '',
);

CatalogItem fakeCatalog(String name, {String parent = ''}) => CatalogItem(
  id: name,
  updatedAt: _t,
  name: name,
  category: 'Produce',
  defaultUnit: '',
  isCustom: false,
  parentName: parent,
);

/// Pumps the whole app at [width] x [height] with fake data (no database).
Future<void> pumpShopIt(
  WidgetTester tester, {
  double width = 1000,
  double height = 800,
  List<ShoppingList>? lists,
  List<ShoppingItem>? items,
  List<PantryItem>? pantry,
  List<TaxRate> rates = const [],
  List<ListCategoryOrder> categoryOrder = const [],
  List<Category>? categories,
  List<HistoryEntry> history = const [],
  GlobalKey? boundary,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final theLists = lists ?? [fakeList('l1', 'Grocery list')];
  final theItems =
      items ??
      [
        fakeItem('a', 'Milk'),
        fakeItem('b', 'Bread', category: 'Bakery'),
        fakeItem('c', 'Eggs', checked: true),
      ];
  final thePantry = pantry ?? [fakePantryItem('p1', 'Yogurt')];

  Widget app = ProviderScope(
    overrides: [
      // Never opened: every query below is replaced.
      databaseProvider.overrideWithValue(AppDatabase.memory()),
      listsProvider.overrideWith((_) => Stream.value(theLists)),
      categoriesProvider.overrideWith(
        (_) => Stream.value(
          categories ??
              [
                Category(name: 'Produce', sortOrder: 0),
                Category(name: 'Bakery', sortOrder: 1),
                Category(name: 'Dairy & Eggs', sortOrder: 2),
                Category(name: 'Other', sortOrder: 3),
              ],
        ),
      ),
      shoppingItemsProvider.overrideWith(
        (ref, id) => Stream.value([
          for (final i in theItems)
            if (i.listId == id) i,
        ]),
      ),
      taxRatesProvider.overrideWith((_) => Stream.value(rates)),
      listCategoryOrderProvider.overrideWith(
        (ref, id) => Stream.value([
          for (final o in categoryOrder)
            if (o.listId == id) o,
        ]),
      ),
      pantryProvider.overrideWith((_) => Stream.value(thePantry)),
      historyProvider.overrideWith((_) => Stream.value(history)),
      catalogSearchProvider.overrideWith(
        (ref, q) async => [
          fakeCatalog('Onions'),
          fakeCatalog('Red onions', parent: 'Onions'),
        ],
      ),
    ],
    child: const ShopItApp(windowChrome: false),
  );
  if (boundary != null) app = RepaintBoundary(key: boundary, child: app);
  await tester.pumpWidget(app);
  // The lists arrive first, then each list's items: pump twice.
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

// ---- Pixels ---------------------------------------------------------------

/// RGBA pixels of a rendered widget.
class Shot {
  Shot(this.width, this.height, this._data);

  final int width;
  final int height;
  final ByteData _data;

  ({int r, int g, int b, int a}) at(int x, int y) {
    final o = (y * width + x) * 4;
    return (
      r: _data.getUint8(o),
      g: _data.getUint8(o + 1),
      b: _data.getUint8(o + 2),
      a: _data.getUint8(o + 3),
    );
  }

  /// How far (0..1) a pixel is from [bg], by its largest channel difference.
  double ink(int x, int y, ({int r, int g, int b}) bg) {
    final p = at(x, y);
    final d = [
      (p.r - bg.r).abs(),
      (p.g - bg.g).abs(),
      (p.b - bg.b).abs(),
    ].reduce((a, b) => a > b ? a : b);
    return d / 255;
  }
}

Future<Shot> capture(
  WidgetTester tester,
  GlobalKey key, {
  double pixelRatio = 1,
}) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final result = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    return Shot(image.width, image.height, data!);
  });
  return result!;
}

HistoryEntry fakeHistory(
  String id,
  String name, {
  String category = 'Dairy & Eggs',
  int daysAgo = 0,
}) => HistoryEntry(
  id: id,
  updatedAt: _t,
  name: name,
  category: category,
  unit: '',
  lastUsed: _t.subtract(Duration(days: daysAgo)),
  useCount: 1,
);
