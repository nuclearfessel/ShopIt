import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:shop_it/ui/keyline/keyline_icon.dart';

import 'support/harness.dart';

const _white = (r: 255, g: 255, b: 255);

/// Renders [icon] in a tight [box] x [box] white square and returns its pixels.
Future<Shot> _render(
  WidgetTester tester,
  Widget icon, {
  double box = 48,
  double pixelRatio = 1,
}) async {
  tester.view.devicePixelRatio = pixelRatio;
  tester.view.physicalSize = Size(box * pixelRatio * 2, box * pixelRatio * 2);
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: Colors.white,
            // A tight box, as some parents impose.
            child: SizedBox(width: box, height: box, child: icon),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return capture(tester, key, pixelRatio: pixelRatio);
}

/// Bounding box of the non-white pixels: (left, top, right, bottom), inclusive.
({int l, int t, int r, int b}) _inkBounds(Shot s) {
  var l = s.width, t = s.height, r = -1, b = -1;
  for (var y = 0; y < s.height; y++) {
    for (var x = 0; x < s.width; x++) {
      if (s.ink(x, y, _white) > 0.12) {
        if (x < l) l = x;
        if (x > r) r = x;
        if (y < t) t = y;
        if (y > b) b = y;
      }
    }
  }
  return (l: l, t: t, r: r, b: b);
}

double _totalInk(Shot s) {
  var sum = 0.0;
  for (var y = 0; y < s.height; y++) {
    for (var x = 0; x < s.width; x++) {
      sum += s.ink(x, y, _white);
    }
  }
  return sum;
}

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
    testWidgets('takes its colour from the icon theme', (tester) async {
      final shot = await _render(
        tester,
        const IconTheme(
          data: IconThemeData(color: Color(0xFFFF0000), size: 24),
          child: KeylineIcon(KeylineIcons.x),
        ),
      );
      // Somewhere the strokes cross, the pixel is solid red.
      var solidRed = false;
      for (var y = 0; y < shot.height && !solidRed; y++) {
        for (var x = 0; x < shot.width; x++) {
          final p = shot.at(x, y);
          if (p.r > 235 && p.g < 40 && p.b < 40) {
            solidRed = true;
            break;
          }
        }
      }
      expect(solidRed, isTrue);
    });

    testWidgets('an explicit colour wins over the icon theme', (tester) async {
      final shot = await _render(
        tester,
        const IconTheme(
          data: IconThemeData(color: Color(0xFFFF0000)),
          child: KeylineIcon(
            KeylineIcons.x,
            size: 24,
            color: Color(0xFF0000FF),
          ),
        ),
      );
      var blue = false, red = false;
      for (var y = 0; y < shot.height; y++) {
        for (var x = 0; x < shot.width; x++) {
          final p = shot.at(x, y);
          if (p.b > 235 && p.r < 40 && p.g < 40) blue = true;
          if (p.r > 200 && p.b < 100) red = true;
        }
      }
      expect(blue, isTrue);
      expect(red, isFalse);
    });

    testWidgets('a heavier stroke weight draws more ink', (tester) async {
      final thin = await _render(
        tester,
        const KeylineIcon(
          KeylineIcons.settings,
          size: 40,
          color: Colors.black,
          strokeWidth: 1,
        ),
      );
      final thick = await _render(
        tester,
        const KeylineIcon(
          KeylineIcons.settings,
          size: 40,
          color: Colors.black,
          strokeWidth: 3,
        ),
      );
      expect(_totalInk(thick), greaterThan(_totalInk(thin) * 1.8));
    });

    testWidgets('a larger forced box does not stretch the drawing', (
      tester,
    ) async {
      // The parent forces 48x48, but the icon is 16 and stays centred.
      final shot = await _render(
        tester,
        const KeylineIcon(KeylineIcons.x, size: 16, color: Colors.black),
      );
      final b = _inkBounds(shot);
      expect(b.r - b.l + 1, lessThanOrEqualTo(16));
      expect(b.b - b.t + 1, lessThanOrEqualTo(16));
      expect((b.l + b.r) / 2, closeTo(23.5, 1.5));
      expect((b.t + b.b) / 2, closeTo(23.5, 1.5));
    });

    testWidgets('solid shapes are filled and outlines are stroked', (
      tester,
    ) async {
      // "accessibility" has a filled dot (the head) at (12, 6.5) as well as
      // outlined paths.
      final shot = await _render(
        tester,
        const KeylineIcon(
          KeylineIcons.accessibility,
          size: 24,
          color: Colors.black,
        ),
        box: 24,
      );
      expect(shot.ink(12, 6, _white), greaterThan(0.9)); // the filled dot
      expect(shot.ink(2, 2, _white), lessThan(0.05)); // empty corner
      expect(_totalInk(shot), greaterThan(20)); // the outline is drawn too
    });

    testWidgets('edges are smooth: many shades, not a handful', (tester) async {
      // A diagonal-heavy icon at a small size, where coarse anti-aliasing shows
      // as stair-steps. Count the distinct shades along the edges.
      final shot = await _render(
        tester,
        const KeylineIcon(KeylineIcons.x, size: 24, color: Colors.black),
        box: 24,
      );
      final shades = <int>{};
      for (var y = 0; y < shot.height; y++) {
        for (var x = 0; x < shot.width; x++) {
          final p = shot.at(x, y);
          if (p.r > 5 && p.r < 250) shades.add(p.r);
        }
      }
      // Coarse 4x anti-aliasing gives only 3 shades between empty and solid.
      expect(shades.length, greaterThan(5));
    });

    testWidgets('draws at the screen\'s pixel size on a sharper display', (
      tester,
    ) async {
      const icon = KeylineIcon(KeylineIcons.x, size: 16, color: Colors.black);
      final normal = _inkBounds(await _render(tester, icon));
      final sharp = _inkBounds(await _render(tester, icon, pixelRatio: 2));
      // Same icon, twice the physical pixels (captured at 2x).
      final normalWidth = normal.r - normal.l + 1;
      final sharpWidth = sharp.r - sharp.l + 1;
      expect(normalWidth, greaterThan(4));
      expect(sharpWidth / normalWidth, closeTo(2, 0.35));
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
