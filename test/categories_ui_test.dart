import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/data/category_order.dart';
import 'package:shop_it/data/database.dart';
import 'package:shop_it/features/categories/category_color_dialog.dart';
import 'package:shop_it/ui/category_color.dart';

import 'support/harness.dart';

ListCategoryOrder _o(String category, int position) =>
    ListCategoryOrder(listId: 'l1', category: category, position: position);

Category _c(String name, int order, {int? color}) =>
    Category(name: name, sortOrder: order, color: color);

Future<void> _openMenu(WidgetTester tester, String entry) async {
  await tester.tap(find.byTooltip('List options'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(PopupMenuItem<String>, entry));
  await tester.pumpAndSettle();
}

void main() {
  group('category order helper', () {
    final all = [_c('A', 0), _c('B', 1), _c('C', 2), _c('D', 3)];

    test('without a manual order it is the default order', () {
      expect(orderedCategoryNames(all, const []), ['A', 'B', 'C', 'D']);
    });

    test('manual positions come first, the rest keep the default order', () {
      expect(orderedCategoryNames(all, [_o('C', 0), _o('A', 1)]), [
        'C',
        'A',
        'B',
        'D',
      ]);
    });

    test('a manual entry for a deleted category is ignored by names', () {
      expect(orderedCategoryNames(all, [_o('Zzz', 0)]), ['A', 'B', 'C', 'D']);
    });
  });

  group('headers', () {
    final items = [fakeItem('a', 'Apples', category: 'Produce')];

    testWidgets('use the category colour when one is set', (tester) async {
      await pumpShopIt(
        tester,
        items: items,
        categories: [_c('Produce', 0, color: 0xFFE53935), _c('Other', 1)],
      );
      final header = tester.widget<Text>(find.text('PRODUCE'));
      expect(header.style?.color, const Color(0xFFE53935));
    });

    testWidgets('fall back to an automatic colour without one', (tester) async {
      await pumpShopIt(tester, items: items);
      final header = tester.widget<Text>(find.text('PRODUCE'));
      expect(header.style?.color, isNotNull);
      expect(header.style?.color, isNot(const Color(0xFFE53935)));
    });

    testWidgets('tapping a header opens the colour dialog for it', (
      tester,
    ) async {
      await pumpShopIt(tester, items: items);
      await tester.tap(find.byTooltip('Change the color of "Produce"'));
      await tester.pumpAndSettle();
      expect(find.text('Color for "Produce"'), findsOneWidget);
      expect(find.text('PRESET COLORS'), findsOneWidget);
    });
  });

  group('colour dialog', () {
    Future<CategoryColorChoice?> run(
      WidgetTester tester, {
      int? current,
      required Future<void> Function() interact,
    }) async {
      CategoryColorChoice? result;
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showCategoryColorDialog(
                    context,
                    category: 'Produce',
                    current: current,
                  );
                  done = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await interact();
      await tester.pumpAndSettle();
      expect(done, isTrue);
      return result;
    }

    testWidgets('picking a preset and saving returns it', (tester) async {
      final r = await run(
        tester,
        interact: () async {
          await tester.tap(find.byTooltip('Use #E53935'));
          await tester.pump();
          await tester.tap(find.text('Save'));
        },
      );
      expect(r?.argb, 0xFFE53935);
    });

    testWidgets('cancel returns nothing', (tester) async {
      final r = await run(
        tester,
        current: 0xFF43A047,
        interact: () async {
          await tester.tap(find.byTooltip('Use #E53935'));
          await tester.pump();
          await tester.tap(find.text('Cancel'));
        },
      );
      expect(r, isNull);
    });

    testWidgets('"Automatic" saves null so the default colour returns', (
      tester,
    ) async {
      final r = await run(
        tester,
        current: 0xFF43A047,
        interact: () async {
          await tester.tap(find.text('Automatic'));
          await tester.pump();
          await tester.tap(find.text('Save'));
        },
      );
      expect(r, isNotNull);
      expect(r!.argb, isNull);
    });

    testWidgets('the custom sliders make a colour of their own', (
      tester,
    ) async {
      final r = await run(
        tester,
        interact: () async {
          // Drag the hue slider somewhere other than where it started.
          await tester.drag(find.byType(Slider).first, const Offset(120, 0));
          await tester.pump();
          await tester.tap(find.text('Save'));
        },
      );
      expect(r?.argb, isNotNull);
      expect(kCategoryPresetColors, isNot(contains(r!.argb)));
      expect(r.argb! >> 24, 0xFF); // fully opaque
    });

    testWidgets('the current colour is shown when it opens', (tester) async {
      await run(
        tester,
        current: 0xFF43A047,
        interact: () async {
          expect(find.text('Current color #43A047'), findsOneWidget);
          await tester.tap(find.text('Cancel'));
        },
      );
    });
  });

  group('Manage categories', () {
    testWidgets('lists every category with its controls', (tester) async {
      await pumpShopIt(
        tester,
        categories: [
          _c('Produce', 0, color: 0xFFE53935),
          _c('Bakery', 1),
          _c('Other', 2),
        ],
      );
      await _openMenu(tester, 'Manage categories');
      expect(find.text('Manage categories'), findsOneWidget);
      for (final n in ['Produce', 'Bakery', 'Other']) {
        expect(find.text(n), findsWidgets, reason: n);
      }
      expect(find.byTooltip('Drag to reorder'), findsNWidgets(3));
      expect(find.byTooltip('Change the color of "Produce"'), findsOneWidget);
      // "Other" is the catch-all and cannot be deleted.
      expect(find.byTooltip('Delete category'), findsNWidgets(2));
      expect(find.byTooltip('Add category'), findsOneWidget);
      expect(find.byType(ReorderableListView), findsOneWidget);
    });

    testWidgets('shows them in this list\'s manual order', (tester) async {
      await pumpShopIt(
        tester,
        categoryOrder: [_o('Bakery', 0)],
        categories: [_c('Produce', 0), _c('Bakery', 1), _c('Other', 2)],
      );
      await _openMenu(tester, 'Manage categories');
      final tops = {
        for (final n in ['Produce', 'Bakery', 'Other'])
          n: tester
              .getTopLeft(
                find
                    .descendant(
                      of: find.byType(ReorderableListView),
                      matching: find.text(n),
                    )
                    .first,
              )
              .dy,
      };
      expect(tops['Bakery']! < tops['Produce']!, isTrue);
      expect(tops['Produce']! < tops['Other']!, isTrue);
      // A manual order exists, so there is a way back to the default.
      expect(find.text('Reset order'), findsOneWidget);
    });

    testWidgets('no "Reset order" while the order is the default', (
      tester,
    ) async {
      await pumpShopIt(tester);
      await _openMenu(tester, 'Manage categories');
      expect(find.text('Reset order'), findsNothing);
    });

    testWidgets('the dot shows the color the header really has', (
      tester,
    ) async {
      await pumpShopIt(
        tester,
        items: [fakeItem('a', 'Apples', category: 'Produce')],
        categories: [_c('Produce', 0, color: 0xFFE53935), _c('Bakery', 1)],
      );
      final headerColor = tester
          .widget<Text>(find.text('PRODUCE'))
          .style
          ?.color;
      await _openMenu(tester, 'Manage categories');

      Color dotOf(String name) =>
          (tester
                      .widget<Container>(
                        find.descendant(
                          // the dialog's row (the list header has the same tip)
                          of: find.descendant(
                            of: find.byType(AlertDialog),
                            matching: find.byTooltip(
                              'Change the color of "$name"',
                            ),
                          ),
                          matching: find.byType(Container),
                        ),
                      )
                      .decoration!
                  as BoxDecoration)
              .color!;

      // A chosen color is shown as chosen...
      expect(dotOf('Produce'), headerColor);
      expect(dotOf('Produce'), const Color(0xFFE53935));
      // ...and an automatic one is the same color the header would get.
      expect(
        dotOf('Bakery'),
        automaticCategoryColor(
          'Bakery',
          Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        ),
      );
    });

    testWidgets('deleting asks first and explains what happens', (
      tester,
    ) async {
      await pumpShopIt(tester);
      await _openMenu(tester, 'Manage categories');
      await tester.tap(find.byTooltip('Delete category').first);
      await tester.pumpAndSettle();
      expect(find.text('Delete "Produce"?'), findsOneWidget);
      expect(find.textContaining('removed from every list'), findsOneWidget);
    });
  });
}
