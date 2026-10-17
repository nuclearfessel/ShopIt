import 'dart:io' show Platform;
import 'dart:math' show min;

import 'package:flutter/widgets.dart';

/// A phone is a window whose shortest side is under this. Tablets and desktop
/// windows are large, even when the width alone is under the settings dialog.
const phoneShortestSide = 600.0;

/// True when [size] is a phone rather than a tablet or desktop window.
bool isPhoneSize(Size size) =>
    min(size.width, size.height) < phoneShortestSide;

/// True when the current view is phone-sized. Used before a widget exists,
/// for the portrait lock and the name announced to another device.
bool hostIsPhone() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return Platform.isAndroid || Platform.isIOS;
  final view = views.first;
  final shortest =
      min(view.physicalSize.width, view.physicalSize.height) /
      view.devicePixelRatio;
  return shortest < phoneShortestSide;
}

/// Widget screenshots set this so a desktop test host can show the camera
/// button. Production leaves it null.
bool? debugPlatformScansBarcodes;

/// Android and iOS have a camera. Windows and Mac do not scan.
bool get platformScansBarcodes =>
    debugPlatformScansBarcodes ?? (Platform.isAndroid || Platform.isIOS);
