import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shop_it/features/settings/about_section.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'ShopIt',
      packageName: 'shop_it',
      version: '1.2.3',
      buildNumber: '42',
      buildSignature: '',
    );
  });

  for (final brightness in Brightness.values) {
    for (final width in [240.0, 320.0, 600.0]) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets(
          'About fits $width wide in $brightness at ${textScale}x text',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final semantics = tester.ensureSemantics();
            try {
              await tester.pumpWidget(
                MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: Size(width, 900),
                      textScaler: TextScaler.linear(textScale),
                    ),
                    child: const Scaffold(
                      body: SingleChildScrollView(
                        padding: EdgeInsets.all(24),
                        child: AboutSection(),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();

              final logoFinder = find.byType(SvgPicture);
              expect(logoFinder, findsOneWidget);
              final logo = tester.widget<SvgPicture>(logoFinder);
              final expectedAsset = brightness == Brightness.dark
                  ? 'assets/brand/shopit-horizontal-dark.svg'
                  : 'assets/brand/shopit-horizontal-light.svg';
              expect(logo.bytesLoader, isA<SvgAssetLoader>());
              expect(
                (logo.bytesLoader as SvgAssetLoader).assetName,
                expectedAsset,
              );
              expect(logo.height, 56);
              expect(find.bySemanticsLabel('ShopIt'), findsOneWidget);
              expect(find.text('ShopIt'), findsNothing);
              expect(
                find.text('An open source shopping, pantry, and recipe app.'),
                findsOneWidget,
              );
              expect(find.text('Version 1.2.3'), findsOneWidget);
              expect(find.text(shopItSiteUrl), findsOneWidget);
              expect(find.text('Privacy'), findsOneWidget);
              expect(find.text('Licenses'), findsOneWidget);
              final bounds = tester.getRect(logoFinder);
              expect(bounds.left, greaterThanOrEqualTo(24));
              expect(bounds.right, lessThanOrEqualTo(width - 24));
              expect(bounds.height, 56);
              expect(tester.takeException(), isNull);

              await tester.ensureVisible(find.text('Privacy'));
              await tester.tap(find.text('Privacy'));
              await tester.pumpAndSettle();
              expect(find.byType(AlertDialog), findsOneWidget);
              await tester.tap(find.text('Close'));
              await tester.pumpAndSettle();
              await tester.ensureVisible(find.text('Licenses'));
              await tester.tap(find.text('Licenses'));
              await tester.pumpAndSettle();
              expect(find.byType(AlertDialog), findsOneWidget);
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }
}
