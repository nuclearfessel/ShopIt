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

  test(
    'regular, East Asian, Southeast Asian, and South Asian produce search',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final bananas = await db.searchCatalog('regular bananas');
      expect(bananas.map((item) => item.name), contains('Regular bananas'));
      expect(
        bananas.firstWhere((item) => item.name == 'Regular bananas').parentName,
        'Bananas',
      );

      final nonOrganic = await db.searchCatalog('non-organic spinach');
      expect(
        nonOrganic.map((item) => item.name),
        contains('Non-organic spinach'),
      );

      final shiso = await db.searchCatalog('shiso');
      expect(shiso.map((item) => item.name), contains('Shiso'));
      expect(
        shiso.firstWhere((item) => item.name == 'Shiso').parentName,
        'East Asian herbs',
      );

      final thaiBasil = await db.searchCatalog('thai basil');
      expect(thaiBasil.map((item) => item.name), contains('Thai basil'));
      expect(
        thaiBasil.firstWhere((item) => item.name == 'Thai basil').parentName,
        'Southeast Asian herbs',
      );

      final curry = await db.searchCatalog('curry leaves');
      expect(curry.map((item) => item.name), contains('Curry leaves'));
      expect(
        curry.firstWhere((item) => item.name == 'Curry leaves').parentName,
        'South Asian herbs',
      );

      final bitter = await db.searchCatalog('bitter melon');
      expect(bitter.map((item) => item.name), contains('Bitter melon'));

      final drumstick = await db.searchCatalog('drumstick');
      expect(drumstick.map((item) => item.name), contains('Drumsticks'));

      final kkaennip = await db.searchCatalog('kkaennip');
      expect(kkaennip.map((item) => item.name), contains('Kkaennip'));

      final daunSalam = await db.searchCatalog('daun salam');
      expect(daunSalam.map((item) => item.name), contains('Daun salam'));

      final gongura = await db.searchCatalog('gongura');
      expect(gongura.map((item) => item.name), contains('Gongura'));

      final alphonso = await db.searchCatalog('alphonso');
      expect(alphonso.map((item) => item.name), contains('Alphonso mango'));

      final mangosteen = await db.searchCatalog('mangosteen');
      expect(mangosteen.map((item) => item.name), contains('Mangosteen SEA'));

      final yuzu = await db.searchCatalog('yuzu fruit');
      expect(yuzu.map((item) => item.name), contains('Yuzu fruit'));
    },
  );

  test('Ghirardelli, Tillamook, and ice cream brands are searchable', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    final ghirardelli = await db.searchCatalog('ghirardelli');
    expect(
      ghirardelli.map((item) => item.name),
      containsAll([
        'Ghirardelli chips',
        'Ghirardelli squares',
        'Ghirardelli brownie mix',
        'Ghirardelli hot chocolate',
      ]),
    );

    final tillamook = await db.searchCatalog('tillamook');
    expect(
      tillamook.map((item) => item.name),
      containsAll([
        'Tillamook cheddar',
        "Tillamook Maker's Reserve",
        'Tillamook ice cream',
        'Tillamook marionberry pie',
        'Tillamook extra creamy salted butter',
        'Tillamook extra creamy unsalted butter',
      ]),
    );

    final organic = await db.searchCatalog('organic valley');
    expect(
      organic.map((item) => item.name),
      containsAll([
        'Organic Valley whole milk',
        'Organic Valley sharp cheddar',
        'Organic Valley salted butter',
        'Organic Valley sour cream',
        'Organic Valley ghee',
        'Organic Valley string cheese',
      ]),
    );

    final haagen = await db.searchCatalog('haagen');
    expect(
      haagen.map((item) => item.name),
      containsAll([
        'Haagen-Dazs vanilla',
        'Haagen-Dazs butter pecan',
        'Haagen-Dazs matcha',
      ]),
    );

    final ben = await db.searchCatalog('jerry');
    expect(
      ben.map((item) => item.name),
      containsAll([
        "Ben & Jerry's Cherry Garcia",
        "Ben & Jerry's Chunky Monkey",
        "Ben & Jerry's The Tonight Dough",
      ]),
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
    await (first.delete(
      first.catalogItems,
    )..where((t) => t.name.equals('Weetabix'))).go();
    await first
        .into(first.catalogItems)
        .insert(
          CatalogItemsCompanion.insert(
            name: 'Kombucha',
            category: 'Beverages',
            isCustom: const Value(true),
          ),
        );
    final milkBefore = await (first.select(
      first.catalogItems,
    )..where((t) => t.name.equals('Milk'))).get();
    expect(milkBefore, hasLength(1));
    await first.customStatement('PRAGMA user_version = 10');
    await first.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    await upgraded.customSelect('select 1').get();

    final rows =
        await (upgraded.select(upgraded.catalogItems)..where(
              (t) =>
                  t.name.equals('Milk') |
                  t.name.equals('Weetabix') |
                  t.name.equals('Kombucha'),
            ))
            .get();
    expect(rows.where((row) => row.name == 'Milk'), hasLength(1));
    expect(rows.where((row) => row.name == 'Weetabix'), hasLength(1));
    expect(rows.singleWhere((row) => row.name == 'Kombucha').isCustom, isTrue);
  });
}
