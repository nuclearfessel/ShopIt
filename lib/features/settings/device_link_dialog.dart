import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_factor.dart';
import '../../services/barcode_scanner.dart';
import '../../services/cloud_mailbox.dart';
import '../../services/sync_qr.dart';
import '../../ui/tip.dart';
import 'device_link_controller.dart';
import 'sync_qr_view.dart';

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
    final errorStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.error,
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
                'Create a code on one device and enter it on the other. The '
                'code is the key, so it is not sent over Wi-Fi. After both '
                'devices have it, lists sync on the same Wi-Fi and, while '
                'the apps are open, over the internet.',
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
              if (link.cloudLinked) ...[
                const SizedBox(height: 4),
                Text(
                  _when('Cloud', link.lastCloudSync),
                  style: theme.textTheme.bodySmall,
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
              if (link.sharing && !link.cloudLinked) ...[
                const SizedBox(height: 8),
                Text(
                  'This Wi-Fi is on. Lists move after both devices have the '
                  'same code.',
                  style: muted,
                ),
              ],
              if (link.wifiError != null) ...[
                const SizedBox(height: 4),
                Text(link.wifiError!, style: errorStyle),
              ],
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
                if (link.cloudError != null) ...[
                  const SizedBox(height: 4),
                  Text(link.cloudError!, style: errorStyle),
                ],
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
                  maxLength: 40,
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
                if (link.cloudError != null) ...[
                  const SizedBox(height: 4),
                  Text(link.cloudError!, style: errorStyle),
                ],
              ],
              if (desktopSearchKeys) ...[
                const SizedBox(height: 12),
                Tip(
                  'Show a QR code the phone can scan to start sync',
                  child: OutlinedButton(
                    onPressed: link.cloudBusy ? null : _showSyncQr,
                    child: const Text('Show QR code'),
                  ),
                ),
              ],
              if (platformScansBarcodes) ...[
                const SizedBox(height: 12),
                Tip(
                  'Scan the QR code shown on the computer',
                  child: OutlinedButton(
                    onPressed: link.cloudBusy ? null : _scanSyncQr,
                    child: const Text('Scan QR code'),
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

  Future<void> _showSyncQr() async {
    final notifier = ref.read(deviceLinkProvider.notifier);
    if (!ref.read(deviceLinkProvider).cloudLinked) {
      await notifier.createCloudHousehold();
    }
    if (!mounted) return;
    final code = ref.read(deviceLinkProvider).cloudCode;
    if (code == null || !isHouseholdCode(code)) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan to sync'),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'On the phone, open Share lists and tap Scan QR code.',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 240,
                height: 240,
                child: SyncQrView(payload: syncQrPayload(code)),
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
      ),
    );
  }

  Future<void> _scanSyncQr() async {
    final raw = await barcodeScanner.scan(sync: true);
    if (!mounted || raw == null) return;
    await ref.read(deviceLinkProvider.notifier).joinFromQr(raw);
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
