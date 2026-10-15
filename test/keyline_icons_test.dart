import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:shop_it/ui/keyline/keyline_icon.dart';

void main() {
  group('the icon set', () {
    test('contains the whole Keyline stroke set', () {
      expect(KeylineIcons.all.length, 1366);
      expect(KeylineIcons.all.map((i) => i.name).toSet().length, 1366);
    });

    test('every icon parses and stays on the 24x24 grid', () {
      for (final icon in KeylineIcons.all) {
        expect(icon.paths, isNotEmpty, reason: icon.name);
        for (final p in icon.paths) {
          // A zero-length line is a dot (round caps), so empty bounds are fine.
          final bounds = parseSvgPathData(p.d).getBounds();
          expect(bounds.left, greaterThanOrEqualTo(-1), reason: icon.name);
          expect(bounds.top, greaterThanOrEqualTo(-1), reason: icon.name);
          expect(bounds.right, lessThanOrEqualTo(25), reason: icon.name);
          expect(bounds.bottom, lessThanOrEqualTo(25), reason: icon.name);
        }
      }
    });

    test('icons the app uses exist', () {
      for (final icon in [
        KeylineIcons.settings,
        KeylineIcons.shoppingCart,
        KeylineIcons.archive,
        KeylineIcons.bin,
        KeylineIcons.pen,
        KeylineIcons.plus,
        KeylineIcons.minus,
        KeylineIcons.x,
        KeylineIcons.sun,
        KeylineIcons.moon,
        KeylineIcons.monitor,
      ]) {
        expect(icon.paths, isNotEmpty, reason: icon.name);
      }
    });
  });

  group('the widget', () {
    testWidgets('takes its size and colour from the icon theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: IconTheme(
              data: const IconThemeData(color: Color(0xFF86AA12), size: 40),
              child: const KeylineIcon(KeylineIcons.settings),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(KeylineIcon)), const Size(40, 40));
      final paint = tester.renderObject(
        find.descendant(
          of: find.byType(KeylineIcon),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(paint, paints..path(color: const Color(0xFF86AA12)));
    });

    testWidgets('explicit size and colour win; stroke weight is applied', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: KeylineIcon(
              KeylineIcons.x,
              size: 20,
              color: Color(0xFFFF0000),
              strokeWidth: 1.25,
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(KeylineIcon)), const Size(20, 20));
      final paint = tester.renderObject(
        find.descendant(
          of: find.byType(KeylineIcon),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(
        paint,
        paints..path(color: const Color(0xFFFF0000), strokeWidth: 1.25),
      );
    });

    testWidgets('a larger forced box does not stretch the drawing', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 48,
              height: 48,
              child: KeylineIcon(KeylineIcons.x, size: 16),
            ),
          ),
        ),
      );
      // Tight 48x48 box from the parent, but the drawing is 16x16 and centred.
      final painted = tester.getSize(
        find.descendant(
          of: find.byType(KeylineIcon),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(painted, const Size(16, 16));
      expect(
        tester.getCenter(
          find.descendant(
            of: find.byType(KeylineIcon),
            matching: find.byType(CustomPaint),
          ),
        ),
        tester.getCenter(find.byType(SizedBox).first),
      );
    });

    testWidgets('solid shapes are filled, outlines are stroked', (
      tester,
    ) async {
      // "accessibility" has a filled dot as well as outlined paths.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: KeylineIcon(
              KeylineIcons.accessibility,
              color: Color(0xFF00AA00),
            ),
          ),
        ),
      );
      final paint = tester.renderObject(
        find.descendant(
          of: find.byType(KeylineIcon),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(
        paint,
        paints
          ..path(style: PaintingStyle.stroke)
          ..path(style: PaintingStyle.fill),
      );
    });
  });

  test('nothing in the UI code still uses Material icons', () {
    // Framework widgets keep their built-in glyphs (checkbox tick, dropdown
    // arrow), but our own code should not reference Icons.* any more.
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is File && f.path.endsWith('.dart')) {
        final text = f.readAsStringSync();
        if (RegExp(r'\bIcons\.\w+').hasMatch(text)) hits.add(f.path);
      }
    }
    expect(hits, isEmpty);
  });
}
