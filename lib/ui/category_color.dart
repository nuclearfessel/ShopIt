import 'package:flutter/material.dart';

/// The color a category header gets when the user has not chosen one: stable
/// for a given name, and light enough on dark themes / dark enough on light
/// ones to read.
Color automaticCategoryColor(String name, Brightness brightness) {
  final hue =
      (name.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0xFFFF) % 360)
          .toDouble();
  return HSLColor.fromAHSL(
    1,
    hue,
    0.5,
    brightness == Brightness.dark ? 0.62 : 0.42,
  ).toColor();
}
