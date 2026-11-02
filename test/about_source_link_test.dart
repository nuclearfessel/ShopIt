import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shop_it/features/settings/about_section.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FakeLauncher extends UrlLauncherPlatform {
  final urls = <String>[];
  Future<bool> Function() result = () async => true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) {
    urls.add(url);
    return result();
  }
}

Future<void> _showAbout(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: AboutSection())),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapSource(WidgetTester tester) async {
  await tester.tap(find.text(shopItSiteUrl));
  await tester.pumpAndSettle();
}

void main() {
  late _FakeLauncher launcher;

  setUp(() {
    final previous = UrlLauncherPlatform.instance;
    launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previous);
    PackageInfo.setMockInitialValues(
      appName: 'ShopIt',
      packageName: 'shop_it',
      version: '1.2.3',
      buildNumber: '42',
      buildSignature: '',
    );
  });

  testWidgets('successful launch preserves the destination without an error', (
    tester,
  ) async {
    await _showAbout(tester);
    await _tapSource(tester);

    expect(launcher.urls, ['https://nuclearfessel.github.io/ShopIt/']);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final throwsPlatformException in [false, true]) {
    testWidgets('failed launch shows an accessible, dismissible notice '
        '(platform exception: $throwsPlatformException)', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        launcher.result = () async {
          if (throwsPlatformException) {
            throw PlatformException(code: 'launch_failed');
          }
          return false;
        };
        await _showAbout(tester);
        await _tapSource(tester);

        expect(launcher.urls, ['https://nuclearfessel.github.io/ShopIt/']);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text("Couldn't open ShopIt site"), findsOneWidget);
        expect(
          find.text(
            "ShopIt couldn't open the site link. "
            'Open this address in your browser instead:\n\n'
            'https://nuclearfessel.github.io/ShopIt/',
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel("Couldn't open ShopIt site"),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp('Open this address in your browser')),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(TextButton, 'Close'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);

        // A failure must not prevent the next attempt from succeeding.
        launcher.result = () async => true;
        await _tapSource(tester);
        expect(launcher.urls, hasLength(2));
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  for (final throwsPlatformException in [false, true]) {
    testWidgets('pending launch is safe after About is removed '
        '(platform exception: $throwsPlatformException)', (tester) async {
      final pending = Completer<bool>();
      launcher.result = () => pending.future;
      await _showAbout(tester);
      await _tapSource(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(launcher.urls, ['https://nuclearfessel.github.io/ShopIt/']);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      if (throwsPlatformException) {
        pending.completeError(PlatformException(code: 'launch_failed'));
      } else {
        pending.complete(false);
      }
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
