/// One drawing in a Keyline icon, as SVG path data on a 24x24 grid.
class KeylinePath {
  const KeylinePath(
    this.d, {
    this.fill = false,
    this.stroke = true,
    this.evenOdd = false,
  });

  /// SVG path data (the `d` attribute).
  final String d;

  /// Filled with the icon colour (used for dots and solid shapes).
  final bool fill;

  /// Outlined with the icon colour at the stroke weight.
  final bool stroke;

  /// Fill rule is even-odd rather than non-zero.
  final bool evenOdd;
}

/// A Keyline icon: a name and the paths that draw it.
class KeylineIconData {
  const KeylineIconData(this.name, this.paths);

  final String name;
  final List<KeylinePath> paths;
}
