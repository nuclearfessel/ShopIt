import '../../data/database.dart';
import '../../services/product_lookup.dart';

/// What a scan should add, after checking the catalog and a product lookup.
class BarcodeResolve {
  const BarcodeResolve({
    required this.barcode,
    this.name = '',
    this.category = 'Other',
    this.needsName = false,
  });

  final String barcode;
  final String name;
  final String category;
  final bool needsName;
}

Future<BarcodeResolve> resolveBarcode(
  AppDatabase db,
  String barcode, {
  ProductLookup? lookup,
}) async {
  final code = barcode.trim();
  final known = await db.catalogByBarcode(code);
  if (known != null) {
    return BarcodeResolve(
      barcode: code,
      name: known.name,
      category: known.category,
    );
  }
  final hit = await (lookup ?? ProductLookup()).lookup(code);
  if (hit != null) {
    final match = (await db.searchCatalog(hit.name))
        .where((item) => item.name.toLowerCase() == hit.name.toLowerCase())
        .toList();
    final name = match.isEmpty ? hit.name : match.first.name;
    final category = match.isEmpty ? hit.category : match.first.category;
    await db.linkBarcode(code, name, category: category);
    return BarcodeResolve(barcode: code, name: name, category: category);
  }
  return BarcodeResolve(barcode: code, needsName: true);
}
