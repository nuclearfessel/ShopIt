import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/data/database.dart';
import 'package:shop_it/data/device_sync.dart';
import 'package:shop_it/services/device_link.dart';

/// The widget-test binding replaces [HttpClient] with one that never connects.
/// This zone uses the real client so two devices on this machine can sync.
class _RealHttp extends HttpOverrides {}

Future<T> _realHttp<T>(Future<T> Function() body) {
  return HttpOverrides.runZoned(
    body,
    createHttpClient: (context) => _RealHttp().createHttpClient(context),
  );
}

Future<List<String>> shoppingNames(AppDatabase db) async {
  final rows =
      await (db.select(db.shoppingLists)..where(
            (t) => t.deletedAt.isNull() & t.kind.equals('shopping'),
          ))
          .get();
  return [for (final row in rows) row.name];
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

  test('syncing over the link copies lists both ways', () async {
    final server = DeviceHost();
    addTearDown(server.stop);
    final port = await server.start(
      db: host,
      code: '123456',
      bindAddress: InternetAddress.loopbackIPv4,
      port: 0,
    );

    await client.addList('From the phone');
    await _realHttp(
      () => syncWithDevice(
        db: client,
        host: '127.0.0.1',
        port: port,
        code: '123456',
      ),
    );
    expect(await shoppingNames(host), contains('From the phone'));

    await host.addList('From the computer');
    await _realHttp(
      () => syncWithDevice(
        db: client,
        host: '127.0.0.1',
        port: port,
        code: '123456',
      ),
    );
    expect(await shoppingNames(client), contains('From the computer'));
    expect(await shoppingNames(host), contains('From the phone'));

    await _realHttp(
      () => expectLater(
        syncWithDevice(
          db: client,
          host: '127.0.0.1',
          port: port,
          code: '000000',
        ),
        throwsA(isA<SyncException>()),
      ),
    );
  });
}
