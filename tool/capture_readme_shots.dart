import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shop_it/app/form_factor.dart';
import 'package:shop_it/data/database.dart';

import '../test/support/harness.dart';

/// One-shot: `flutter test tool/capture_readme_shots.dart`
/// Writes a screenshot of each platform into docs/screenshots/.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _loadRoboto();
  });

  testWidgets('capture readme screenshots', (tester) async {
    final lists = [fakeList('l1', 'Groceries')];
    final items = [
      fakeItem('a', 'Bananas', category: 'Produce', price: 1.29),
      fakeItem('b', 'Bread', category: 'Bakery', price: 3.49),
      fakeItem('c', 'Milk', category: 'Dairy & Eggs', price: 4.19),
      fakeItem('d', 'Eggs', category: 'Dairy & Eggs', price: 3.99, checked: true),
      fakeItem('e', 'Butter', category: 'Dairy & Eggs', price: 5.49),
    ];
    final categories = [
      Category(name: 'Produce', sortOrder: 0, color: 0xFF4CAF50),
      Category(name: 'Bakery', sortOrder: 1, color: 0xFFFFB300),
      Category(name: 'Dairy & Eggs', sortOrder: 2, color: 0xFF42A5F5),
    ];
    final outDir = Directory('docs/screenshots')..createSync(recursive: true);

    Future<void> shot({
      required String name,
      required double width,
      required double height,
      required bool scan,
    }) async {
      debugPlatformScansBarcodes = scan;
      final key = GlobalKey();
      await pumpShopIt(
        tester,
        width: width,
        height: height,
        lists: lists,
        items: items,
        categories: categories,
        themeMode: ThemeMode.dark,
        boundary: key,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final bytes = await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      final temp = File('${outDir.path}/$name.part');
      final file = File('${outDir.path}/$name');
      await tester.runAsync(() async {
        await temp.writeAsBytes(bytes!, flush: true);
        if (file.existsSync()) {
          try {
            file.deleteSync();
          } on FileSystemException {
            // Windows may keep the old preview open; overwrite via rename.
          }
        }
        temp.renameSync(file.path);
      });
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(20000));
    }

    await shot(name: 'windows.png', width: 1200, height: 760, scan: false);
    await shot(name: 'macos.png', width: 1440, height: 900, scan: false);
    await shot(name: 'android.png', width: 412, height: 915, scan: true);
    await shot(
      name: 'android-tablet.png',
      width: 1280,
      height: 800,
      scan: true,
    );
    await shot(name: 'iphone.png', width: 393, height: 852, scan: true);
    await shot(name: 'ipad.png', width: 1194, height: 834, scan: true);
    debugPlatformScansBarcodes = null;
  });
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
