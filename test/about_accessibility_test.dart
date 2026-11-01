import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shop_it/features/settings/about_section.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FailedLauncher extends UrlLauncherPlatform {
  bool throwsPlatformException = false;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    if (throwsPlatformException) {
      throw PlatformException(code: 'launch_failed');
    }
    return false;
  }
}

Future<void> _showAbout(
  WidgetTester tester, {
  double width = 320,
  double scale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = Size(width, 560);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: AboutSection(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late _FailedLauncher launcher;
  setUp(() {
    final previous = UrlLauncherPlatform.instance;
    launcher = _FailedLauncher();
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

  for (final platformException in [false, true]) {
    testWidgets('source failure exposes readable dialog and actionable Close '
        '(platform exception: $platformException)', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        launcher.throwsPlatformException = platformException;
        await _showAbout(tester);
        await tester.ensureVisible(find.text(shopItSourceUrl));
        await tester.tap(find.text(shopItSourceUrl));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel("Couldn't open GitHub"), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('Open this address in your browser')),
          findsOneWidget,
        );
        final close = find.widgetWithText(TextButton, 'Close');
        final data = tester.getSemantics(close).getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(data.label, contains('Close'));
        // Modal dismissal works without pointer input.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text(shopItSourceUrl), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  for (final brightness in Brightness.values) {
    for (final width in [240.0, 320.0, 600.0]) {
      for (final scale in [2.0, 3.2]) {
        for (final notice in ['Privacy', 'Licenses']) {
          testWidgets('$notice scrolls at $width / ${scale}x / $brightness', (
            tester,
          ) async {
            await _showAbout(
              tester,
              width: width,
              scale: scale,
              brightness: brightness,
            );
            await tester.ensureVisible(find.text(notice));
            await tester.tap(find.text(notice));
            await tester.pumpAndSettle();
            expect(find.byType(AlertDialog), findsOneWidget);
            final close = find.widgetWithText(TextButton, 'Close');
            expect(tester.getRect(close).bottom, lessThanOrEqualTo(560));
            final scroll = find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(SingleChildScrollView),
            );
            expect(scroll, findsOneWidget);
            await tester.drag(scroll, const Offset(0, -240));
            await tester.pumpAndSettle();
            await tester.tap(close);
            await tester.pumpAndSettle();
            expect(find.byType(AlertDialog), findsNothing);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
}
