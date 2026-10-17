import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/tip.dart';
import 'device_link_controller.dart';

/// Turn sharing on for Wi-Fi and, optionally, over the internet.
class DeviceLinkDialog extends ConsumerStatefulWidget {
  const DeviceLinkDialog({super.key});

  @override
  ConsumerState<DeviceLinkDialog> createState() => _DeviceLinkDialogState();
}

class _DeviceLinkDialogState extends ConsumerState<DeviceLinkDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final link = ref.watch(deviceLinkProvider);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
    );
    final notifier = ref.read(deviceLinkProvider.notifier);

    return AlertDialog(
      title: const Text('Share lists'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Turn sharing on here and on the other device. On the same '
                'Wi-Fi they find each other. When Wi-Fi is off, lists still '
                'sync over the internet while each app is open. The first '
                'time they meet, they share a code so that can happen. You '
                'can also create or enter that code below.',
                style: muted,
              ),
              const SizedBox(height: 12),
              Text(link.summary, style: theme.textTheme.bodyMedium),
              if (link.sharing) ...[
                const SizedBox(height: 4),
                Text(
                  _when('Wi-Fi', link.lastWifiSync),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (link.wifiError != null) ...[
                const SizedBox(height: 4),
                Text(
                  link.wifiError!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              if (link.cloudLinked) ...[
                const SizedBox(height: 4),
                Text(
                  _when('Cloud', link.lastCloudSync),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (link.cloudError != null) ...[
                const SizedBox(height: 4),
                Text(
                  link.cloudError!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              if (link.sharing && Platform.isWindows) ...[
                const SizedBox(height: 12),
                Text(
                  'If Windows asks whether to allow ShopIt on private '
                  'networks, choose allow. The phone cannot connect on Wi-Fi '
                  'until you do.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'THIS WI-FI',
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 0.6,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              if (link.sharing)
                Tip(
                  'Stop sharing lists on this Wi-Fi',
                  child: TextButton(
                    onPressed: link.busy ? null : notifier.stop,
                    child: const Text('Stop Wi-Fi sharing'),
                  ),
                )
              else
                Tip(
                  'Share lists with ShopIt on the other device on this Wi-Fi',
                  child: FilledButton(
                    onPressed: link.busy ? null : notifier.startSharing,
                    child: const Text('Share on this Wi-Fi'),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                'OVER THE INTERNET',
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 0.6,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              if (link.cloudLinked) ...[
                Text(
                  'Household code: ${link.cloudCode}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter that code on the other device. Both apps need an '
                  'internet connection while they are open.',
                  style: muted,
                ),
                const SizedBox(height: 8),
                Tip(
                  'Copy the household code',
                  child: TextButton(
                    onPressed: () async {
                      final code = link.cloudCode;
                      if (code == null) return;
                      await Clipboard.setData(ClipboardData(text: code));
                    },
                    child: const Text('Copy code'),
                  ),
                ),
                Tip(
                  'Stop syncing over the internet',
                  child: TextButton(
                    onPressed: link.cloudBusy ? null : notifier.leaveCloud,
                    child: const Text('Leave cloud sync'),
                  ),
                ),
              ] else ...[
                Text(
                  'Create a code on one device, then enter it on the other. '
                  'Works on mobile data, not only Wi-Fi.',
                  style: muted,
                ),
                const SizedBox(height: 8),
                Tip(
                  'Create a household code for the other device',
                  child: FilledButton(
                    onPressed: link.cloudBusy
                        ? null
                        : notifier.createCloudHousehold,
                    child: const Text('Create cloud code'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  decoration: const InputDecoration(
                    labelText: 'Code from the other device',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                  maxLength: 8,
                  enabled: !link.cloudBusy,
                ),
                Tip(
                  'Join the household with that code',
                  child: OutlinedButton(
                    onPressed: link.cloudBusy
                        ? null
                        : () => notifier.joinCloudHousehold(_code.text),
                    child: const Text('Join with code'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        Tip(
          'Close',
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }

  String _when(String channel, DateTime? time) {
    if (time == null) return '$channel: not synced yet.';
    final seconds = DateTime.now().difference(time).inSeconds;
    if (seconds < 10) return '$channel: synced just now.';
    if (seconds < 60) return '$channel: synced ${seconds}s ago.';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$channel: synced ${minutes}m ago.';
    return '$channel: synced ${minutes ~/ 60}h ago.';
  }
}
