import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The About block at the bottom of Settings, on Windows and Android.
class AboutSection extends StatefulWidget {
  const AboutSection({super.key});

  @override
  State<AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<AboutSection> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      if (!mounted) return;
      setState(() => _version = version.isEmpty ? null : version);
    } on Object {
      if (mounted) setState(() => _version = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final version = _version;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ShopIt', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'A shopping and pantry list app.',
          style: theme.textTheme.bodyMedium,
        ),
        if (version != null) ...[
          const SizedBox(height: 4),
          Text('Version $version', style: muted),
        ],
      ],
    );
  }
}
