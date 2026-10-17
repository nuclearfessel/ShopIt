import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shop_it/data/database.dart';
import 'package:shop_it/features/catalog/resolve_barcode.dart';
import 'package:shop_it/services/product_lookup.dart';

void main() {
  test('Open Food Facts JSON becomes a product name', () async {
    final lookup = ProductLookup(
      client: MockClient((request) async {
        expect(request.url.path, contains('3017620422003'));
        return http.Response(
          jsonEncode({
            'status': 1,
            'product': {
              'product_name': 'Nutella',
              'categories_tags': ['en:spreads', 'en:chocolate-spreads'],
            },
          }),
          200,
        );
      }),
    );
    final hit = await lookup.lookup('3017620422003');
    expect(hit?.name, 'Nutella');
    expect(hit?.category, 'Snacks');
  });

  test('a missing product needs a name', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final lookup = ProductLookup(
      client: MockClient((request) async => http.Response('{"status":0}', 200)),
    );
    final resolved = await resolveBarcode(db, '000', lookup: lookup);
    expect(resolved.needsName, isTrue);
    expect(resolved.name, isEmpty);
  });

  test('a known barcode skips the lookup', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await db.linkBarcode('111', 'Milk', category: 'Dairy & Eggs');
    var called = false;
    final lookup = ProductLookup(
      client: MockClient((request) async {
        called = true;
        return http.Response('{"status":0}', 200);
      }),
    );
    final resolved = await resolveBarcode(db, '111', lookup: lookup);
    expect(called, isFalse);
    expect(resolved.name, 'Milk');
    expect(resolved.needsName, isFalse);
  });
}
