import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme_mode.dart';
import '../shopping/tax_rates_dialog.dart';
import '../../ui/keyline/keyline_icon.dart';
import '../../ui/tip.dart';
import 'about_section.dart';
import 'device_link_controller.dart';
import 'device_link_dialog.dart';

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
    final link = ref.watch(deviceLinkProvider);

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

    // Desktop draws the scrollbar over the scroll view. Keep a gutter so it
    // sits beside the theme control instead of covering it when the dialog
    // shrinks to fit a short window.
    final scrollbarGutter = switch (theme.platform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => 16.0,
      _ => 0.0,
    };

    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(right: scrollbarGutter),
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
              const Divider(height: 24),
              heading('Devices'),
              Text(
                'Share on this Wi-Fi when both apps are nearby, or pair once '
                'with a cloud code to sync over the internet.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                link.summary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              if (link.error != null) ...[
                const SizedBox(height: 4),
                Text(
                  link.error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Tip(
                'Share lists with your other device',
                child: OutlinedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const DeviceLinkDialog(),
                  ),
                  child: Text(link.sharing ? 'Sharing on' : 'Share lists'),
                ),
              ),
              const Divider(height: 24),
              heading('About'),
              const AboutSection(),
            ],
          ),
        ),
      ),
      actions: [
        Tip(
          'Close settings',
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}
