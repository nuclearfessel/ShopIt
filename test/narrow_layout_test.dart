import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/app/app.dart';
import 'package:shop_it/data/database.dart';
import 'package:shop_it/data/providers.dart';
import 'package:shop_it/features/settings/settings_dialog.dart';

final _t = DateTime(2026, 1, 1);
const _longName = 'Extra mature cheddar cheese block family size';

final _list = ShoppingList(
  id: 'l1',
  updatedAt: _t,
  name: 'Groceries',
  taxRateId: 'r1',
  useCategories: true,
  autoCategorize: true,
  showEmptyCategories: false,
  sortOrder: 0,
  kind: 'shopping',
  quantityMode: 'level',
);

final _rate = TaxRate(
  id: 'r1',
  updatedAt: _t,
  name: 'Home, a long region name',
  percent: 8.25,
  ruleSet: 'US-WA',
  groceryPercent: null,
);

ShoppingItem _item(String id, String name, {bool checked = false}) =>
    ShoppingItem(
      id: id,
      updatedAt: _t,
      listId: 'l1',
      name: name,
      quantity: 1,
      unit: '',
      checked: checked,
      category: 'Dairy & Eggs',
      price: 3.5,
      taxable: true,
      hasCoupon: true,
      taxManual: false,
      note: 'Brand X, the blue one, check for a coupon first',
    );

CatalogItem _cat(String name, {String parent = ''}) => CatalogItem(
  id: name,
  updatedAt: _t,
  name: name,
  category: 'Produce',
  defaultUnit: '',
  isCustom: false,
  parentName: parent,
  barcode: '',
);

/// Scrolls the (last) list until [finder] is built; rows far below the fold
/// aren't built by the lazy list.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 12 && finder.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).last, const Offset(0, -250));
    await tester.pump();
  }
  // Built is not enough on short windows: bring it fully on screen.
  await tester.ensureVisible(finder.first);
  await tester.pump();
}

