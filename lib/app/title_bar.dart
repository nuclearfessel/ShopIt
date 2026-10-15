import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../ui/keyline/keyline_icon.dart';

/// Custom window title bar that replaces the native Windows one so the whole
/// window, chrome included, is drawn in the app's own style.
class AppTitleBar extends StatefulWidget {
  const AppTitleBar({super.key});

  @override
  State<AppTitleBar> createState() => _AppTitleBarState();
}

class _AppTitleBarState extends State<AppTitleBar> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _maximized = v);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lime = IconTheme.of(context).color ?? scheme.primary;
    return Material(
      color: scheme.surfaceContainer,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: DragToMoveArea(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: _toggleMaximize,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        KeylineIcon(
                          KeylineIcons.shoppingBasket,
                          size: 20,
                          color: lime,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Shop-it',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _Dot(
              icon: KeylineIcons.minus,
              color: lime,
              onTap: () => windowManager.minimize(),
            ),
            _Dot(
              icon: _maximized ? KeylineIcons.copy : KeylineIcons.square,
              color: lime,
              onTap: _toggleMaximize,
            ),
            _Dot(
              icon: KeylineIcons.x,
              color: lime,
              hover: scheme.error,
              onTap: () => windowManager.close(),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }
}

/// Round window button.
class _Dot extends StatefulWidget {
  const _Dot({
    required this.icon,
    required this.color,
    required this.onTap,
    this.hover,
  });
  final KeylineIconData icon;
  final Color color;
  final Color? hover;
  final VoidCallback onTap;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> {
  bool _over = false;

  @override
  Widget build(BuildContext context) {
    final bg = _over
        ? (widget.hover ?? widget.color).withValues(alpha: 0.18)
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _over = true),
      onExit: (_) => setState(() => _over = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: KeylineIcon(
            widget.icon,
            size: 16,
            color: _over && widget.hover != null ? widget.hover : widget.color,
          ),
        ),
      ),
    );
  }
}
