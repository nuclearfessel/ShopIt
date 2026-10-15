import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import 'keyline_icon_data.dart';

export 'keyline_icon_data.dart';
export 'keyline_icons.g.dart';

/// Stroke weight for every icon in the app, in the icon grid's units (the
/// Keyline set is drawn at 2 on a 24 grid). Lower is lighter; change it here to
/// restyle all icons at once.
const double kKeylineStrokeWidth = 1.75;

/// Draws a [KeylineIconData] like Flutter's own `Icon`: size and colour come
/// from the surrounding [IconTheme] (so buttons, navigation and the app theme
/// colour it) unless given.
///
/// Icons are drawn smoothly: each one is rendered at four times its pixel size
/// and averaged down to the screen's pixels. Drawing thin strokes straight onto
/// the screen gives only a handful of edge shades on renderers that use coarse
/// anti-aliasing (visible as jagged diagonals), which this avoids without
/// making the icon any bigger.
class KeylineIcon extends StatelessWidget {
  const KeylineIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.strokeWidth,
    this.semanticLabel,
  });

  final KeylineIconData icon;
  final double? size;
  final Color? color;

  /// Overrides [kKeylineStrokeWidth] for this icon.
  final double? strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final dimension = size ?? theme.size ?? 24.0;
    var paint = color ?? theme.color ?? Theme.of(context).colorScheme.onSurface;
    final opacity = theme.opacity;
    if (opacity != null && opacity != 1) {
      paint = paint.withValues(alpha: paint.a * opacity);
    }
    final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    return Semantics(
      label: semanticLabel,
      image: true,
      child: ExcludeSemantics(
        // Like Flutter's own Icon: a box of the icon's size whose drawing stays
        // that size and centred even when a parent forces a larger tight box
        // (a Container with a width, an input's prefix icon, ...).
        child: SizedBox.square(
          dimension: dimension,
          child: Center(
            child: SizedBox.square(
              dimension: dimension,
              child: CustomPaint(
                painter: _KeylinePainter(
                  icon,
                  paint,
                  strokeWidth ?? kKeylineStrokeWidth,
                  pixelRatio,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Path parsing --------------------------------------------------------

/// Parsed paths, cached: parsing SVG path data is the costly part.
final Map<KeylinePath, Path> _parsed = {};

Path _pathFor(KeylinePath p) => _parsed.putIfAbsent(p, () {
  final path = parseSvgPathData(p.d);
  path.fillType = p.evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;
  return path;
});

// ---- Smooth rasterising --------------------------------------------------

/// Render at this many times the pixel size, then halve twice.
const int _kSupersample = 4;

class _MaskKey {
  const _MaskKey(this.icon, this.pixels, this.stroke);

  final KeylineIconData icon;
  final int pixels;

  /// Stroke weight in hundredths, so equal weights share an image.
  final int stroke;

  @override
  bool operator ==(Object other) =>
      other is _MaskKey &&
      other.icon == icon &&
      other.pixels == pixels &&
      other.stroke == stroke;

  @override
  int get hashCode => Object.hash(icon, pixels, stroke);
}

/// White-on-transparent coverage masks, one per icon/size/weight, at exactly the
/// device pixel size. Oldest are dropped past the limit.
final Map<_MaskKey, ui.Image> _masks = {};
const int _kMaxMasks = 256;

ui.Image _maskFor(KeylineIconData icon, int pixels, double strokeWidth) {
  final key = _MaskKey(icon, pixels, (strokeWidth * 100).round());
  final cached = _masks.remove(key);
  if (cached != null) {
    _masks[key] = cached; // most recently used goes last
    return cached;
  }
  final image = _renderMask(icon, pixels, strokeWidth);
  _masks[key] = image;
  while (_masks.length > _kMaxMasks) {
    // Dropped, not disposed: a picture drawn this frame may still hold it.
    _masks.remove(_masks.keys.first);
  }
  return image;
}

ui.Image _renderMask(KeylineIconData icon, int pixels, double strokeWidth) {
  final big = pixels * _kSupersample;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(big / 24);
  const white = Color(0xFFFFFFFF);
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = white
    ..isAntiAlias = true;
  final fill = Paint()
    ..style = PaintingStyle.fill
    ..color = white
    ..isAntiAlias = true;
  for (final p in icon.paths) {
    final path = _pathFor(p);
    if (p.fill) canvas.drawPath(path, fill);
    if (p.stroke) canvas.drawPath(path, stroke);
  }
  var image = recorder.endRecording().toImageSync(big, big);

  // Halve until we are at the pixel size. Each halving samples exactly between
  // four source pixels with linear filtering, which is a perfect 2x2 average,
  // so 4x -> 2x -> 1x averages 16 samples per screen pixel.
  var size = big;
  while (size > pixels) {
    final next = size ~/ 2;
    final r = ui.PictureRecorder();
    Canvas(r).drawImageRect(
      image,
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      Rect.fromLTWH(0, 0, next.toDouble(), next.toDouble()),
      Paint()..filterQuality = FilterQuality.low,
    );
    final smaller = r.endRecording().toImageSync(next, next);
    image.dispose();
    image = smaller;
    size = next;
  }
  return image;
}

class _KeylinePainter extends CustomPainter {
  const _KeylinePainter(
    this.icon,
    this.color,
    this.strokeWidth,
    this.pixelRatio,
  );

  final KeylineIconData icon;
  final Color color;
  final double strokeWidth;
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final pixels = (size.width * pixelRatio).round().clamp(1, 1024);
    final mask = _maskFor(icon, pixels, strokeWidth);
    canvas.drawImageRect(
      mask,
      Rect.fromLTWH(0, 0, pixels.toDouble(), pixels.toDouble()),
      Offset.zero & size,
      Paint()
        ..filterQuality = FilterQuality.low
        ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  @override
  bool shouldRepaint(_KeylinePainter old) =>
      old.icon != icon ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.pixelRatio != pixelRatio;
}
