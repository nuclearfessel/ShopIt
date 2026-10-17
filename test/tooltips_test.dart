import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/ui/choice_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_it/app/title_bar.dart';

import 'support/harness.dart';

/// True when [e] has a tooltip of its own, sits inside one, or contains one.
bool _hasTip(Element e) {
  final w = e.widget;
  if (w is IconButton && (w.tooltip?.isNotEmpty ?? false)) return true;
  if (w is FloatingActionButton && (w.tooltip?.isNotEmpty ?? false)) {
    return true;
  }
  if (w is PopupMenuButton && (w.tooltip?.isNotEmpty ?? false)) return true;
  if (w is NavigationDestination && (w.tooltip?.isNotEmpty ?? false)) {
    return true;
  }
  var found = false;
  e.visitAncestorElements((a) {
    if (a.widget is Tooltip) found = true;
    return !found;
  });
  if (found) return true;
  void down(Element c) {
    if (found) return;
    if (c.widget is Tooltip) {
      found = true;
      return;
    }
    c.visitChildren(down);
  }

  e.visitChildren(down);
  return found;
}

/// Whether [w] is something the user can click or tap (and is enabled).
bool _isControl(Widget w) {
  if (w is IconButton) return w.onPressed != null;
  if (w is TextButton) return w.onPressed != null;
  if (w is FilledButton) return w.onPressed != null;
  if (w is OutlinedButton) return w.onPressed != null;
  if (w is ElevatedButton) return w.onPressed != null;
  if (w is FloatingActionButton) return w.onPressed != null;
  if (w is Checkbox) return w.onChanged != null;
  if (w is CheckboxListTile) return w.onChanged != null;
  if (w is SwitchListTile) return w.onChanged != null;
  if (w is Slider) return w.onChanged != null;
  if (w is ListTile) return w.onTap != null;
  if (w is SimpleDialogOption) return w.onPressed != null;
  if (w is PopupMenuItem) return w.enabled;
  if (w is PopupMenuButton) return true;
  if (w is MenuItemButton) return w.onPressed != null;
  if (w is ChoiceField) return true;
  if (w is SegmentedButton) return true;
  if (w is NavigationDestination) return true;
  return false;
}

String _describe(Element e) {
  String? text;
  void down(Element c) {
    if (text != null) return;
    final w = c.widget;
    if (w is Text && (w.data?.isNotEmpty ?? false)) {
      text = w.data;
      return;
    }
    c.visitChildren(down);
  }

  e.visitChildren(down);
  return '${e.widget.runtimeType}${text == null ? '' : ' "$text"'}';
}

/// Every enabled control on screen that has no tooltip.
List<String> _untipped(WidgetTester tester) => [
  for (final e in tester.allElements)
    if (_isControl(e.widget) && !_hasTip(e)) _describe(e),
];

void _expectAllTipped(WidgetTester tester, String where) {
  expect(
    _untipped(tester),
    isEmpty,
    reason: 'controls without a tooltip on: $where',
  );
}

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle();

