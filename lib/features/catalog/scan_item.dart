import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../services/barcode_scanner.dart';
import '../../services/product_lookup.dart';
import '../../ui/keyline/keyline_icon.dart';
import '../../ui/tip.dart';
import 'item_editor.dart';
import 'resolve_barcode.dart';

/// Android-only scan button for the search field.
class ScanItemButton extends StatelessWidget {
  const ScanItemButton({super.key, required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return const SizedBox.shrink();
    return Tip(
      'Scan a barcode',
      child: IconButton(
        tooltip: 'Scan a barcode',
        icon: const KeylineIcon(KeylineIcons.scanBarcode),
        onPressed: onScan,
      ),
    );
  }
}

Future<BarcodeResolve?> scanAndResolve(
  BuildContext context,
  AppDatabase db, {
  BarcodeScanner? scanner,
  ProductLookup? lookup,
}) async {
  final code = await (scanner ?? barcodeScanner).scan();
  if (code == null) return null;
  return resolveBarcode(db, code, lookup: lookup);
}

/// Asks for a name when the barcode is not in the catalog and has no lookup.
Future<ItemEdit?> nameUnknownBarcode(
  BuildContext context, {
  required String barcode,
  required List<String> categories,
}) async {
  final result = await showItemEditor(
    context,
    title: 'Scanned item',
    isNew: true,
    showPrice: false,
    categories: categories.isEmpty ? null : categories,
    initial: ItemEdit(name: '', note: barcode, category: 'Other'),
  );
  if (result is ItemSaved && result.edit.name.trim().isNotEmpty) {
    return result.edit;
  }
  return null;
}
