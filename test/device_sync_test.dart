import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_it/data/database.dart';
import 'package:shop_it/data/device_sync.dart';
import 'package:shop_it/data/providers.dart';
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
    expect(
      find.byTooltip('Share lists with Shop-it on the other device'),
      findsOneWidget,
    );
    expect(find.byTooltip('Close'), findsOneWidget);
  });
}
