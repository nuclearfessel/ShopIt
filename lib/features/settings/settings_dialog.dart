import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme_mode.dart';
import '../shopping/tax_rates_dialog.dart';

/// App settings: light/dark theme and the sales tax rates.
///
/// Opened from a shopping list, [listId] and [listName] let the tax section
/// choose which rate that list uses; from elsewhere it only manages rates.
class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key, this.listId, this.listName});

  final String? listId;
  final String? listName;

  static const _options = [
    (ThemeMode.system, 'Match system', Icons.brightness_auto_outlined),
    (ThemeMode.light, 'Light', Icons.light_mode_outlined),
    (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
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
              for (final (m, label, icon) in _options)
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 4, right: 4),
                  leading: Icon(
                    mode == m
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(label),
                  trailing: Icon(icon, size: 20),
                  onTap: () => ref.read(themeModeProvider.notifier).set(m),
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
