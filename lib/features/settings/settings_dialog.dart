import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_factor.dart';
import '../../app/theme_mode.dart';
import '../shopping/tax_rates_dialog.dart';
import '../../ui/keyline/keyline_icon.dart';
import '../../ui/tip.dart';
import 'about_section.dart';
import 'device_link_controller.dart';
import 'device_link_dialog.dart';
import 'list_handoff.dart';

/// On a large window, Settings is a dialog at this width or wider, and a
/// full-screen page below it. A phone is always the page.
const settingsDialogBreakpoint = 700.0;

/// A phone is always the full-screen page. A tablet or desktop window follows
/// [width], including while Settings is already open.
bool settingsUsesDialog({required bool phone, required double width}) =>
    !phone && width >= settingsDialogBreakpoint;

/// Opens Settings and switches between the dialog and the page if the window
/// later crosses [settingsDialogBreakpoint] or the phone-size line.
void showAppSettings(BuildContext context, {String? listId, String? listName}) {
  Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (_, _, _) =>
          _AdaptiveSettings(listId: listId, listName: listName),
    ),
  );
}

/// Switches the open Settings between the dialog and the full-screen page as
/// the window changes size.
class _AdaptiveSettings extends StatefulWidget {
  const _AdaptiveSettings({this.listId, this.listName});

  final String? listId;
  final String? listName;

  @override
  State<_AdaptiveSettings> createState() => _AdaptiveSettingsState();
}

class _AdaptiveSettingsState extends State<_AdaptiveSettings> {
  final _formKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dialog = settingsUsesDialog(
      phone: isPhoneSize(size),
      width: size.width,
    );
    if (!dialog) {
      return SettingsPage(
        listId: widget.listId,
        listName: widget.listName,
        formKey: _formKey,
      );
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).pop();
        },
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ModalBarrier(
              color: const Color(0x8A000000),
              dismissible: true,
              onDismiss: () => Navigator.of(context).pop(),
            ),
            SettingsDialog(
              listId: widget.listId,
              listName: widget.listName,
              formKey: _formKey,
            ),
          ],
        ),
      ),
    );
  }
}

/// App settings: light/dark theme and the sales tax rates.
///
/// Opened from a shopping list, [listId] and [listName] let the tax section
/// choose which rate that list uses; from elsewhere it only manages rates.
class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key, this.listId, this.listName, this.formKey});

  final String? listId;
  final String? listName;

  /// Keeps the form's fields when Windows swaps this dialog for the page.
  final Key? formKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
          child: SettingsForm(key: formKey, listId: listId, listName: listName),
        ),
      ),
      actions: const [_SettingsDoneButton()],
    );
  }
}

/// Settings as its own page. The close icon and Done both return to the
/// section that was open.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.listId, this.listName, this.formKey});

  final String? listId;
  final String? listName;

  /// Keeps the form's fields when Windows swaps this page for the dialog.
  final Key? formKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Settings'),
        actions: [
          IconButton(
            tooltip: 'Close',
            icon: const KeylineIcon(KeylineIcons.x),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          SettingsForm(key: formKey, listId: listId, listName: listName),
        ],
      ),
      bottomNavigationBar: const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(width: double.infinity, child: _SettingsDoneButton()),
        ),
      ),
    );
  }
}

class _SettingsDoneButton extends StatelessWidget {
  const _SettingsDoneButton();

  @override
  Widget build(BuildContext context) {
    return Tip(
      'Close settings',
      child: FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Done'),
      ),
    );
  }
}

/// (mode, tooltip, segment label, icon)
const _themeOptions = [
  (ThemeMode.system, 'Match system', 'System', KeylineIcons.monitor),
  (ThemeMode.light, 'Light', 'Light', KeylineIcons.sun),
  (ThemeMode.dark, 'Dark', 'Dark', KeylineIcons.moon),
];

class SettingsForm extends ConsumerWidget {
  const SettingsForm({super.key, this.listId, this.listName});

  final String? listId;
  final String? listName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = ref.watch(themeModeProvider);
    final link = ref.watch(deviceLinkProvider);
    final handoff = ref.watch(listHandoffProvider);

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading('Appearance'),
        // System / Light / Dark, full width of the page or dialog. Each
        // word stays on one line and shrinks to fit, including a narrow
        // phone, instead of wrapping and getting clipped.
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            expandedInsets: EdgeInsets.zero,
            segments: [
              for (final (m, label, short, icon) in _themeOptions)
                ButtonSegment(
                  value: m,
                  tooltip: label,
                  icon: KeylineIcon(icon, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(short, maxLines: 1, softWrap: false),
                  ),
                ),
            ],
            selected: {mode},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).set(s.first),
          ),
        ),
        const Divider(height: 24),
        heading(listName == null ? 'Sales tax' : 'Sales tax for "$listName"'),
        TaxRatesSection(listId: listId),
        const Divider(height: 24),
        heading('Lists'),
        Tip(
          'Turn on offers between the shopping list and the pantry',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Shopping and pantry'),
            subtitle: const Text(
              'Offer to add checked items to the pantry, and to add low, '
              'empty, or use-soon pantry items to the shopping list.',
            ),
            value: handoff,
            onChanged: (v) => ref.read(listHandoffProvider.notifier).set(v),
          ),
        ),
        const Divider(height: 24),
        heading('Devices'),
        Text(
          householdCodeStartsWifiSharing
              ? 'Share lists on this Wi-Fi, and over the internet when '
                    'Wi-Fi is off. Both apps need to be open.'
              : 'Share lists over the internet with a household code. This '
                    'computer is already on Wi-Fi, so Share on this Wi-Fi '
                    'can stay off. Both apps need to be open.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          link.summary,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        if (link.wifiError != null) ...[
          const SizedBox(height: 4),
          Text(
            link.wifiError!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        if (link.cloudError != null) ...[
          const SizedBox(height: 4),
          Text(
            link.cloudError!,
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
            child: Text(
              link.sharing || link.cloudLinked ? 'Sharing on' : 'Share lists',
            ),
          ),
        ),
        const Divider(height: 24),
        heading('About'),
        const AboutSection(),
      ],
    );
  }
}
