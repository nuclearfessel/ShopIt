import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr/qr.dart';
import 'package:shop_it/features/settings/sync_qr_view.dart';
import 'package:shop_it/services/cloud_mailbox.dart';
import 'package:shop_it/services/sync_qr.dart';

void main() {
  test('a sync QR code carries the household code and nothing else', () {
    final code = newHouseholdCode();
    final payload = syncQrPayload(code);
    expect(payload, startsWith(syncQrPrefix));
    expect(householdFromQr(payload), code);
    expect(householdFromQr('  $payload  '), code);
    expect(householdFromQr(code), code);
    expect(householdFromQr('012345678905'), isNull);
    expect(householdFromQr('shopit:not-a-code'), isNull);

    final image = QrImage(QrCode(payload: QrPayload.fromString(payload)));
    expect(image.moduleCount, greaterThan(20));
    expect(image.isDark(0, 0), isTrue);
  });

  testWidgets('the sync QR view paints without throwing', (tester) async {
    final code = newHouseholdCode();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 240,
            height: 240,
            child: SyncQrView(payload: syncQrPayload(code)),
          ),
        ),
      ),
    );
    expect(find.byType(SyncQrView), findsOneWidget);
  });
}
