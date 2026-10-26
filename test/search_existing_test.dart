import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  testWidgets('search jumps to an item already on the list', (tester) async {
    await pumpShopIt(
      tester,
      items: [
        fakeItem('a', 'Milk'),
        fakeItem('b', 'Bread', category: 'Bakery'),
      ],
    );
    await tester.enterText(find.byType(TextField).first, 'mil');
    await tester.pump();
    expect(find.text('On this list'), findsOneWidget);
    await tester.tap(find.text('On this list'));
    await tester.pump();
    expect(find.text('Milk is already on this list.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'mil'), findsNothing);
    expect(find.text('On this list'), findsNothing);
  });

  testWidgets('search offers pantry items without adding them', (tester) async {
    await pumpShopIt(
      tester,
      items: [fakeItem('a', 'Bread', category: 'Bakery')],
      pantry: [fakePantryItem('p', 'Yogurt')],
    );
    await tester.enterText(find.byType(TextField).first, 'yog');
    await tester.pump();
    expect(find.text('In pantry'), findsOneWidget);
    await tester.tap(find.text('In pantry'));
    await tester.pump();
    expect(find.text('You already have Yogurt in the pantry.'), findsOneWidget);
    expect(find.text('Yogurt'), findsNothing);
  });

  testWidgets('an empty search field offers recent history', (tester) async {
    await pumpShopIt(
      tester,
      items: [fakeItem('a', 'Milk')],
      history: [fakeHistory('h1', 'Chips', category: 'Snacks')],
    );
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Chips'), findsOneWidget);
  });

  testWidgets('suggestions cover the list instead of pushing it down', (
    tester,
  ) async {
    await pumpShopIt(
      tester,
      items: [fakeItem('a', 'Milk')],
      history: [fakeHistory('h1', 'Chips', category: 'Snacks')],
    );
    final before = tester.getTopLeft(find.text('Milk'));
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(find.text('Recent'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Milk')), before);
  });

  testWidgets('choosing a recent name closes the menu', (tester) async {
    await pumpShopIt(
      tester,
      items: [fakeItem('a', 'Milk')],
      history: [fakeHistory('h1', 'Chips', category: 'Snacks')],
    );
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.tap(find.text('Chips'));
    await tester.pump();
    expect(find.text('Recent'), findsNothing);
  });

  testWidgets('arrow keys cycle search results on desktop', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await pumpShopIt(tester, items: [fakeItem('a', 'Milk')]);
      await tester.enterText(find.byType(TextField).first, 'oni');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      List<ListTile> suggestionTiles() {
        final card = find.ancestor(
          of: find.text('Onions').first,
          matching: find.byType(Card),
        );
        return tester
            .widgetList<ListTile>(
              find.descendant(of: card, matching: find.byType(ListTile)),
            )
            .toList();
      }

      expect(suggestionTiles().where((tile) => tile.selected), isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(suggestionTiles().first.selected, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(suggestionTiles()[1].selected, isTrue);
      expect(suggestionTiles().first.selected, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(suggestionTiles().first.selected, isTrue);

      final count = suggestionTiles().length;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(suggestionTiles().last.selected, isTrue);
      expect(suggestionTiles().length, count);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Red onions'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('arrow down reaches a name already in recent history', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await pumpShopIt(
        tester,
        items: [fakeItem('a', 'Milk')],
        history: [fakeHistory('h1', 'Chips', category: 'Snacks')],
      );
      await tester.enterText(find.byType(TextField).first, 'chi');
      await tester.pump();
      expect(find.text('Recent'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      final tile = tester.widget<ListTile>(
        find.ancestor(of: find.text('Chips'), matching: find.byType(ListTile)),
      );
      expect(tile.selected, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('choosing a catalog match closes the menu', (tester) async {
    await pumpShopIt(tester, items: [fakeItem('a', 'Milk')]);
    await tester.enterText(find.byType(TextField).first, 'oni');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Red onions'), findsOneWidget);
    await tester.tap(find.text('Onions').first);
    await tester.pump();
    expect(find.text('Red onions'), findsNothing);
    expect(find.text('Onions'), findsNothing);
  });

  testWidgets('an Other item can be dragged into a category that has items', (
    tester,
  ) async {
    await pumpShopIt(
      tester,
      items: [
        fakeItem('a', 'Crackers', category: 'Other'),
        fakeItem('b', 'Bread', category: 'Bakery'),
      ],
    );
    expect(find.byTooltip('Drag into a category'), findsOneWidget);
    expect(find.text('OTHER'), findsOneWidget);
    expect(find.text('BAKERY'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byTooltip('Drag into a category')),
    );
    await gesture.moveTo(tester.getCenter(find.text('BAKERY')));
    await tester.pump();
    expect(find.text('Crackers'), findsNWidgets(2));
    await gesture.up();
    await tester.pump();
  });
}
