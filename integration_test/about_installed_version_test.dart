import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shop_it/features/settings/about_section.dart';

// Use real platform metadata, not PackageInfo.setMockInitialValues().
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('installed About version matches the expected native release', (
    tester,
  ) async {
    const expectedVersion = String.fromEnvironment('EXPECTED_APP_VERSION');
    const expectedBuild = String.fromEnvironment('EXPECTED_APP_BUILD');
    expect(
      expectedVersion,
      isNotEmpty,
      reason: 'Pass --dart-define=EXPECTED_APP_VERSION=<release version>',
    );
    expect(
      expectedBuild,
      isNotEmpty,
      reason: 'Pass --dart-define=EXPECTED_APP_BUILD=<release build>',
    );
    final info = await PackageInfo.fromPlatform();
    expect(info.version.trim(), expectedVersion);
    expect(info.buildNumber.trim(), expectedBuild);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: AboutSection())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Version $expectedVersion'), findsOneWidget);
    expect(find.text('ShopIt'), findsOneWidget);
    expect(find.text('Version unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
