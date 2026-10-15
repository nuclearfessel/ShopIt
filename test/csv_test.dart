import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/data/csv.dart';
import 'package:shop_it/data/database.dart';
import 'package:shop_it/data/list_csv.dart';
import 'package:shop_it/services/file_service.dart';

import 'support/harness.dart';

Future<void> _menu(WidgetTester tester, String entry) async {
  await tester.tap(find.byTooltip('List options'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(PopupMenuItem<String>, entry));
  await tester.pumpAndSettle();
}

void main() {
  group('csv codec', () {
    test('quotes commas, quotes, line breaks and edge spaces', () {
      final text = encodeCsv([
        ['a,b', 'say "hi"', 'two\nlines', ' padded ', 'plain'],
      ]);
      expect(text, '"a,b","say ""hi""","two\nlines"," padded ",plain');
      expect(decodeCsv(text), [
        ['a,b', 'say "hi"', 'two\nlines', ' padded ', 'plain'],
      ]);
    });

    test('reads CRLF, CR, a BOM, blank lines and a missing final newline', () {
      expect(decodeCsv('﻿a,b\r\nc,d\r\n\r\ne,f'), [
        ['a', 'b'],
        ['c', 'd'],
        ['e', 'f'],
      ]);
      expect(decodeCsv('a\rb'), [
        ['a'],
        ['b'],
      ]);
      expect(decodeCsv(''), isEmpty);
    });

    test('keeps empty fields', () {
      expect(decodeCsv('a,,c\n,,'), [
        ['a', '', 'c'],
        ['', '', ''],
      ]);
      expect(decodeCsv('"",x'), [
        ['', 'x'],
      ]);
    });
  });

  group('list csv', () {
    final shopping = fakeItem('i1', 'Milk, 2%', checked: true).copyWith(
      quantity: 2,
      unit: 'gal',
      note: 'The "good" one',
      hasCoupon: true,
    );

    test('shopping round trip', () {
      final rows = parseShoppingCsv(shoppingItemsToCsv([shopping]));
      expect(rows, hasLength(1));
      final r = rows.single;
      expect(r.name, 'Milk, 2%');
      expect(r.quantity, 2);
      expect(r.unit, 'gal');
      expect(r.category, 'Dairy & Eggs');
      expect(r.price, 3.5);
      expect(r.note, 'The "good" one');
      expect(r.coupon, isTrue);
      expect(r.checked, isTrue);
    });

    test('tolerant shopping parsing', () {
      final rows = parseShoppingCsv(
        'Item,Qty,Aisle,Cost,Done\n'
        'Eggs,"1,5",Dairy,\$3.50,Y\n'
        ',4,Dairy,,\n'
        'Bread,,,,no\n',
      );
      expect(rows.map((r) => r.name), ['Eggs', 'Bread']);
      expect(rows.first.quantity, 1.5);
      expect(rows.first.price, 3.5);
      expect(rows.first.category, 'Dairy');
      expect(rows.first.checked, isTrue);
      expect(rows.last.quantity, 1);
      expect(rows.last.price, isNull);
      expect(rows.last.checked, isFalse);
    });

    test('a file without a header is a list of names', () {
      final rows = parseShoppingCsv('Apples\nPears\n');
      expect(rows.map((r) => r.name), ['Apples', 'Pears']);
    });

    test('pantry parsing: modes, levels and dates', () {
      final rows = parsePantryCsv(
        'Name,Quantity,Expiry,Level,Amount\n'
        'Yogurt,,12/31/26,Low,Low/Full\n'
        'Rice,3,2027-01-05,,Number\n'
        'Flour,2,,,\n',
      );
      expect(rows[0].mode, 'level');
      expect(rows[0].level, 'low');
      expect(rows[0].expiry, DateTime(2026, 12, 31));
      expect(rows[1].mode, 'number');
      expect(rows[1].quantity, 3);
      expect(rows[1].expiry, DateTime(2027, 1, 5));
      expect(rows[2].mode, 'number'); // quantity but no Amount column value
    });

    test('safeFileName', () {
      expect(safeFileName('Weekly: "shop"/1'), 'Weekly_ _shop__1');
      expect(safeFileName('  '), 'list');
    });
  });

  group('database import', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.memory());
    tearDown(() => db.close());

    test('shopping import creates categories and history', () async {
      await db.addList('Imported');
      final list = (await db.watchLists().first).last;
      final n = await db.importShoppingItems(
        list.id,
        parseShoppingCsv(
          'Name,Category,Quantity\nMilk,Dairy & Eggs,2\nWidget,Gadgets,1\n',
        ),
      );
      expect(n, 2);
      final items = await db.watchShoppingItems(list.id).first;
      expect(items.map((i) => i.name), containsAll(['Milk', 'Widget']));
      expect(items.firstWhere((i) => i.name == 'Widget').category, 'Gadgets');
      final cats = (await db.watchCategories().first).map((c) => c.name);
      expect(cats, contains('Gadgets'));
      // an existing category is matched case-insensitively, not duplicated
      await db.importShoppingItems(
        list.id,
        parseShoppingCsv('Name,Category\nCream,dairy & eggs\n'),
      );
      final again = (await db.watchCategories().first).where(
        (c) => c.name.toLowerCase() == 'dairy & eggs',
      );
      expect(again, hasLength(1));
    });

    test('pantry import', () async {
      await db.addList('Garage', kind: 'pantry');
      final list = (await db.watchPantryLists().first).last;
      await db.importPantryItems(
        list.id,
        parsePantryCsv('Name,Amount,Level\nGlue,Low/Full,Low\n'),
      );
      final items = await db.watchPantry(listId: list.id).first;
      expect(items.single.name, 'Glue');
      expect(items.single.quantityMode, 'level');
      expect(items.single.level, 'low');
    });
  });

  group('export and import menus', () {
    testWidgets('shopping export saves the list as CSV', (tester) async {
      final files = FakeFileService();
      await pumpShopIt(tester, fileService: files);
      await _menu(tester, 'Export list');
      expect(files.savedName, 'Grocery list.csv');
      final rows = decodeCsv(files.savedText!);
      expect(rows.first.first, 'Name');
      expect(rows.map((r) => r.first), containsAll(['Milk', 'Bread', 'Eggs']));
      expect(find.text('Exported 3 items from "Grocery list"'), findsOneWidget);
    });

    testWidgets('a cancelled export says nothing', (tester) async {
      final files = FakeFileService()..cancelSave = true;
      await pumpShopIt(tester, fileService: files);
      await _menu(tester, 'Export list');
      expect(find.textContaining('Exported'), findsNothing);
    });

    testWidgets('importing an empty file explains why', (tester) async {
      final files = FakeFileService(
        picked: const PickedText(name: 'blank', text: 'Name,Qty\n'),
      );
      await pumpShopIt(tester, fileService: files);
      await _menu(tester, 'Import list');
      expect(find.text('No items were found in "blank"'), findsOneWidget);
      expect(find.text('Import as a new list'), findsNothing);
    });

    testWidgets('cancelling the file picker does nothing', (tester) async {
      await pumpShopIt(tester, fileService: FakeFileService());
      await _menu(tester, 'Import list');
      expect(find.text('Import as a new list'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('import asks for a name, pre-filled with the file name', (
      tester,
    ) async {
      final files = FakeFileService(
        picked: const PickedText(name: 'Weekly shop', text: 'Name\nApples\n'),
      );
      await pumpShopIt(tester, fileService: files);
      await _menu(tester, 'Import list');
      expect(find.text('Import as a new list'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Weekly shop'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Import as a new list'), findsNothing);
    });

    testWidgets('pantry export and import', (tester) async {
      final files = FakeFileService(
        picked: const PickedText(name: 'Garage', text: 'Name\nGlue\n'),
      );
      await pumpShopIt(tester, fileService: files);
      await tester.tap(find.byTooltip('Go to Pantry'));
      await tester.pumpAndSettle();
      await _menu(tester, 'Export list');
      expect(files.savedName, 'Pantry.csv');
      expect(decodeCsv(files.savedText!).first, contains('Level'));
      await _menu(tester, 'Import list');
      expect(find.text('Import as a new pantry list'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Garage'), findsOneWidget);
    });
  });
}
