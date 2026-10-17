import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Black-on-white QR code. Theme colors are not used, so a camera can read it.
class SyncQrView extends StatelessWidget {
  const SyncQrView({super.key, required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SyncQrPainter(payload),
      child: const SizedBox.expand(),
    );
  }
}

class _SyncQrPainter extends CustomPainter {
  _SyncQrPainter(this.payload);

  final String payload;

  @override
  void paint(Canvas canvas, Size size) {
    final image = QrImage(QrCode(payload: QrPayload.fromString(payload)));
    const quiet = 4;
    final cells = image.moduleCount + quiet * 2;
    final module = size.shortestSide / cells;
    final left = (size.width - module * cells) / 2;
    final top = (size.height - module * cells) / 2;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final ink = Paint()..color = const Color(0xFF000000);
    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (!image.isDark(row, col)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            left + (col + quiet) * module,
            top + (row + quiet) * module,
            module + 0.5,
            module + 0.5,
          ),
          ink,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SyncQrPainter oldDelegate) =>
      oldDelegate.payload != payload;
}