void main() {
  // The Ziptax key dialog reads the saved key from the device settings.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('wide window: every control has a tooltip', (tester) async {
    await pumpShopIt(
      tester,
      lists: [fakeList('l1', 'Grocery list'), fakeList('l2', 'Party')],
    );
    _expectAllTipped(tester, 'shopping screen');
    // Navigation rail destinations.
    expect(find.byTooltip('Go to Shopping'), findsOneWidget);
    expect(find.byTooltip('Go to Pantry'), findsOneWidget);

    // The overflow menu and its entries.
    await tester.tap(find.byTooltip('List options'));
    await _settle(tester);
    expect(find.byType(PopupMenuItem<String>), findsWidgets);
    _expectAllTipped(tester, 'list options menu');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape); // close the menu
    await _settle(tester);
    expect(find.byType(PopupMenuItem<String>), findsNothing);

    // Settings, and the dialogs it opens.
    await tester.tap(find.byTooltip('Settings'));
    await _settle(tester);
    _expectAllTipped(tester, 'settings dialog');
    await tester.tap(find.text('Add a tax rate'));
    await _settle(tester);
    _expectAllTipped(tester, 'add tax rate form');
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    await tester.tap(find.text('Ziptax API key...'));
    await _settle(tester);
    _expectAllTipped(tester, 'Ziptax key dialog');
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    await tester.tap(find.text('Done'));
    await _settle(tester);

    // The item editor and its list picker.
    await tester.tap(find.text('Milk'));
    await _settle(tester);
    _expectAllTipped(tester, 'shopping item editor');
    await tester.tap(find.text('Move'));
    await _settle(tester);
    _expectAllTipped(tester, 'move to list picker');
    await tester.tap(find.text('Party').last);
    await _settle(tester);
  });

  testWidgets('dialogs from the menu have tooltips', (tester) async {
    await pumpShopIt(tester, lists: [fakeList('l1', 'Grocery list')]);
    await tester.tap(find.byTooltip('List options'));
    await _settle(tester);
    await tester.tap(find.text('New list'));
    await _settle(tester);
    _expectAllTipped(tester, 'new list dialog');
    await tester.tap(find.text('Cancel'));
    await _settle(tester);

    await tester.tap(find.byTooltip('List options'));
    await _settle(tester);
    await tester.tap(find.text('Delete this list'));
    await _settle(tester);
    _expectAllTipped(tester, 'delete list confirmation');
  });

  testWidgets('list settings and manage lists dialogs have tooltips', (
    tester,
  ) async {
    await pumpShopIt(
      tester,
      lists: [fakeList('l1', 'Grocery list'), fakeList('l2', 'Party')],
    );
    await tester.tap(find.byTooltip('List options'));
    await _settle(tester);
    await tester.tap(find.text('List settings'));
    await _settle(tester);
    _expectAllTipped(tester, 'list settings dialog');
    await tester.tap(find.text('Done'));
    await _settle(tester);

    await tester.tap(find.byTooltip('List options'));
    await _settle(tester);
    await tester.tap(find.text('Manage lists'));
    await _settle(tester);
    _expectAllTipped(tester, 'manage lists dialog');
    await tester.tap(find.byTooltip('Rename list').first);
    await _settle(tester);
    _expectAllTipped(tester, 'rename list dialog');
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Delete list').first);
    await _settle(tester);
    _expectAllTipped(tester, 'delete list confirmation (from manage lists)');
  });

  testWidgets('categories and the colour dialog have tooltips', (tester) async {
    await pumpShopIt(tester);
    await tester.tap(find.byTooltip('List options'));
    await _settle(tester);
    await tester.tap(find.text('Manage categories'));
    await _settle(tester);
    _expectAllTipped(tester, 'manage categories dialog');
    await tester.tap(find.byTooltip('Change the color of "Produce"').first);
    await _settle(tester);
    _expectAllTipped(tester, 'category colour dialog');
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Delete category').first);
    await _settle(tester);
    _expectAllTipped(tester, 'delete category confirmation');
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    await tester.tap(find.text('Done'));
    await _settle(tester);

    // Tapping a header on the list opens the same colour dialog.
    await tester.tap(find.byTooltip('Change the color of "Bakery"'));
    await _settle(tester);
    _expectAllTipped(tester, 'colour dialog from a header');
  });

  testWidgets('history and the new item editor have tooltips', (tester) async {
    await pumpShopIt(tester, history: [fakeHistory('h1', 'Milk')]);
    await tester.tap(find.byTooltip('History'));
    await _settle(tester);
    _expectAllTipped(tester, 'history dialog');
    await tester.tap(find.text('Done'));
    await _settle(tester);

    await tester.enterText(find.byType(TextField).first, 'Oat milk');
    await tester.pump(const Duration(milliseconds: 300));
    _expectAllTipped(tester, 'add bar with the pencil');
    await tester.tap(find.byTooltip('Edit details before adding'));
    await _settle(tester);
    _expectAllTipped(tester, 'new item editor');
  });

  testWidgets('the Move/Copy dialog has tooltips', (tester) async {
    await pumpShopIt(
      tester,
      lists: [fakeList('l1', 'Grocery list'), fakeList('l2', 'Party')],
    );
    await tester.tap(find.byTooltip('List options'));
    await _settle(tester);
    await tester.tap(find.text('Move/Copy items'));
    await _settle(tester);
    _expectAllTipped(tester, 'move/copy dialog');
    await tester.tap(find.text('Select all'));
    await tester.pump();
    _expectAllTipped(tester, 'move/copy dialog with items ticked');
  });

  testWidgets('the pantry menu and its dialogs have tooltips', (tester) async {
    await pumpShopIt(
      tester,
      pantry: [
        fakePantryItem('a', 'Yogurt', mode: 'level'),
        fakePantryItem('b', 'Rice'),
      ],
      lists: [fakeList('l1', 'Grocery list'), fakeList('l2', 'Party')],
      pantryLists: [
        fakeList('p1', 'Pantry', kind: 'pantry'),
        fakeList('p2', 'Garage', kind: 'pantry'),
      ],
    );
    await tester.tap(find.byTooltip('Go to Pantry'));
    await _settle(tester);
    _expectAllTipped(tester, 'pantry screen (Low/Full and numbers)');

    Future<void> openFromMenu(String entry) async {
      await tester.tap(find.byTooltip('List options'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(PopupMenuItem<String>, entry));
      await _settle(tester);
    }

    await tester.tap(find.byTooltip('List options'));
    await _settle(tester);
    _expectAllTipped(tester, 'pantry list menu');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);

    await openFromMenu('Amounts');
    _expectAllTipped(tester, 'items setting dialog');
    await tester.tap(find.text('Cancel'));
    await _settle(tester);

    await openFromMenu('Manage lists');
    _expectAllTipped(tester, 'manage pantry lists');
    await tester.tap(find.text('Done'));
    await _settle(tester);

    await openFromMenu('Move/Copy items');
    _expectAllTipped(tester, 'pantry move/copy dialog');
    await tester.tap(find.text('Cancel'));
    await _settle(tester);

    await tester.tap(find.text('Yogurt'));
    await _settle(tester);
    _expectAllTipped(tester, 'pantry item editor (Low/Full)');
  });

  testWidgets('pantry: every control has a tooltip', (tester) async {
    await pumpShopIt(tester);
    await tester.tap(find.byTooltip('Go to Pantry'));
    await _settle(tester);
    _expectAllTipped(tester, 'pantry screen');

    await tester.tap(find.text('Yogurt'));
    await _settle(tester);
    _expectAllTipped(tester, 'pantry item editor');
    await tester.tap(find.text('Cancel'));
    await _settle(tester);

    await tester.tap(find.byTooltip('Add pantry item'));
    await _settle(tester);
    _expectAllTipped(tester, 'add pantry item dialog');
  });

  testWidgets('narrow window: every control has a tooltip', (tester) async {
    await pumpShopIt(tester, width: 360, height: 700);
    _expectAllTipped(tester, 'shopping screen (narrow)');
    expect(find.byTooltip('Go to Shopping'), findsOneWidget);
    expect(find.byTooltip('Go to Pantry'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await _settle(tester);
    _expectAllTipped(tester, 'settings dialog (narrow)');
    await tester.tap(find.text('Done'));
    await _settle(tester);

    await tester.tap(find.text('Milk'));
    await _settle(tester);
    _expectAllTipped(tester, 'item editor sheet (narrow)');
  });

  testWidgets('the audit itself catches a control without a tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextButton(onPressed: () {}, child: const Text('Naked')),
              IconButton(
                tooltip: 'Dressed',
                onPressed: () {},
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
    expect(_untipped(tester), ['TextButton "Naked"']);
  });

  group('window title bar', () {
    Future<void> pumpFrame(WidgetTester tester) => tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WindowFrame(child: Center(child: Text('app'))),
        ),
      ),
    );

    testWidgets('its three buttons have tooltips', (tester) async {
      await pumpFrame(tester);
      await tester.pump();
      expect(find.byTooltip('Minimize'), findsOneWidget);
      expect(find.byTooltip('Maximize'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.text('app'), findsOneWidget);
    });

    testWidgets('hovering a button shows its tooltip', (tester) async {
      await pumpFrame(tester);
      await tester.pump();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);

      await mouse.moveTo(tester.getCenter(find.byTooltip('Close')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Close'), findsOneWidget);

      await mouse.moveTo(tester.getCenter(find.byTooltip('Minimize')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Minimize'), findsOneWidget);
    });
  });
}
