import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/data/database.dart';
import 'package:shop_it/services/cloud_mailbox.dart';

void main() {
  test('sealed mailbox payloads hide list contents', () async {
    const json = '{"name":"Milk","note":"2%"}';
    final code = newHouseholdCode();
    final other = newHouseholdCode();
    final sealed = await sealMailboxPayload(code, json);
    expect(sealed.startsWith('enc1:'), isTrue);
    expect(sealed.contains('Milk'), isFalse);
    expect(sealed.contains(householdSecret(code)), isFalse);
    expect(await openMailboxPayload(code, sealed), json);
    expect(await openMailboxPayload(other, sealed), isNull);
    expect(await openMailboxPayload(code, 'gz:not-ours'), isNull);
  });

  test('new household codes are shorter and older codes still join', () {
    final code = newHouseholdCode();
    final parts = code.split('.');
    expect(isHouseholdCode(code), isTrue);
    expect(parts[0].length, householdMailboxIdLength);
    expect(parts[1].length, householdSecretLength);
    expect(isHouseholdCode('aaaaaaaaaa.aaaaaaaaaaaaaaaaaaaaaaaaaa'), isTrue);
    expect(isHouseholdCode('short'), isFalse);
    expect(isHouseholdCode('aaaaaaaa.aaaaaaaaaaaaaaaaaaaaaaaaaa'), isFalse);
  });

  test('the cloud topic carries the mailbox id and not the secret', () {
    final code = newHouseholdCode();
    final topic = mailboxDeviceTopic(code, 'phone');
    expect(topic, 'shopit/p/${householdMailboxId(code)}/phone');
    expect(topic.contains(householdSecret(code)), isFalse);
  });

  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('cloud mailbox merges the other device then uploads this one', () async {
    final mailbox = MemoryCloudMailbox();
    final phone = AppDatabase.memory();
    final computer = AppDatabase.memory();
    addTearDown(phone.close);
    addTearDown(computer.close);

    final code = await mailbox.createHousehold();
    expect(isHouseholdCode(code), isTrue);

    await phone.addList('From the phone');
    await mailbox.syncDevice(
      code: code,
      deviceId: 'phone',
      deviceName: 'the phone',
      db: phone,
    );

    await computer.addList('From the computer');
    await mailbox.syncDevice(
      code: code,
      deviceId: 'computer',
      deviceName: 'the computer',
      db: computer,
    );

    final names = await (computer.select(
      computer.shoppingLists,
    )..where((t) => t.deletedAt.isNull() & t.kind.equals('shopping'))).get();
    expect([for (final row in names) row.name]..sort(), [
      'From the computer',
      'From the phone',
      'Groceries',
    ]);

    await mailbox.syncDevice(
      code: code,
      deviceId: 'phone',
      deviceName: 'the phone',
      db: phone,
    );
    final phoneNames = await (phone.select(
      phone.shoppingLists,
    )..where((t) => t.deletedAt.isNull() & t.kind.equals('shopping'))).get();
    expect([for (final row in phoneNames) row.name]..sort(), [
      'From the computer',
      'From the phone',
      'Groceries',
    ]);
  });

  test('same-name lists replace across the cloud mailbox too', () async {
    final mailbox = MemoryCloudMailbox();
    final phone = AppDatabase.memory();
    final computer = AppDatabase.memory();
    addTearDown(phone.close);
    addTearDown(computer.close);

    final code = await mailbox.createHousehold();
    // Computer publishes first with Bananas, then the phone publishes Apples
    // with a newer item timestamp so Apples replace Bananas on the next sync.
    final computerList = await computer.addList('Groceries');
    await computer.addShoppingItem(computerList, 'Bananas');
    await mailbox.syncDevice(
      code: code,
      deviceId: 'computer',
      deviceName: 'the computer',
      db: computer,
    );

    // Item timestamps are stored to the second; wait so Apples is strictly newer.
    await Future<void>.delayed(const Duration(seconds: 2));
    final phoneList = await phone.addList('Groceries');
    await phone.addShoppingItem(phoneList, 'Apples');
    await mailbox.syncDevice(
      code: code,
      deviceId: 'phone',
      deviceName: 'the phone',
      db: phone,
    );

    await mailbox.syncDevice(
      code: code,
      deviceId: 'computer',
      deviceName: 'the computer',
      db: computer,
    );

    final lists = await (computer.select(
      computer.shoppingLists,
    )..where((t) => t.deletedAt.isNull() & t.kind.equals('shopping'))).get();
    expect(lists, hasLength(1));
    final items =
        await (computer.select(computer.shoppingItems)..where(
              (t) => t.deletedAt.isNull() & t.listId.equals(lists.single.id),
            ))
            .get();
    expect([for (final item in items) item.name], ['Apples']);
  });

  test('cloud sync prefers the newest peer when several devices publish', () async {
    final mailbox = MemoryCloudMailbox();
    final tablet = AppDatabase.memory();
    final phone = AppDatabase.memory();
    final computer = AppDatabase.memory();
    addTearDown(tablet.close);
    addTearDown(phone.close);
    addTearDown(computer.close);

    final code = await mailbox.createHousehold();
    final tabletList = (await tablet.watchLists().first).single.id;
    await tablet.addShoppingItem(tabletList, 'Old');
    await mailbox.syncDevice(
      code: code,
      deviceId: 'tablet',
      deviceName: 'the tablet',
      db: tablet,
    );

    // Fresher local content on the phone must not be wiped by the older tablet
    // snapshot when the phone syncs, and the computer must end on Fresh.
    await Future<void>.delayed(const Duration(seconds: 2));
    final phoneList = (await phone.watchLists().first).single.id;
    await phone.addShoppingItem(phoneList, 'Fresh');
    await mailbox.syncDevice(
      code: code,
      deviceId: 'phone',
      deviceName: 'the phone',
      db: phone,
    );

    final phoneItems = await (phone.select(
      phone.shoppingItems,
    )..where((t) => t.deletedAt.isNull())).get();
    expect([for (final item in phoneItems) item.name], ['Fresh']);

    await mailbox.syncDevice(
      code: code,
      deviceId: 'computer',
      deviceName: 'the computer',
      db: computer,
    );

    final items = await (computer.select(
      computer.shoppingItems,
    )..where((t) => t.deletedAt.isNull())).get();
    expect([for (final item in items) item.name], ['Fresh']);
  });

  test('websocket mailbox clients stay on websocket', () {
    final websocket = buildCloudMqttClient(
      endpoint: cloudEndpoints.first,
      clientId: 'test-ws',
    );
    expect(websocket.useWebSocket, isTrue);
    expect(websocket.secure, isFalse);
    expect(websocket.port, 8884);
    expect(websocket.server, startsWith('wss://'));

    final tls = buildCloudMqttClient(
      endpoint: cloudEndpoints[1],
      clientId: 'test-tls',
    );
    expect(tls.useWebSocket, isFalse);
    expect(tls.secure, isTrue);
    expect(tls.port, 8883);
  });
}
