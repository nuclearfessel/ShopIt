import 'package:flutter/services.dart';

import '../app/form_factor.dart';

/// Opens the phone or tablet camera to read one product barcode.
///
/// Returns the digits, or null if the user cancelled or this is Windows or Mac.
class BarcodeScanner {
  BarcodeScanner({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('shop_it/barcode');

  final MethodChannel _channel;

  /// [sync] reads the QR code from the computer. Otherwise this reads a
  /// product barcode.
  Future<String?> scan({bool sync = false}) async {
    if (!platformScansBarcodes) return null;
    try {
      final code = await _channel.invokeMethod<String>('scan', {
        'portrait': hostIsPhone(),
        'sync': sync,
      });
      final trimmed = code?.trim() ?? '';
      return trimmed.isEmpty ? null : trimmed;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

/// Shared scanner used by Shopping and Pantry.
final barcodeScanner = BarcodeScanner();
