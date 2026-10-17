import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/data/database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('new generic items and brands are searchable', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    final eggplant = await db.searchCatalog('eggplant');
    expect(eggplant.map((item) => item.name), contains('Eggplant'));

    final weet = await db.searchCatalog('weet');
    expect(weet.map((item) => item.name), contains('Weetabix'));
    expect(
      weet.firstWhere((item) => item.name == 'Weetabix').parentName,
      'Cereal',
    );
  });

  test('a parent query does not list every brand', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    final cereal = await db.searchCatalog('cereal');
    final unmatched = cereal.where(
      (item) =>
          item.parentName == 'Cereal' &&
          !item.name.toLowerCase().contains('cereal'),
    );
    expect(unmatched.length, lessThanOrEqualTo(8));
    expect(cereal.map((item) => item.name), isNot(contains('Weetabix')));
    expect(
      (await db.searchCatalog('weetabix')).map((item) => item.name),
      contains('Weetabix'),
    );
  });

  test('upgrading adds missing built-ins without duplicating names', () async {
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'shopit-catalog-${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });

    final first = AppDatabase(NativeDatabase(file));
    await first.customSelect('select 1').get();
    await (first.delete(first.catalogItems)
          ..where((t) => t.name.equals('Weetabix')))
        .go();
    await first.into(first.catalogItems).insert(
      CatalogItemsCompanion.insert(
        name: 'Kombucha',
        category: 'Beverages',
        isCustom: const Value(true),
      ),
    );
    final milkBefore = await (first.select(first.catalogItems)
          ..where((t) => t.name.equals('Milk')))
        .get();
    expect(milkBefore, hasLength(1));
    await first.customStatement('PRAGMA user_version = 10');
    await first.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    await upgraded.customSelect('select 1').get();

    final rows = await (upgraded.select(upgraded.catalogItems)..where(
      (t) =>
          t.name.equals('Milk') |
          t.name.equals('Weetabix') |
          t.name.equals('Kombucha'),
    )).get();
    expect(rows.where((row) => row.name == 'Milk'), hasLength(1));
    expect(rows.where((row) => row.name == 'Weetabix'), hasLength(1));
    expect(rows.singleWhere((row) => row.name == 'Kombucha').isCustom, isTrue);
  });
}