/// Renders the app at several window widths and fails on any layout overflow.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  for (final width in [900.0, 600.0, 420.0, 320.0, 240.0]) {
    testWidgets('no layout overflow at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Never opened: the providers below replace every query.
            databaseProvider.overrideWithValue(AppDatabase.memory()),
            taxRatesProvider.overrideWith((_) => Stream.value([_rate])),
            listsProvider.overrideWith((_) => Stream.value([_list])),
            categoriesProvider.overrideWith(
              (_) =>
                  Stream.value([Category(name: 'Dairy & Eggs', sortOrder: 0)]),
            ),
            shoppingItemsProvider.overrideWith(
              (ref, id) => Stream.value([
                _item('a', _longName),
                _item('b', 'Milk'),
                _item('c', 'Eggs', checked: true),
              ]),
            ),
            pantryListsProvider.overrideWith(
              (_) => Stream.value([
                ShoppingList(
                  id: 'p1',
                  updatedAt: _t,
                  name: 'Pantry',
                  taxRateId: null,
                  useCategories: true,
                  autoCategorize: true,
                  showEmptyCategories: false,
                  sortOrder: 0,
                  kind: 'pantry',
                  quantityMode: 'number',
                ),
              ]),
            ),
            pantryProvider.overrideWith(
              (ref, id) => Stream.value([
                PantryItem(
                  id: 'p1',
                  updatedAt: _t,
                  name: _longName,
                  quantity: 12.5,
                  unit: 'family packets',
                  expiryDate: DateTime.now().add(const Duration(days: 2)),
                  location: 'Fridge, top shelf, at the back',
                  category: 'Dairy & Eggs',
                  note: 'Opened last week, use for the pasta bake',
                  listId: 'p1',
                  quantityMode: 'number',
                  level: 'full',
                ),
              ]),
            ),
            catalogSearchProvider.overrideWith(
              (ref, q) async => [
                _cat('Onions'),
                _cat('Yellow onions', parent: 'Onions'),
                _cat('Caramelised extra sweet spring onions', parent: 'Onions'),
              ],
            ),
          ],
          child: const ShopItApp(windowChrome: false),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'shopping screen');

      await tester.enterText(find.byType(TextField).first, 'onion');
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'shopping suggestions');

      // Clear the search so the suggestions don't push the list off screen.
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump(const Duration(milliseconds: 300));

      // Item details sheet from the shopping list.
      await _reveal(tester, find.text('Milk'));
      await tester.tap(find.text('Milk'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'shopping item editor');
      // The title is dropped on very narrow windows to make room for the buttons.
      expect(
        find.text('Edit item'),
        width >= 330 ? findsOneWidget : findsNothing,
      );
      expect(find.text('Save'), findsOneWidget);
      if (width >= 700) {
        // Side navigation visible: a dialog centered in the window.
        final c = tester.getCenter(find.byType(Dialog));
        expect(
          c.dx,
          closeTo(width / 2, 1),
          reason: 'dialog centered horizontally',
        );
        expect(c.dy, closeTo(350, 1), reason: 'dialog centered vertically');
      } else {
        expect(
          find.byType(Dialog),
          findsNothing,
          reason: 'bottom sheet when narrow',
        );
      }
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Sales tax dialog (and the tax lines in the totals bar).
      expect(find.textContaining('Tax 8.25%'), findsOneWidget);
      // Out-of-Milk-style cart section and totals bar.
      await _reveal(tester, find.textContaining('IN YOUR CART'));
      expect(find.textContaining('IN YOUR CART'), findsOneWidget);
      expect(find.textContaining('Cart total:'), findsOneWidget);
      expect(find.textContaining('Items in list: 3'), findsOneWidget);
      expect(
        find.textContaining('\$'),
        findsWidgets,
        reason: 'currency symbol',
      );
      if (width >= 360) {
        expect(find.text('Uncheck all'), findsOneWidget);
        expect(find.text('Delete all'), findsOneWidget);
        // compact: nowhere near a full-width button
        final r = tester.getRect(find.text('Delete all'));
        expect(r.height, lessThan(40));
      } else {
        expect(find.byTooltip('Uncheck all'), findsOneWidget);
        expect(find.byTooltip('Delete all'), findsOneWidget);
      }
      // Settings: theme options and the tax rates, from the gear icon.
      // Wide windows use a dialog. Narrow windows use a full-screen page.
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'settings');
      if (width >= 700) {
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Settings'),
          ),
          findsOneWidget,
        );
      } else {
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(find.byTooltip('Close'), findsOneWidget);
      }
      expect(find.text('APPEARANCE'), findsOneWidget);
      // A segmented control: System / Light / Dark.
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
      for (final tip in ['Match system', 'Light', 'Dark']) {
        expect(find.byTooltip(tip), findsOneWidget, reason: tip);
      }
      // The words stay whole on a narrow page and inside the dialog.
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      await tester.tap(find.byTooltip('Light'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'theme segments');
      expect(find.textContaining('SALES TAX'), findsOneWidget);
      expect(find.text('No tax'), findsOneWidget);
      expect(find.text('Add a tax rate'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      // The old menu entry for tax is gone.
      await tester.tap(find.byTooltip('List options'));
      await tester.pumpAndSettle();
      expect(find.text('Sales tax rate...'), findsNothing);
      await tester.tapAt(const Offset(2, 2)); // dismiss the menu
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pantry').last);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500)); // stream emits
      await tester.pump(const Duration(milliseconds: 500)); // the list's items
      expect(tester.takeException(), isNull, reason: 'pantry screen');

      // Item details sheet from the pantry.
      expect(find.text(_longName), findsOneWidget, reason: 'pantry row shown');
      await tester.tap(find.text(_longName));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'pantry item editor');
      expect(
        find.text('Edit pantry item'),
        width >= 330 ? findsOneWidget : findsNothing,
      );
      expect(find.text('Save'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'add pantry dialog');

      // Let any tooltip timers finish before the test ends.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  }

  test('android never uses the settings dialog', () {
    expect(settingsUsesDialog(android: true, width: 1200), isFalse);
    expect(settingsUsesDialog(android: false, width: 700), isTrue);
    expect(settingsUsesDialog(android: false, width: 699), isFalse);
  });

  testWidgets('windows settings switches as the window crosses 700', (
    tester,
  ) async {
    Future<void> show(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(AppDatabase.memory()),
            listsProvider.overrideWith(
              (_) => Stream.value(const <ShoppingList>[]),
            ),
            taxRatesProvider.overrideWith(
              (_) => Stream.value(const <TaxRate>[]),
            ),
            pantryListsProvider.overrideWith(
              (_) => Stream.value(const <ShoppingList>[]),
            ),
            pantryProvider.overrideWith(
              (ref, id) => Stream.value(const <PantryItem>[]),
            ),
          ],
          child: const ShopItApp(windowChrome: false),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    addTearDown(tester.view.reset);
    await show(const Size(640, 700));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(SettingsDialog), findsNothing);

    tester.view.physicalSize = const Size(900, 700);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'grew past 700');
    expect(find.byType(SettingsDialog), findsOneWidget);
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.text('Shopping'), findsWidgets);

    tester.view.physicalSize = const Size(640, 700);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'shrank below 700');
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(SettingsDialog), findsNothing);
    final page = tester.getRect(find.byType(SettingsPage));
    expect(page.width, 640);
    expect(page.height, 700);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('android settings stay full screen and keep appearance words', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    // A small phone, a common phone, and a larger phone with bigger text.
    // Android stays portrait, so these are portrait sizes under the
    // full-screen breakpoint.
    const cases = [
      (size: Size(320, 640), scale: 1.0),
      (size: Size(360, 800), scale: 1.0),
      (size: Size(412, 915), scale: 1.3),
    ];
    try {
      for (final (:size, :scale) in cases) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 48);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(AppDatabase.memory()),
              listsProvider.overrideWith((_) => Stream.value([_list])),
              taxRatesProvider.overrideWith((_) => Stream.value([_rate])),
              categoriesProvider.overrideWith(
                (_) => Stream.value([
                  Category(name: 'Dairy & Eggs', sortOrder: 0),
                ]),
              ),
              shoppingItemsProvider.overrideWith(
                (ref, id) => Stream.value([_item('b', 'Milk')]),
              ),
              pantryListsProvider.overrideWith(
                (_) => Stream.value(const <ShoppingList>[]),
              ),
              pantryProvider.overrideWith(
                (ref, id) => Stream.value(const <PantryItem>[]),
              ),
            ],
            child: const ShopItApp(windowChrome: false),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);

        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'android settings');
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(SettingsPage), findsOneWidget);

        final page = tester.getRect(find.byType(SettingsPage));
        expect(page.left, 0, reason: 'page covers the left edge');
        expect(page.top, 0, reason: 'page covers the top edge');
        expect(page.width, size.width, reason: 'page is as wide as the screen');
        expect(
          page.height,
          size.height,
          reason: 'page is as tall as the screen',
        );

        final done = tester.getRect(find.widgetWithText(FilledButton, 'Done'));
        expect(
          done.bottom,
          closeTo(size.height - 48 - 12, 2),
          reason: 'Done stays at the bottom, above the system inset',
        );

        for (final word in ['System', 'Light', 'Dark']) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(word),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: word);
          expect(paragraph.text.toPlainText(), word);
          final textRect = tester.getRect(find.text(word));
          final tip = word == 'System' ? 'Match system' : word;
          final segment = tester.getRect(find.byTooltip(tip));
          expect(textRect.left, greaterThanOrEqualTo(segment.left - 1));
          expect(textRect.right, lessThanOrEqualTo(segment.right + 1));
          expect(textRect.top, greaterThanOrEqualTo(segment.top - 1));
          expect(textRect.bottom, lessThanOrEqualTo(segment.bottom + 1));
          expect(
            textRect.height,
            greaterThan(8),
            reason: '$word stays readable',
          );
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
