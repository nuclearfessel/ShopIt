import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop_it/app/app.dart';
import 'package:shop_it/app/theme_mode.dart';
import 'package:shop_it/data/database.dart';
import 'package:shop_it/data/providers.dart';
import 'package:shop_it/features/settings/settings_dialog.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('saving the theme choice', () {
    test('defaults to following the system', () async {
      expect(await loadThemeMode(), ThemeMode.system);
    });

    test('each choice is remembered and loaded back', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      for (final mode in ThemeMode.values) {
        await container.read(themeModeProvider.notifier).set(mode);
        expect(container.read(themeModeProvider), mode);
        expect(await loadThemeMode(), mode);
      }
    });

    test('an unknown saved value falls back to system', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'sepia'});
      expect(await loadThemeMode(), ThemeMode.system);
    });

    test('the saved choice is the starting value', () async {
      final container = ProviderContainer(
        overrides: [initialThemeModeProvider.overrideWithValue(ThemeMode.dark)],
      );
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });
  });

  group('switching in the settings dialog', () {
    Future<ProviderContainer> pumpApp(
      WidgetTester tester, {
      Brightness platform = Brightness.light,
    }) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = platform;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(AppDatabase.memory()),
            listsProvider.overrideWith(
              (_) => Stream.value(const <ShoppingList>[]),
            ),
            taxRatesProvider.overrideWith(
              (_) => Stream.value(const <TaxRate>[]),
            ),
            pantryProvider.overrideWith(
              (_) => Stream.value(const <PantryItem>[]),
            ),
          ],
          child: const ShopItApp(windowChrome: false),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      return ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
    }

    Brightness shown(WidgetTester tester) =>
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

    Future<void> choose(WidgetTester tester, String label) async {
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsDialog), findsOneWidget);
      // Tap the segment (found by its tooltip, which every segment has).
      await tester.tap(find.byTooltip(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
    }

    testWidgets('Light, Dark and Match system change the whole app', (
      tester,
    ) async {
      final container = await pumpApp(tester); // the system is light
      expect(shown(tester), Brightness.light);

      await choose(tester, 'Dark');
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(shown(tester), Brightness.dark);
      expect(await loadThemeMode(), ThemeMode.dark); // remembered

      await choose(tester, 'Light');
      expect(shown(tester), Brightness.light);

      // "Match system" follows the platform in both directions.
      await choose(tester, 'Match system');
      expect(container.read(themeModeProvider), ThemeMode.system);
      expect(shown(tester), Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(shown(tester), Brightness.dark);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(shown(tester), Brightness.light);
    });

    testWidgets('a forced theme ignores the system setting', (tester) async {
      await pumpApp(tester, platform: Brightness.dark);
      expect(shown(tester), Brightness.dark); // system is dark by default
      await choose(tester, 'Light');
      expect(shown(tester), Brightness.light);
    });

    testWidgets('settings are reachable from the pantry too', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Pantry').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
      // No list is open, so tax rates can be managed but not assigned.
      expect(find.text('No tax'), findsNothing);
      expect(find.text('Add a tax rate'), findsOneWidget);
    });
  });
}
