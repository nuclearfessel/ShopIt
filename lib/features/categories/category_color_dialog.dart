import 'package:flutter/material.dart';

import '../../ui/tip.dart';

/// Preset header colours (ARGB) for category headers.
const List<int> kCategoryPresetColors = [
  0xFF00ACC1,
  0xFF43A047,
  0xFF9E9D24,
  0xFFFFB300,
  0xFFFB8C00,
  0xFFF4511E,
  0xFFE53935,
  0xFFD81B60,
  0xFF8E24AA,
  0xFF3949AB,
  0xFF1E88E5,
  0xFF6D4C41,
];

/// What the colour dialog returns: a colour, or null for "automatic".
class CategoryColorChoice {
  const CategoryColorChoice(this.argb);
  final int? argb;
}

/// Pick a header colour for one category: a preset, a custom colour, or the
/// automatic one. Returns null if cancelled. The colour applies to the category
/// on every list.
Future<CategoryColorChoice?> showCategoryColorDialog(
  BuildContext context, {
  required String category,
  required int? current,
}) => showDialog<CategoryColorChoice>(
  context: context,
  builder: (_) => _CategoryColorDialog(category: category, current: current),
);

class _CategoryColorDialog extends StatefulWidget {
  const _CategoryColorDialog({required this.category, required this.current});

  final String category;
  final int? current;

  @override
  State<_CategoryColorDialog> createState() => _CategoryColorDialogState();
}

class _CategoryColorDialogState extends State<_CategoryColorDialog> {
  /// The colour chosen so far; null means automatic.
  late int? _chosen = widget.current;

  late double _hue = _hsv(widget.current).hue;
  late double _value = _hsv(widget.current).value;

  static HSVColor _hsv(int? argb) => argb == null
      ? const HSVColor.fromAHSV(1, 190, 0.75, 0.75)
      : HSVColor.fromColor(Color(argb));

  int get _custom =>
      HSVColor.fromAHSV(1, _hue, 0.75, _value).toColor().toARGB32();

  String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AlertDialog(
      title: Text('Color for "${widget.category}"'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PRESET COLORS', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final argb in kCategoryPresetColors)
                    Tip(
                      'Use ${_hex(argb)}',
                      child: InkResponse(
                        onTap: () => setState(() => _chosen = argb),
                        radius: 24,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(argb),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _chosen == argb
                                  ? scheme.onSurface
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('CUSTOM COLOR', style: theme.textTheme.labelLarge),
              Row(
                children: [
                  const SizedBox(width: 56, child: Text('Hue')),
                  Expanded(
                    child: Tip(
                      'Slide to choose the color',
                      child: Slider(
                        value: _hue,
                        max: 360,
                        onChanged: (v) => setState(() {
                          _hue = v;
                          _chosen = _custom;
                        }),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const SizedBox(width: 56, child: Text('Darkness')),
                  Expanded(
                    child: Tip(
                      'Slide to make it lighter or darker',
                      child: Slider(
                        value: _value,
                        min: 0.2,
                        onChanged: (v) => setState(() {
                          _value = v;
                          _chosen = _custom;
                        }),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _chosen == null
                          ? scheme.surfaceContainerHighest
                          : Color(_chosen!),
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.outline),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _chosen == null
                          ? 'Automatic color'
                          : 'Current color ${_hex(_chosen!)}',
                    ),
                  ),
                  Tip(
                    'Go back to the automatic color',
                    child: TextButton(
                      onPressed: () => setState(() => _chosen = null),
                      child: const Text('Automatic'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        Tip(
          'Close without changing the color',
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
        Tip(
          'Use this color on every list',
          child: FilledButton(
            onPressed: () =>
                Navigator.pop(context, CategoryColorChoice(_chosen)),
            child: const Text('Save'),
          ),
        ),
      ],
    );
  }
}
