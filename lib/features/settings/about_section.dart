import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'legal_copy.dart';

const shopItSiteUrl = 'https://nuclearfessel.github.io/ShopIt/';

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

  Future<void> _openSite() async {
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(shopItSiteUrl));
    } on PlatformException {
      // A missing browser or a platform launch failure needs visible feedback.
    }
    if (!mounted || opened) return;
    _showNotice(
      context,
      "Couldn't open ShopIt site",
      "ShopIt couldn't open the site link. "
          'Open this address in your browser instead:\n\n$shopItSiteUrl',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final version = _version;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
    );
    // Pre-rasterized PNGs stay smooth on every platform; flutter_svg jaggies
    // the curved Daily Circle seams at About size.
    final lockupAsset = theme.brightness == Brightness.dark
        ? 'assets/brand/shopit-horizontal-dark.png'
        : 'assets/brand/shopit-horizontal-light.png';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          lockupAsset,
          height: 56,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          filterQuality: FilterQuality.high,
          semanticLabel: 'ShopIt',
        ),
        const SizedBox(height: 8),
        Text(
          'An open source shopping, pantry, and recipe app.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        _AboutLink(
          label: shopItSiteUrl,
          tooltip: 'Open the ShopIt site',
          onTap: _openSite,
        ),
        const SizedBox(height: 4),
        _AboutLink(
          label: 'Privacy',
          tooltip: 'Read what ShopIt sends and how to delete it',
          onTap: () => _showNotice(context, 'Privacy', shopItPrivacyNotice),
        ),
        const SizedBox(height: 4),
        _AboutLink(
          label: 'Licenses',
          tooltip: 'Read the licenses for ShopIt and the pieces it includes',
          onTap: () => _showNotice(context, 'Licenses', shopItLicenses),
        ),
        if (version != null) ...[
          const SizedBox(height: 4),
          Text('Version $version', style: muted),
        ],
      ],
    );
  }
}

class _AboutLink extends StatelessWidget {
  const _AboutLink({
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary,
    );
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Text(label, style: style),
        ),
      ),
    );
  }
}

void _showNotice(BuildContext context, String title, String body) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(title),
      content: SizedBox(width: 420, child: Text(body)),
      actions: [
        Tooltip(
          message: 'Close',
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ),
      ],
    ),
  );
}
