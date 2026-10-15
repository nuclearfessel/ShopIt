import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/tip.dart';
import 'device_link_controller.dart';

/// Turn sharing on. The other device does the same, and the two find each other.
class DeviceLinkDialog extends ConsumerWidget {
  const DeviceLinkDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Turn this on here and on the other device. Lists you add on '
              'either one show up on the other while both apps are open on '
              'the same Wi-Fi.',
              style: muted,
            ),
            const SizedBox(height: 12),
            Text(link.summary, style: theme.textTheme.bodyMedium),
            if (link.lastSync != null) ...[
              const SizedBox(height: 4),
              Text(_when(link), style: theme.textTheme.bodySmall),
            ],
            if (link.sharing && Platform.isWindows) ...[
              const SizedBox(height: 12),
              Text(
                'If Windows asks whether to allow Shop-it on private networks, '
                'choose allow. The phone cannot connect until you do.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (link.error != null) ...[
              const SizedBox(height: 12),
              Text(
                link.error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (link.sharing)
              Tip(
                'Stop sharing lists',
                child: TextButton(
                  onPressed: link.busy ? null : notifier.stop,
                  child: const Text('Stop sharing'),
                ),
              )
            else
              Tip(
                'Share lists with Shop-it on the other device',
                child: FilledButton(
                  onPressed: link.busy ? null : notifier.startSharing,
                  child: const Text('Share on this Wi-Fi'),
                ),
              ),
          ],
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

  String _when(DeviceLinkState link) {
    final time = link.lastSync;
    if (time == null) return 'Not synced yet.';
    final seconds = DateTime.now().difference(time).inSeconds;
    if (seconds < 10) return 'Synced just now.';
    if (seconds < 60) return 'Synced ${seconds}s ago.';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return 'Synced ${minutes}m ago.';
    return 'Synced ${minutes ~/ 60}h ago.';
  }
}
