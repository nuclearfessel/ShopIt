import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/tip.dart';
import 'device_link_controller.dart';

/// Share this device's lists, or connect to a device that is already sharing.
class DeviceLinkDialog extends ConsumerStatefulWidget {
  const DeviceLinkDialog({super.key});

  @override
  ConsumerState<DeviceLinkDialog> createState() => _DeviceLinkDialogState();
}

class _DeviceLinkDialogState extends ConsumerState<DeviceLinkDialog> {
  final _address = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _address.dispose();
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

    return AlertDialog(
      title: const Text('Share lists'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_intro(link), style: muted),
              const SizedBox(height: 12),
              if (link.hosting) ..._hosting(context, link, theme),
              if (link.connected) ..._connected(link, theme),
              if (link.role == DeviceRole.none) ..._setup(link),
              if (link.busy)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('Working...', style: muted),
                ),
              if (link.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    link.error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
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

  String _intro(DeviceLinkState link) {
    if (link.hosting) {
      return 'On the other device, open Share lists, choose Connect, and '
          'enter this address and code.';
    }
    if (link.connected) {
      return 'Lists you add on either device show up on the other within a '
          'few seconds, while both apps are open.';
    }
    return 'A list you add on your phone shows up on this computer, and the '
        'other way around. On one device, share. On the other, connect. '
        'Sharing from the computer is the easier direction. Lists already on '
        'each device are kept, so two lists can share a name.';
  }

  List<Widget> _hosting(
    BuildContext context,
    DeviceLinkState link,
    ThemeData theme,
  ) {
    final codeStyle = theme.textTheme.headlineSmall?.copyWith(letterSpacing: 4);
    return [
      if (link.localAddresses.isEmpty)
        const Text(
          'No Wi-Fi address was found. Join the same network as the other '
          'device, then try again.',
        )
      else ...[
        Text('Address', style: theme.textTheme.labelLarge),
        for (final address in link.localAddresses)
          SelectableText('$address:${link.port}'),
        const SizedBox(height: 8),
        Text('Code', style: theme.textTheme.labelLarge),
        SelectableText(link.code, style: codeStyle),
      ],
      if (Platform.isWindows) ...[
        const SizedBox(height: 12),
        Text(
          'If Windows asks whether to allow Shop-it on private networks, '
          'choose allow. The phone cannot connect until you do.',
          style: theme.textTheme.bodySmall,
        ),
      ],
      const SizedBox(height: 8),
      Text(_when(link), style: theme.textTheme.bodySmall),
      const SizedBox(height: 12),
      Tip(
        'Stop sharing lists',
        child: TextButton(
          onPressed: link.busy
              ? null
              : () => ref.read(deviceLinkProvider.notifier).stop(),
          child: const Text('Stop sharing'),
        ),
      ),
    ];
  }

  List<Widget> _connected(DeviceLinkState link, ThemeData theme) {
    return [
      Text(_when(link), style: theme.textTheme.bodyMedium),
      const SizedBox(height: 12),
      Tip(
        'Sync lists now',
        child: FilledButton(
          onPressed: link.busy
              ? null
              : () => ref.read(deviceLinkProvider.notifier).syncNow(),
          child: const Text('Sync now'),
        ),
      ),
      Tip(
        'Stop syncing with that device',
        child: TextButton(
          onPressed: link.busy
              ? null
              : () => ref.read(deviceLinkProvider.notifier).stop(),
          child: const Text('Disconnect'),
        ),
      ),
    ];
  }

  List<Widget> _setup(DeviceLinkState link) {
    final notifier = ref.read(deviceLinkProvider.notifier);
    return [
      Tip(
        'Let the other device connect to this one',
        child: FilledButton(
          onPressed: link.busy ? null : () => notifier.share(),
          child: const Text('Share from this device'),
        ),
      ),
      const SizedBox(height: 16),
      const Text('Or connect to a device that is sharing'),
      const SizedBox(height: 8),
      TextField(
        controller: _address,
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(
          labelText: 'Address',
          hintText: '192.168.1.20:47821',
        ),
        onSubmitted: (_) => _connect(),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _code,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        decoration: const InputDecoration(labelText: 'Code'),
        onSubmitted: (_) => _connect(),
      ),
      const SizedBox(height: 12),
      Tip(
        'Sync lists with that device',
        child: FilledButton(
          onPressed: link.busy ? null : _connect,
          child: const Text('Connect'),
        ),
      ),
    ];
  }

  void _connect() {
    ref
        .read(deviceLinkProvider.notifier)
        .connect(address: _address.text, code: _code.text);
  }

  String _when(DeviceLinkState link) {
    final time = link.lastSync;
    if (time == null) {
      return link.hosting ? 'Waiting for the other device.' : 'Not synced yet.';
    }
    final seconds = DateTime.now().difference(time).inSeconds;
    if (seconds < 10) return 'Synced just now.';
    if (seconds < 60) return 'Synced ${seconds}s ago.';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return 'Synced ${minutes}m ago.';
    return 'Synced ${minutes ~/ 60}h ago.';
  }
}
