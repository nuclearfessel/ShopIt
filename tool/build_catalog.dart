import 'dart:convert';
import 'dart:io';

/// Reads assets/catalog.json and writes lib/data/catalog_seed.g.dart.
///
/// Run from the repo root: `dart run tool/build_catalog.dart`
void main() {
  final source = File('assets/catalog.json');
  if (!source.existsSync()) {
    stderr.writeln('Missing assets/catalog.json');
    exit(1);
  }
  final decoded = jsonDecode(source.readAsStringSync());
  if (decoded is! Map) {
    stderr.writeln('Catalog JSON must be an object of categories.');
    exit(1);
  }
  final buffer = StringBuffer()
    ..writeln('// Generated from assets/catalog.json by tool/build_catalog.dart.')
    ..writeln('// Do not edit by hand.')
    ..writeln()
    ..writeln('/// Built-in catalog: category, then generic item, then variants.')
    ..writeln('///')
    ..writeln('/// Variants are types, cuts, flavours, and the brand names people')
    ..writeln('/// type. Categories are shown alphabetically; this map order is')
    ..writeln('/// only how the file is generated.')
    ..writeln(
      'const Map<String, Map<String, List<String>>> catalogSeed = {',
    );

  for (final category in decoded.entries) {
    final name = category.key;
    final items = category.value;
    if (name is! String || name.trim().isEmpty || items is! Map) {
      stderr.writeln('Bad category: ${category.key}');
      exit(1);
    }
    buffer.writeln('  ${_dart(name)}: {');
    for (final item in items.entries) {
      final itemName = item.key;
      final variants = item.value;
      if (itemName is! String || itemName.trim().isEmpty || variants is! List) {
        stderr.writeln('Bad item under $name: ${item.key}');
        exit(1);
      }
      buffer.write('    ${_dart(itemName)}: [');
      if (variants.isEmpty) {
        buffer.writeln('],');
        continue;
      }
      buffer.writeln();
      for (final variant in variants) {
        if (variant is! String || variant.trim().isEmpty) {
          stderr.writeln('Bad variant under $name / $itemName');
          exit(1);
        }
        buffer.writeln('      ${_dart(variant)},');
      }
      buffer.writeln('    ],');
    }
    buffer.writeln('  },');
  }
  buffer.writeln('};');

  final out = File('lib/data/catalog_seed.g.dart');
  out.writeAsStringSync(buffer.toString());
  stdout.writeln('Wrote ${out.path}');
}

String _dart(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');
  return "'$escaped'";
}
