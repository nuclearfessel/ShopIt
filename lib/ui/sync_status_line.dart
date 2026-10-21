import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/device_link_controller.dart';

/// A quiet line under the list name: synced just now, waiting, or the short
/// error. Hidden when lists are not being shared.
class SyncStatusLine extends ConsumerWidget {
  const SyncStatusLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(deviceLinkProvider);
    final text = link.listLine;
    if (text.isEmpty) return const SizedBox.shrink();
    final failed = link.wifiError != null || link.cloudError != null;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: failed
              ? scheme.error
              : scheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
