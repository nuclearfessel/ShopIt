import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  testWidgets('one list: just its name, no pull-down', (tester) async {
    await pumpShopIt(tester, lists: [fakeList('l1', 'Grocery list')]);
    expect(find.text('Grocery list'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.byTooltip('Choose a list'), findsNothing);
    // Left-aligned with the search field below it, not floating in the middle.
    final nameLeft = tester.getTopLeft(find.text('Grocery list')).dx;
    final fieldLeft = tester.getTopLeft(find.byType(TextField)).dx;
    expect(nameLeft, closeTo(fieldLeft + 12, 16));
  });

  testWidgets('one list at a narrow width too', (tester) async {
    await pumpShopIt(
      tester,
      width: 320,
      lists: [fakeList('l1', 'A very long shopping list name that overflows')],
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(DropdownButton<String>), findsNothing);
  });

  testWidgets('two lists: a pull-down to switch between them', (tester) async {
    await pumpShopIt(
      tester,
      lists: [fakeList('l1', 'Grocery list'), fakeList('l2', 'Party')],
      items: [
        fakeItem('a', 'Milk'),
        fakeItem('b', 'Chips', listId: 'l2', category: 'Snacks'),
      ],
    );
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    expect(find.byTooltip('Choose a list'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Chips'), findsNothing);

    // Open the pull-down and pick the other list.
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Party'), findsOneWidget);
    await tester.tap(find.text('Party').last);
    await tester.pumpAndSettle();
    expect(find.text('Chips'), findsOneWidget);
    expect(find.text('Milk'), findsNothing);
  });

  testWidgets('the pull-down appears as soon as a second list exists', (
    tester,
  ) async {
    await pumpShopIt(tester, lists: [fakeList('l1', 'Only')]);
    expect(find.byType(DropdownButton<String>), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink()); // a fresh app next
    await pumpShopIt(
      tester,
      lists: [fakeList('l1', 'Only'), fakeList('l2', 'Second')],
    );
    expect(find.byType(DropdownButton<String>), findsOneWidget);
  });
}
