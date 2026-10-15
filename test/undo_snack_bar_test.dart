import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/ui/undo_snack_bar.dart';

import 'support/harness.dart';

void main() {
  /// Shows the message from inside the running app, as the shopping screen
  /// does after "Delete all".
  void show(WidgetTester tester, VoidCallback onUndo) {
    showUndoSnackBar(
      tester.element(find.byType(Scaffold).first),
      message: 'Deleted 2 items from your cart',
      onUndo: onUndo,
    );
  }

  testWidgets('shows the message with an Undo and a close button', (
    tester,
  ) async {
    await pumpShopIt(tester);
    show(tester, () {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Deleted 2 items from your cart'), findsOneWidget);
    expect(find.text('UNDO'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
  });

  testWidgets('goes away by itself, even though it has an action', (
    tester,
  ) async {
    await pumpShopIt(tester);
    show(tester, () {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Deleted 2 items from your cart'), findsOneWidget);

    // Not yet: still inside the timeout.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Deleted 2 items from your cart'), findsOneWidget);

    // After the timeout it slides away without any tap.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Deleted 2 items from your cart'), findsNothing);
  });

  testWidgets('the close button dismisses it', (tester) async {
    await pumpShopIt(tester);
    show(tester, () {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Deleted 2 items from your cart'), findsNothing);
  });

  testWidgets('Undo runs the action and dismisses the message', (tester) async {
    var undone = 0;
    await pumpShopIt(tester);
    show(tester, () => undone++);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(find.text('Deleted 2 items from your cart'), findsNothing);
  });

  testWidgets('switching sections dismisses it (wide window)', (tester) async {
    await pumpShopIt(tester);
    show(tester, () {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Deleted 2 items from your cart'), findsOneWidget);

    await tester.tap(find.byTooltip('Go to Pantry'));
    await tester.pumpAndSettle();
    expect(find.text('Deleted 2 items from your cart'), findsNothing);

    // ...and it does not come back when returning to the shopping list.
    await tester.tap(find.byTooltip('Go to Shopping'));
    await tester.pumpAndSettle();
    expect(find.text('Deleted 2 items from your cart'), findsNothing);
  });

  testWidgets('switching sections dismisses it (narrow window)', (
    tester,
  ) async {
    await pumpShopIt(tester, width: 360, height: 700);
    show(tester, () {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Deleted 2 items from your cart'), findsOneWidget);

    await tester.tap(find.byTooltip('Go to Pantry'));
    await tester.pumpAndSettle();
    expect(find.text('Deleted 2 items from your cart'), findsNothing);
  });

  testWidgets('a newer message replaces the older one instead of queueing', (
    tester,
  ) async {
    await pumpShopIt(tester);
    show(tester, () {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    showUndoSnackBar(
      tester.element(find.byType(Scaffold).first),
      message: 'Deleted 1 item from your cart',
      onUndo: () {},
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Deleted 1 item from your cart'), findsOneWidget);
    expect(find.text('Deleted 2 items from your cart'), findsNothing);
  });
}
