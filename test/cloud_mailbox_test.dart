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

  test('same-name lists merge across the cloud mailbox too', () async {
    final mailbox = MemoryCloudMailbox();
    final phone = AppDatabase.memory();
    final computer = AppDatabase.memory();
    addTearDown(phone.close);
    addTearDown(computer.close);

    final code = await mailbox.createHousehold();
    final phoneList = await phone.addList('Groceries');
    await phone.addShoppingItem(phoneList, 'Apples');
    await mailbox.syncDevice(
      code: code,
      deviceId: 'phone',
      deviceName: 'the phone',
      db: phone,
    );

    final computerList = await computer.addList('Groceries');
    await computer.addShoppingItem(computerList, 'Bananas');
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
    expect([for (final item in items) item.name]..sort(), [
      'Apples',
      'Bananas',
    ]);
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
