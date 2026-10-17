import 'package:flutter/material.dart';
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
}
