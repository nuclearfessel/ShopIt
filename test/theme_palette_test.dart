import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/app/app.dart';
import 'package:shop_it/app/title_bar.dart';
import 'package:shop_it/ui/category_color.dart';
import 'package:shop_it/ui/keyline/keyline_icon.dart';

void main() {
  final cases = <Brightness, _Palette>{
    Brightness.light: const _Palette(
      background: Color(0xFFF8F1E7),
      cards: Color(0xFFF1E7D8),
      raised: Color(0xFFFFF8EA),
      totals: Color(0xFFE8D8C1),
      text: Color(0xFF24342D),
      icon: iconOnLight,
    ),
    Brightness.dark: const _Palette(
      background: Color(0xFF171E1A),
      cards: Color(0xFF202B25),
      raised: Color(0xFF26372F),
      totals: Color(0xFF304238),
      text: Color(0xFFFFF8EA),
      icon: iconOnDark,
    ),
  };

  test('both themes are generated from the Original Tangerine seed', () {
    expect(shopItSeed, const Color(0xFFEF7008));
    for (final brightness in Brightness.values) {
      final theme = shopItTheme(brightness);
      final generated = ColorScheme.fromSeed(
        seedColor: shopItSeed,
        brightness: brightness,
      );
      final previous = ColorScheme.fromSeed(
        seedColor: const Color(0xFF4F7A3A),
        brightness: brightness,
      );
      final scheme = theme.colorScheme;
      expect(scheme.primary, generated.primary);
      expect(scheme.onPrimary, generated.onPrimary);
      expect(scheme.primaryContainer, generated.primaryContainer);
      expect(scheme.onPrimaryContainer, generated.onPrimaryContainer);
      expect(scheme.secondary, generated.secondary);
      expect(scheme.onSecondary, generated.onSecondary);
      expect(scheme.secondaryContainer, generated.secondaryContainer);
      expect(scheme.onSecondaryContainer, generated.onSecondaryContainer);
      expect(scheme.error, generated.error);
      expect(scheme.onError, generated.onError);
      expect(scheme.outline, generated.outline);
      expect(scheme.outlineVariant, generated.outlineVariant);
      expect(scheme.primary, isNot(previous.primary));
      expect(scheme.surfaceTint, Colors.transparent);
    }
  });

  test('each fixed role keeps its own color', () {
    for (final brightness in Brightness.values) {
      final palette = cases[brightness]!;
      final scheme = shopItTheme(brightness).colorScheme;
      expect(scheme.surface, palette.background);
      expect(scheme.surfaceContainerLowest, palette.background);
      expect(scheme.onSurface, palette.text);
      expect(scheme.surfaceContainerLow, palette.cards);
      expect(scheme.surfaceContainer, palette.cards);
      expect(scheme.surfaceContainerHigh, palette.raised);
      expect(scheme.surfaceContainerHighest, palette.totals);
      expect({
        palette.background,
        palette.cards,
        palette.raised,
        palette.totals,
      }, hasLength(4));
    }
  });

  test('components use the fixed surfaces, text, and icon accent', () {
    for (final brightness in Brightness.values) {
      final palette = cases[brightness]!;
      final theme = shopItTheme(brightness);
      final scheme = theme.colorScheme;
      expect(theme.scaffoldBackgroundColor, palette.background);
      expect(theme.cardTheme.color, palette.cards);
      expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
      expect(theme.dialogTheme.backgroundColor, palette.raised);
      expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
      expect(theme.appBarTheme.backgroundColor, palette.background);
      expect(theme.appBarTheme.foregroundColor, palette.text);
      expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
      expect(theme.appBarTheme.iconTheme?.color, palette.icon);
      expect(theme.iconTheme.color, palette.icon);
      expect(theme.navigationBarTheme.backgroundColor, palette.cards);
      expect(theme.navigationRailTheme.backgroundColor, palette.cards);
      expect(
        theme.navigationBarTheme.indicatorColor,
        scheme.secondaryContainer,
      );
      expect(
        theme.navigationBarTheme.iconTheme?.resolve({
          WidgetState.selected,
        })?.color,
        scheme.onSecondaryContainer,
      );
      expect(
        theme.navigationBarTheme.iconTheme?.resolve({})?.color,
        palette.icon,
      );
      expect(
        theme.navigationRailTheme.selectedIconTheme?.color,
        scheme.onSecondaryContainer,
      );
      expect(
        theme.navigationRailTheme.unselectedIconTheme?.color,
        palette.icon,
      );
      expect(theme.floatingActionButtonTheme.backgroundColor, palette.raised);
      expect(theme.floatingActionButtonTheme.foregroundColor, palette.icon);
      expect(
        theme.iconButtonTheme.style?.foregroundColor?.resolve({}),
        palette.icon,
      );
      expect(
        theme.iconButtonTheme.style?.foregroundColor?.resolve({
          WidgetState.disabled,
        }),
        palette.icon.withValues(alpha: 0.4),
      );
      expect(
        theme.inputDecorationTheme.hintStyle?.color,
        palette.text.withValues(alpha: 0.75),
      );
      expect(
        theme.inputDecorationTheme.labelStyle?.color,
        palette.text.withValues(alpha: 0.85),
      );
      expect(
        theme.inputDecorationTheme.floatingLabelStyle?.color,
        palette.text,
      );
      expect(theme.primaryIconTheme.color, isNot(palette.icon));
    }
  });

  testWidgets('a primary button keeps the generated foreground', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      final theme = shopItTheme(brightness);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          themeAnimationDuration: Duration.zero,
          home: Scaffold(
            body: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final foreground = IconTheme.of(tester.element(find.byIcon(Icons.add)))
          .color;
      expect(foreground, theme.colorScheme.onPrimary);
      expect(
        foreground,
        isNot(brightness == Brightness.dark ? iconOnDark : iconOnLight),
      );
    }
  });

  testWidgets('the floating button uses the raised surface and icon accent', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      final theme = shopItTheme(brightness);
      final accent = brightness == Brightness.dark ? iconOnDark : iconOnLight;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          themeAnimationDuration: Duration.zero,
          home: Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );
      final button = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(button.backgroundColor, isNull);
      expect(
        theme.floatingActionButtonTheme.backgroundColor,
        theme.colorScheme.surfaceContainerHigh,
      );
      expect(
        IconTheme.of(tester.element(find.byIcon(Icons.add))).color,
        accent,
      );
    }
  });

  test('automatic category lightness stays 0.42 and 0.62', () {
    const names = ['Produce', 'Bakery', 'Dairy & Eggs', 'Spices'];
    for (final name in names) {
      final light = HSLColor.fromColor(
        automaticCategoryColor(name, Brightness.light),
      );
      final dark = HSLColor.fromColor(
        automaticCategoryColor(name, Brightness.dark),
      );
      expect(light.lightness, closeTo(0.42, 0.02));
      expect(dark.lightness, closeTo(0.62, 0.02));
      expect(light.saturation, closeTo(0.5, 0.05));
      expect(dark.saturation, closeTo(0.5, 0.05));
      expect((light.hue - dark.hue).abs(), lessThan(1));
    }
    expect(
      automaticCategoryColor('Produce', Brightness.light),
      isNot(automaticCategoryColor('Bakery', Brightness.light)),
    );
    // A stored choice is a plain color. The generator is not applied to it.
    expect(
      const Color(0xFFE53935),
      isNot(automaticCategoryColor('Produce', Brightness.light)),
    );
  });

  testWidgets('Close turns the generated error color on hover', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('window_manager'), (
      call,
    ) async {
      if (call.method == 'isMaximized') return false;
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        null,
      ),
    );

    for (final brightness in Brightness.values) {
      final theme = shopItTheme(brightness);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          themeAnimationDuration: Duration.zero,
          home: const Scaffold(
            body: Align(alignment: Alignment.topCenter, child: AppTitleBar()),
          ),
        ),
      );
      await tester.pump();

      KeylineIcon closeIcon() => tester.widget<KeylineIcon>(
        find.descendant(
          of: find.byTooltip('Close'),
          matching: find.byType(KeylineIcon),
        ),
      );

      final accent = brightness == Brightness.dark ? iconOnDark : iconOnLight;
      expect(closeIcon().color, accent);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byTooltip('Close')));
      await tester.pump();

      expect(closeIcon().color, theme.colorScheme.error);
      expect(closeIcon().color, isNot(shopItSeed));
      expect(closeIcon().color, isNot(accent));
      final wash = Color.alphaBlend(
        theme.colorScheme.error.withValues(alpha: 0.18),
        theme.colorScheme.surfaceContainer,
      );
      expect(_contrast(theme.colorScheme.error, wash), greaterThanOrEqualTo(3));
      await gesture.removePointer();
    }
  });
}

class _Palette {
  const _Palette({
    required this.background,
    required this.cards,
    required this.raised,
    required this.totals,
    required this.text,
    required this.icon,
  });

  final Color background;
  final Color cards;
  final Color raised;
  final Color totals;
  final Color text;
  final Color icon;
}

double _channel(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _contrast(Color a, Color b) {
  final l1 = _luminance(a);
  final l2 = _luminance(b);
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);
