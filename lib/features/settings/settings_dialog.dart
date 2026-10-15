import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme_mode.dart';
import '../shopping/tax_rates_dialog.dart';
import '../../ui/keyline/keyline_icon.dart';

/// App settings: light/dark theme and the sales tax rates.
///
/// Opened from a shopping list, [listId] and [listName] let the tax section
/// choose which rate that list uses; from elsewhere it only manages rates.
class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key, this.listId, this.listName});

  final String? listId;
  final String? listName;

  /// (mode, tooltip, segment label, icon)
  static const _options = [
    (ThemeMode.system, 'Match system', 'System', KeylineIcons.monitor),
    (ThemeMode.light, 'Light', 'Light', KeylineIcons.sun),
    (ThemeMode.dark, 'Dark', 'Dark', KeylineIcons.moon),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = ref.watch(themeModeProvider);

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          letterSpacing: 0.6,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );

    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading('Appearance'),
              // Segmented control: System / Light / Dark. Icons only (with
              // tooltips) when the dialog is too narrow for the labels.
              LayoutBuilder(
                builder: (context, box) {
                  final compact = box.maxWidth < 300;
                  return SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      expandedInsets: EdgeInsets.zero,
                      segments: [
                        for (final (m, label, short, icon) in _options)
                          ButtonSegment(
                            value: m,
                            tooltip: label,
                            icon: KeylineIcon(icon, size: 18),
                            label: compact ? null : Text(short),
                          ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (s) =>
                          ref.read(themeModeProvider.notifier).set(s.first),
                    ),
                  );
                },
              ),
              const Divider(height: 24),
              heading(
                listName == null ? 'Sales tax' : 'Sales tax for "$listName"',
              ),
              TaxRatesSection(listId: listId),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
