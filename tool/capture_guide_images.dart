import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_it/data/database.dart';
import 'package:shop_it/ui/keyline/keyline_icon.dart';

import '../test/support/harness.dart';

/// One-shot: `flutter test tool/capture_guide_images.dart`
///
/// Writes the icons and screens used by docs/usage.md. Icons match the app:
/// key lime stroke on the night background.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const night = Color(0xFF1A1C17);
  const lime = Color(0xFFBFE04F);

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _loadRoboto();
  });

  testWidgets('capture guide icons and screens', (tester) async {
    final iconDir = Directory('docs/icons')..createSync(recursive: true);
    final shotDir = Directory('docs/screenshots')..createSync(recursive: true);

    const icons = <String, KeylineIconData>{
      'shopping': KeylineIcons.shoppingCart,
      'pantry': KeylineIcons.archive,
      'recipes': KeylineIcons.bookOpen,
      'scan': KeylineIcons.scanBarcode,
      'settings': KeylineIcons.settings,
      'more': KeylineIcons.moreVertical,
      'search': KeylineIcons.search,
      'pen': KeylineIcons.pen,
      'history': KeylineIcons.history,
      'plus': KeylineIcons.plus,
      'uncheck': KeylineIcons.listX,
      'delete': KeylineIcons.bin2,
      'bin': KeylineIcons.bin,
      'new-list': KeylineIcons.listPlus,
      'sun': KeylineIcons.sun,
      'moon': KeylineIcons.moon,
      'monitor': KeylineIcons.monitor,
      'tax': KeylineIcons.percent,
      'locate': KeylineIcons.locateFixed,
    };

    for (final entry in icons.entries) {
      final bytes = await _pngOf(
        tester,
        width: 48,
        height: 48,
        child: ColoredBox(
          color: night,
          child: Center(
            child: KeylineIcon(entry.value, size: 26, color: lime),
          ),
        ),
      );
      await _write(tester, File('${iconDir.path}/${entry.key}.png'), bytes);
    }

    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final lists = [fakeList('l1', 'Groceries')];
    final items = [
      fakeItem('a', 'Bananas', category: 'Produce', price: 1.29),
      fakeItem('b', 'Bread', category: 'Bakery', price: 3.49),
      fakeItem('c', 'Milk', category: 'Dairy & Eggs', price: 4.19),
      fakeItem('d', 'Eggs', category: 'Dairy & Eggs', price: 3.99, checked: true),
    ];

    final searchKey = GlobalKey();
    await pumpShopIt(
      tester,
      width: 1100,
      height: 760,
      lists: lists,
      items: items,
      pantry: [fakePantryItem('p', 'Yogurt')],
      history: [fakeHistory('h1', 'Oat milk', category: 'Dairy & Eggs')],
      themeMode: ThemeMode.dark,
      boundary: searchKey,
    );
    await tester.enterText(find.byType(TextField).first, 'mi');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _write(
      tester,
      File('${shotDir.path}/search.png'),
      await _boundaryPng(tester, searchKey),
    );

    final menuKey = GlobalKey();
    await pumpShopIt(
      tester,
      width: 1100,
      height: 820,
      lists: lists,
      items: items,
      themeMode: ThemeMode.dark,
      boundary: menuKey,
    );
    await tester.tap(find.byTooltip('List options'));
    await tester.pumpAndSettle();
    await _write(
      tester,
      File('${shotDir.path}/menu.png'),
      await _boundaryPng(tester, menuKey),
    );

    final pantryKey = GlobalKey();
    await pumpShopIt(
      tester,
      width: 1100,
      height: 760,
      lists: lists,
      items: items,
      pantry: [
        fakePantryItem(
          'a',
          'Yogurt',
          expiryDate: start.add(const Duration(days: 2)),
        ),
        fakePantryItem(
          'b',
          'Milk',
          expiryDate: start.subtract(const Duration(days: 1)),
        ),
      ],
      themeMode: ThemeMode.dark,
      boundary: pantryKey,
    );
    await tester.tap(find.byTooltip('Go to Pantry'));
    await tester.pumpAndSettle();
    await _write(
      tester,
      File('${shotDir.path}/pantry.png'),
      await _boundaryPng(tester, pantryKey),
    );
  });
}

Future<Uint8List> _pngOf(
  WidgetTester tester, {
  required double width,
  required double height,
  required Widget child,
}) async {
  final key = GlobalKey();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Center(
      child: RepaintBoundary(
        key: key,
        child: SizedBox(width: width, height: height, child: child),
      ),
    ),
  );
  await tester.pump();
  return _boundaryPng(tester, key, pixelRatio: 2);
}

Future<Uint8List> _boundaryPng(
  WidgetTester tester,
  GlobalKey key, {
  double pixelRatio = 2,
}) async {
  final bytes = await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

Future<void> _write(WidgetTester tester, File file, Uint8List bytes) async {
  final temp = File('${file.path}.part');
  await tester.runAsync(() async {
    await temp.writeAsBytes(bytes, flush: true);
    if (file.existsSync()) file.deleteSync();
    temp.renameSync(file.path);
  });
  expect(file.existsSync(), isTrue);
  expect(file.lengthSync(), greaterThan(200));
}

Future<void> _loadRoboto() async {
  Future<ByteData> font(String path) async {
    final bytes = await File(path).readAsBytes();
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }

  final loader = FontLoader('Roboto')
    ..addFont(font('assets/fonts/roboto-regular.ttf'))
    ..addFont(font('assets/fonts/roboto-medium.ttf'))
    ..addFont(font('assets/fonts/roboto-bold.ttf'));
  await loader.load();
}
