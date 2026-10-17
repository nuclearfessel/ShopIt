import 'dart:io';

import 'package:flutter/services.dart';

/// Opens the Android camera to read one product barcode.
///
/// Returns the digits, or null if the user cancelled or this is not Android.
class BarcodeScanner {
  BarcodeScanner({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('shop_it/barcode');

  final MethodChannel _channel;

  Future<String?> scan() async {
    if (!Platform.isAndroid) return null;
    try {
      final code = await _channel.invokeMethod<String>('scan');
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
