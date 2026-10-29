import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/data/database.dart';

import 'support/harness.dart';

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _openHistory(WidgetTester tester) async {
  await tester.tap(find.byTooltip('History'));
  await tester.pumpAndSettle();
}

void main() {
  group('the add bar', () {
    testWidgets('has history and add; the pencil shows once you type', (
      tester,
    ) async {
      await pumpShopIt(tester);
      expect(find.byTooltip('History'), findsOneWidget);
      expect(find.byTooltip('Add item'), findsOneWidget);
      expect(find.byTooltip('Edit details before adding'), findsNothing);

      await _type(tester, 'Oat milk');
      expect(find.byTooltip('Edit details before adding'), findsOneWidget);

      await _type(tester, '');
      expect(find.byTooltip('Edit details before adding'), findsNothing);
    });

    testWidgets('fits at the narrowest width with the pencil showing', (
      tester,
    ) async {
      await pumpShopIt(tester, width: 240);
      await _type(tester, 'Oat milk');
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Edit details before adding'), findsOneWidget);
    });
  });

  group('the pencil: add with details', () {
    testWidgets('opens a "New item" editor that says Add, not Save', (
      tester,
    ) async {
      await pumpShopIt(tester);
      await _type(tester, 'Oat milk');
      await tester.tap(find.byTooltip('Edit details before adding'));
      await tester.pumpAndSettle();
      expect(find.text('New item'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      // The name typed in the add bar carries over.
      expect(find.widgetWithText(TextField, 'Oat milk'), findsWidgets);
    });

    testWidgets('a new item cannot be deleted, but still has price and notes', (
      tester,
    ) async {
      await pumpShopIt(tester);
      await _type(tester, 'Oat milk');
      await tester.tap(find.byTooltip('Edit details before adding'));
      await tester.pumpAndSettle();
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Unit price'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
    });

    testWidgets('cancelling leaves the typed text where it was', (
      tester,
    ) async {
      await pumpShopIt(tester);
      await _type(tester, 'Oat milk');
      await tester.tap(find.byTooltip('Edit details before adding'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Oat milk'), findsOneWidget);
    });

    testWidgets('the category list is the user\'s own, custom ones included', (
      tester,
    ) async {
      await pumpShopIt(
        tester,
        categories: [
          Category(name: 'Produce', sortOrder: 0),
          Category(name: 'Gluten free', sortOrder: 1),
          Category(name: 'Other', sortOrder: 2),
        ],
      );
      await _type(tester, 'Pasta');
      await tester.tap(find.byTooltip('Edit details before adding'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Choose a category'));
      await tester.pumpAndSettle();
      expect(find.text('Gluten free'), findsWidgets);
      expect(find.text('Bakery'), findsNothing); // not one of this user's
    });

    testWidgets('an existing item\'s editor also uses the user\'s categories', (
      tester,
    ) async {
      await pumpShopIt(
        tester,
        categories: [
          Category(name: 'Dairy & Eggs', sortOrder: 0),
          Category(name: 'Gluten free', sortOrder: 1),
        ],
        items: [fakeItem('a', 'Milk')],
      );
      await tester.tap(find.text('Milk'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Choose a category'));
      await tester.pumpAndSettle();
      expect(find.text('Gluten free'), findsWidgets);
    });
  });

  group('the History dialog', () {
    testWidgets('lists previous items with their categories', (tester) async {
      await pumpShopIt(
        tester,
        history: [
          fakeHistory('h1', 'Milk'),
          fakeHistory('h2', 'Chips', category: 'Snacks', daysAgo: 3),
        ],
      );
      await _openHistory(tester);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Chips'), findsOneWidget);
      expect(find.text('Snacks'), findsOneWidget);
      expect(find.byTooltip('Remove from history'), findsNWidgets(2));
      expect(find.byTooltip('Add "Chips" to "Grocery list"'), findsOneWidget);
    });

    testWidgets('keeps the order it is given (most recent first)', (
      tester,
    ) async {
      await pumpShopIt(
        tester,
        history: [
          fakeHistory('h1', 'Zucchini'),
          fakeHistory('h2', 'Apples', daysAgo: 2),
        ],
      );
      await _openHistory(tester);
      final z = tester.getTopLeft(find.text('Zucchini')).dy;
      final a = tester.getTopLeft(find.text('Apples')).dy;
      expect(z < a, isTrue);
    });

    testWidgets('can be searched', (tester) async {
      await pumpShopIt(
        tester,
        history: [
          fakeHistory('h1', 'Milk'),
          fakeHistory('h2', 'Chips', category: 'Snacks'),
          fakeHistory('h3', 'Oat milk'),
        ],
      );
      await _openHistory(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Search your history'),
        'milk',
      );
      await tester.pump();
      // (the shopping list behind the dialog also has a "Milk" on it)
      Finder inDialog(String t) =>
          find.descendant(of: find.byType(AlertDialog), matching: find.text(t));
      expect(inDialog('Milk'), findsOneWidget);
      expect(inDialog('Oat milk'), findsOneWidget);
      expect(inDialog('Chips'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'milk'), 'zzz');
      await tester.pump();
      expect(find.textContaining('No items match'), findsOneWidget);
    });

    testWidgets('says so when there is nothing yet', (tester) async {
      await pumpShopIt(tester);
      await _openHistory(tester);
      expect(find.textContaining('Nothing here yet'), findsOneWidget);
    });

    testWidgets('fits a narrow window', (tester) async {
      await pumpShopIt(
        tester,
        width: 240,
        history: [fakeHistory('h1', 'A rather long item name that must wrap')],
      );
      await _openHistory(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('Clear all history', () {
    testWidgets('asks before clearing from the list menu', (tester) async {
      await pumpShopIt(tester, history: [fakeHistory('h1', 'Milk')]);
      await tester.tap(find.byTooltip('List options'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PopupMenuItem<String>, 'Clear all history'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Clear all history?'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Clear all history?'), findsNothing);
    });
  });
}
