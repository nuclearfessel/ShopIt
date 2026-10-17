import 'dart:convert';

import 'package:http/http.dart' as http;

/// One product name from a barcode lookup.
class ProductHit {
  const ProductHit({required this.name, this.category = 'Other'});

  final String name;
  final String category;
}

/// Looks up a single barcode. The default source is Open Food Facts.
class ProductLookup {
  ProductLookup({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ProductHit?> lookup(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$code.json',
    );
    try {
      final response = await _client
          .get(
            uri,
            headers: const {
              'User-Agent': 'Shop-it/0.1 (grocery list; Android scan)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map) return null;
      if (body['status'] != 1) return null;
      final product = body['product'];
      if (product is! Map) return null;
      final name = _firstString(product, const [
        'product_name',
        'product_name_en',
        'generic_name',
        'generic_name_en',
      ]);
      if (name == null) return null;
      return ProductHit(name: name, category: _category(product));
    } on Object {
      return null;
    }
  }

  String? _firstString(Map<dynamic, dynamic> product, List<String> keys) {
    for (final key in keys) {
      final value = product[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    final brand = product['brands'];
    if (brand is String && brand.trim().isNotEmpty) return brand.trim();
    return null;
  }

  String _category(Map<dynamic, dynamic> product) {
    final tags = product['categories_tags'];
    if (tags is! List) return 'Other';
    final joined = tags.map((e) => e.toString().toLowerCase()).join(' ');
    if (joined.contains('dairy') || joined.contains('cheese') || joined.contains('yogurt') || joined.contains('milk')) {
      return 'Dairy & Eggs';
    }
    if (joined.contains('ice-cream') || joined.contains('frozen')) {
      return 'Frozen';
    }
    if (joined.contains('bread') || joined.contains('bakery')) return 'Bakery';
    if (joined.contains('beverage') || joined.contains('drink') || joined.contains('juice')) {
      return 'Beverages';
    }
    if (joined.contains('snack') || joined.contains('chocolate') || joined.contains('cookie')) {
      return 'Snacks';
    }
    if (joined.contains('cereal') || joined.contains('breakfast')) {
      return 'Breakfast & Cereal';
    }
    if (joined.contains('meat') || joined.contains('poultry')) {
      return 'Meat & Poultry';
    }
    if (joined.contains('fruit') || joined.contains('vegetable') || joined.contains('produce')) {
      return 'Produce';
    }
    return 'Other';
  }
}
