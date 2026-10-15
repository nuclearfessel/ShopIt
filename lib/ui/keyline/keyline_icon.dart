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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Parsed paths, cached per icon: parsing SVG path data is the costly part.
final Map<KeylinePath, Path> _parsed = {};

Path _pathFor(KeylinePath p) => _parsed.putIfAbsent(p, () {
  final path = parseSvgPathData(p.d);
  path.fillType = p.evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;
  return path;
});

class _KeylinePainter extends CustomPainter {
  const _KeylinePainter(this.icon, this.color, this.strokeWidth);

  final KeylineIconData icon;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color
      ..isAntiAlias = true;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..isAntiAlias = true;
    for (final p in icon.paths) {
      final path = _pathFor(p);
      if (p.fill) canvas.drawPath(path, fill);
      if (p.stroke) canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_KeylinePainter old) =>
      old.icon != icon || old.color != color || old.strokeWidth != strokeWidth;
}
