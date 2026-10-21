import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_it/app/form_factor.dart';
import 'package:shop_it/data/database.dart';
import 'package:shop_it/data/device_sync.dart';
import 'package:shop_it/data/providers.dart';
import 'package:shop_it/features/settings/device_link_dialog.dart';
import 'package:shop_it/features/settings/settings_dialog.dart';
import 'package:shop_it/services/device_link.dart';

/// What the real link does: the client sends its lists, the host merges them,
/// then the client merges whatever the host sends back.
Future<void> exchange(AppDatabase host, AppDatabase client) async {
  await host.applySnapshot(await client.exportSnapshot());
  await client.applySnapshot(await host.exportSnapshot());
}

Future<List<String>> shoppingNames(AppDatabase db) async {
  final rows = await (db.select(
    db.shoppingLists,
  )..where((t) => t.deletedAt.isNull() & t.kind.equals('shopping'))).get();
  return [for (final row in rows) row.name];
}

Future<List<String>> pantryNames(AppDatabase db) async {
  final rows = await (db.select(
    db.shoppingLists,
  )..where((t) => t.deletedAt.isNull() & t.kind.equals('pantry'))).get();
  return [for (final row in rows) row.name];
}

Future<void> stamp(AppDatabase db, String id, DateTime at, String name) {
  return db.customUpdate(
    'UPDATE shopping_lists SET name = ?, updated_at = ? WHERE id = ?',
    variables: [
      Variable.withString(name),
      Variable.withDateTime(at),
      Variable.withString(id),
    ],
    updates: {db.shoppingLists},
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase host;
  late AppDatabase client;

  setUp(() {
    host = AppDatabase.memory();
    client = AppDatabase.memory();
  });

  tearDown(() async {
    await host.close();
    await client.close();
  });

  test('a list added on either device shows up on the other', () async {
    await client.addList('From the phone');
    await exchange(host, client);
    expect(await shoppingNames(host), contains('From the phone'));

    await host.addList('From the computer');
    await exchange(host, client);
    expect(await shoppingNames(client), contains('From the computer'));
    expect(await shoppingNames(host), contains('From the phone'));
  });

  test(
    'same grocery list name becomes one list with the other device\'s items',
    () async {
      // Each database already has a seeded "Groceries" list. Syncing folds them
      // into one list and replaces this device's items with the other device's.
      final phoneList = await client.addList('Groceries');
      await client.addShoppingItem(phoneList, 'Milk');
      await client.addShoppingItem(phoneList, 'Bread');

      final computerList = await host.addList('Groceries');
      await host.addShoppingItem(computerList, 'Eggs');
      await host.addShoppingItem(computerList, 'Milk');

      await exchange(host, client);

      expect(await shoppingNames(host), ['Groceries']);
      expect(await shoppingNames(client), ['Groceries']);

      Future<List<String>> itemNames(AppDatabase db) async {
        final lists =
            await (db.select(db.shoppingLists)..where(
                  (t) => t.deletedAt.isNull() & t.kind.equals('shopping'),
                ))
                .get();
        expect(lists, hasLength(1));
        final items =
            await (db.select(db.shoppingItems)..where(
                  (t) =>
                      t.deletedAt.isNull() & t.listId.equals(lists.single.id),
                ))
                .get();
        return [for (final item in items) item.name]..sort();
      }

      // The phone's list is applied first, so both devices end with the phone's
      // two items. The computer's Eggs are gone.
      expect(await itemNames(host), ['Bread', 'Milk']);
      expect(await itemNames(client), ['Bread', 'Milk']);
    },
  );

  test('applying a shopping list replaces local-only names', () async {
    final phone = await client.watchLists().first;
    final phoneId = phone.single.id;
    await client.addShoppingItem(phoneId, 'Milk');
    await client.addShoppingItem(phoneId, 'Bread');

    final computer = await host.watchLists().first;
    final computerId = computer.single.id;
    await host.addShoppingItem(computerId, 'Eggs');
    await host.addShoppingItem(computerId, 'Butter');

    await host.applySnapshot(await client.exportSnapshot());

    final items = await (host.select(
      host.shoppingItems,
    )..where((t) => t.deletedAt.isNull())).get();
    expect([for (final item in items) item.name]..sort(), ['Bread', 'Milk']);
  });

  test('an empty remote shopping list does not wipe local items', () async {
    // Windows creates the household with an empty Groceries list. Android joins,
    // adds items, then receives the empty Windows snapshot again. Those items
    // must stay.
    final phone = await client.watchLists().first;
    final phoneId = phone.single.id;
    await client.addShoppingItem(phoneId, 'Milk');
    await client.addShoppingItem(phoneId, 'Bread');
    await client.addShoppingItem(phoneId, 'Rice');

    await client.applySnapshot(await host.exportSnapshot());

    final items = await (client.select(
      client.shoppingItems,
    )..where((t) => t.deletedAt.isNull())).get();
    expect([for (final item in items) item.name]..sort(), [
      'Bread',
      'Milk',
      'Rice',
    ]);
  });

  test('an empty remote pantry list does not wipe local items', () async {
    final phonePantry = (await client.watchPantryLists().first).first;
    await client.addPantryItem('Rice', listId: phonePantry.id);
    await client.addPantryItem('Beans', listId: phonePantry.id);

    await client.applySnapshot(await host.exportSnapshot());

    final items =
        await (client.select(client.pantryItems)..where(
              (t) => t.deletedAt.isNull() & t.listId.equals(phonePantry.id),
            ))
            .get();
    expect([for (final item in items) item.name]..sort(), ['Beans', 'Rice']);
  });

  test(
    'deleting items on one device still removes them on the other',
    () async {
      final phone = await client.watchLists().first;
      final phoneId = phone.single.id;
      final milk = await client.addShoppingItem(phoneId, 'Milk');
      final bread = await client.addShoppingItem(phoneId, 'Bread');
      await host.applySnapshot(await client.exportSnapshot());

      await client.deleteShoppingItems([milk, bread]);
      await host.applySnapshot(await client.exportSnapshot());

      final items = await (host.select(
        host.shoppingItems,
      )..where((t) => t.deletedAt.isNull())).get();
      expect(items, isEmpty);
    },
  );

  test(
    'two grocery lists with the same category order still share items',
    () async {
      final first = await host.addList('Groceries');
      final second = await host.addList('Groceries');
      await host.addShoppingItem(first, 'Blueberries');
      await host.addShoppingItem(second, 'Chocolate bars');
      await host.setListCategoryOrder(first, const ['Produce']);
      await host.setListCategoryOrder(second, const ['Produce']);

      await client.applySnapshot(await host.exportSnapshot());

      expect(await shoppingNames(client), ['Groceries']);
      final items = await (client.select(
        client.shoppingItems,
      )..where((t) => t.deletedAt.isNull())).get();
      expect([for (final item in items) item.name]..sort(), [
        'Blueberries',
        'Chocolate bars',
      ]);
    },
  );

  test(
    'same pantry list name becomes one list with the other device\'s items',
    () async {
      final phone = await client.addList('Garage', kind: 'pantry');
      await client.addPantryItem('Water', listId: phone);
      final computer = await host.addList('Garage', kind: 'pantry');
      await host.addPantryItem('Batteries', listId: computer);
      await host.addPantryItem('Water', listId: computer);

      await exchange(host, client);

      expect(await pantryNames(host), containsAll(['Pantry', 'Garage']));
      expect(await pantryNames(client), containsAll(['Pantry', 'Garage']));
      expect(
        (await pantryNames(host)).where((n) => n == 'Garage'),
        hasLength(1),
      );
      final garage =
          (await (host.select(host.shoppingLists)..where(
                    (t) =>
                        t.deletedAt.isNull() &
                        t.kind.equals('pantry') &
                        t.name.equals('Garage'),
                  ))
                  .get())
              .single;
      final items = await (host.select(
        host.pantryItems,
      )..where((t) => t.deletedAt.isNull() & t.listId.equals(garage.id))).get();
      expect([for (final item in items) item.name]..sort(), ['Water']);
    },
  );

  test('items and a pantry list come along with it', () async {
    final listId = await client.addList('Phone groceries');
    final itemId = await client.addShoppingItem(listId, 'Oat milk');
    await client.updateShoppingItem(
      itemId,
      name: 'Oat milk',
      quantity: 2,
      unit: 'cartons',
      category: 'Dairy',
      price: 4.5,
      note: 'unsweetened',
      taxable: true,
    );
    final pantryId = await client.addList('Garage shelf', kind: 'pantry');
    await client.addPantryItem(
      'Sparkling water',
      listId: pantryId,
      location: 'Shelf',
    );

    await exchange(host, client);

    expect(await shoppingNames(host), contains('Phone groceries'));
    expect(await pantryNames(host), contains('Garage shelf'));
    final items = await (host.select(
      host.shoppingItems,
    )..where((t) => t.deletedAt.isNull() & t.listId.equals(listId))).get();
    expect(items, hasLength(1));
    expect(items.single.name, 'Oat milk');
    expect(items.single.quantity, 2);
    expect(items.single.price, 4.5);
    expect(items.single.note, 'unsweetened');
    final categories = await host.select(host.categories).get();
    expect(categories.map((c) => c.name), contains('Dairy'));
    final pantry = await (host.select(
      host.pantryItems,
    )..where((t) => t.deletedAt.isNull())).get();
    expect(pantry.map((item) => item.name), contains('Sparkling water'));
  });

  test('deleting a list on one device removes it on the other', () async {
    final id = await client.addList('Temporary');
    await exchange(host, client);
    expect(await shoppingNames(host), contains('Temporary'));

    await client.deleteList(id);
    await exchange(host, client);
    expect(await shoppingNames(host), isNot(contains('Temporary')));
    expect(await shoppingNames(client), isNot(contains('Temporary')));
  });

  test('the newer edit of a list wins', () async {
    final id = await client.addList('Shared');
    await exchange(host, client);

    await stamp(host, id, DateTime.utc(2030), 'From the computer');
    await stamp(client, id, DateTime.utc(2020), 'From the phone');
    await exchange(host, client);
    expect(await shoppingNames(host), contains('From the computer'));
    expect(await shoppingNames(client), contains('From the computer'));
    expect(await shoppingNames(host), isNot(contains('From the phone')));

    await stamp(client, id, DateTime.utc(2031), 'From the phone');
    await exchange(host, client);
    expect(await shoppingNames(host), contains('From the phone'));
    expect(await shoppingNames(client), contains('From the phone'));
  });

  test('two new household codes collapse to one', () {
    const a = 'aaaaaaaaaa.aaaaaaaaaaaaaaaaaaaaaaaaaa';
    const m = 'mmmmmmmmmm.mmmmmmmmmmmmmmmmmmmmmmmmmm';
    expect(pickHouseholdCode(m, a, keepLocal: false), a);
    expect(pickHouseholdCode(a, m, keepLocal: false), a);
    expect(pickHouseholdCode(m, a, keepLocal: true), m);
    expect(pickHouseholdCode(null, a, keepLocal: false), a);
  });

  test('beacon targets include the subnet broadcast phones deliver', () {
    expect(subnetBroadcast('192.168.1.20'), '192.168.1.255');
    expect(subnetBroadcast('10.0.0.4'), '10.0.0.255');
    expect(subnetBroadcast('127.0.0.1'), null);
    expect(subnetBroadcast('not-an-address'), null);
    expect(announcesOnInterface('Wi-Fi'), isTrue);
    expect(announcesOnInterface('wlan0'), isTrue);
    expect(announcesOnInterface('en0'), isTrue);
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(householdCodeStartsWifiSharing, isFalse);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(householdCodeStartsWifiSharing, isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(householdCodeStartsWifiSharing, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
    expect(announcesOnInterface('awdl0'), isFalse);
    expect(announcesOnInterface('vEthernet (Default Switch)'), isFalse);
    expect(announcesOnInterface('rmnet_data0'), isFalse);
    final sends = beaconSendsFor(const [
      (name: 'vEthernet (Default Switch)', address: '172.22.224.1'),
      (name: 'Wi-Fi', address: '192.168.1.20'),
    ]);
    expect(sends, hasLength(2));
    expect(sends.first.from.address, '192.168.1.20');
    expect(sends.first.to.address, '192.168.1.255');
    expect(sends.last.from.address, '192.168.1.20');
    expect(sends.last.to.address, '255.255.255.255');
    final fallback = beaconSendsFor(const [
      (name: 'vEthernet (WSL)', address: '172.22.224.1'),
    ]);
    expect(fallback.single.to.address, '255.255.255.255');
    expect(
      friendlySyncError(const HttpException('closed')),
      "Can't reach the other device. Keep both apps open on the same Wi-Fi.",
    );
    expect(
      friendlySyncError(
        PlatformException(
          code: 'error',
          message: 'WifiLock.acquire() requires android.permission.WAKE_LOCK',
        ),
      ),
      'Could not sync with the other device.',
    );
  });

  test('sharing still gets a device id when preferences fail', () async {
    final saved = await resolveDeviceId(
      readSaved: () async => '6f97ac34a9a65b87b2d722e057837da6',
      write: (_) async => fail('already saved'),
    );
    expect(saved, '6f97ac34a9a65b87b2d722e057837da6');

    final created = await resolveDeviceId(
      readSaved: () async => null,
      write: (_) async => throw PlatformException(code: 'error'),
    );
    expect(created, matches(RegExp(r'^[0-9a-f]{32}$')));

    final again = await resolveDeviceId(
      remembered: created,
      readSaved: () async => throw PlatformException(code: 'error'),
      write: (_) async => fail('remembered'),
    );
    expect(again, created);
  });

  test('a beacon says which device is sharing and where', () {
    final beacon = ShopItBeacon.tryParse('SHOPIT1\t47821\tabc\tthe phone');
    expect(beacon?.port, shopItSyncPort);
    expect(beacon?.id, 'abc');
    expect(beacon?.name, 'the phone');
    expect(beacon?.encode(), 'SHOPIT1\t47821\tabc\tthe phone');
    expect(ShopItBeacon.tryParse('hello'), null);
    expect(ShopItBeacon.tryParse('SHOPIT1\tnope\tabc\tphone'), null);
  });

  testWidgets('settings explains how to share lists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          // Real queries schedule a timer when the test disposes them.
          listsProvider.overrideWith((_) => Stream.value(const [])),
          taxRatesProvider.overrideWith((_) => Stream.value(const [])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const SettingsDialog(),
                ),
                child: const Text('Open settings'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('DEVICES'), findsOneWidget);
    expect(find.text('Share lists'), findsOneWidget);
    expect(
      find.byTooltip('Share lists with your other device'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(find.text('Share lists'), 200);
    await tester.tap(find.text('Share lists'));
    await tester.pumpAndSettle();
    expect(find.text('Share on this Wi-Fi'), findsOneWidget);
    expect(find.text('Create cloud code'), findsOneWidget);
    expect(
      find.byTooltip(
        'Share lists with ShopIt on the other device on this Wi-Fi',
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Close'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('An open source shopping and pantry list app.'),
      200,
    );
    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('ShopIt'), findsOneWidget);
    expect(
      find.text('An open source shopping and pantry list app.'),
      findsOneWidget,
    );
    expect(
      find.text('https://github.com/nuclearfessel/ShopIt'),
      findsOneWidget,
    );
    expect(find.widgetWithText(AlertDialog, 'About'), findsNothing);
  });

  testWidgets(
    'Windows and Mac show the QR code an iPhone or Android phone scans',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase.memory();
      addTearDown(db.close);

      Future<void> expectControls({
        required TargetPlatform platform,
        required bool scans,
        required bool showsQr,
      }) async {
        debugDefaultTargetPlatformOverride = platform;
        debugPlatformScansBarcodes = scans;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              key: ValueKey(platform),
              home: const DeviceLinkDialog(),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.text('Show QR code'),
          showsQr ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Scan QR code'),
          scans ? findsOneWidget : findsNothing,
        );
      }

      try {
        await expectControls(
          platform: TargetPlatform.windows,
          scans: false,
          showsQr: true,
        );
        await expectControls(
          platform: TargetPlatform.macOS,
          scans: false,
          showsQr: true,
        );
        await expectControls(
          platform: TargetPlatform.iOS,
          scans: true,
          showsQr: false,
        );
        await expectControls(
          platform: TargetPlatform.android,
          scans: true,
          showsQr: false,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
        debugPlatformScansBarcodes = null;
      }
    },
  );
}
