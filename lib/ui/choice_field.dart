import 'package:flutter/material.dart';

import 'keyline/keyline_icon.dart';
import 'tip.dart';

/// One choice in a [ChoiceField].
class Choice<T> {
  const Choice(this.value, this.label);

  final T value;
  final String label;
}

/// A pull-down that opens a card of rows, styled like the item suggestions
/// under the add bar (same card color and shape, same row density, selected
/// row in bold with a check) instead of Material's stock dropdown.
///
/// With a [decoration] it looks like a text field; without one it is a plain
/// row, for use directly on a screen.
class ChoiceField<T> extends StatefulWidget {
  const ChoiceField({
    super.key,
    required this.choices,
    required this.value,
    required this.onChanged,
    this.decoration,
    this.textStyle,
  });

  final List<Choice<T>> choices;
  final T? value;
  final ValueChanged<T> onChanged;
  final InputDecoration? decoration;
  final TextStyle? textStyle;

  @override
  State<ChoiceField<T>> createState() => _ChoiceFieldState<T>();
}

class _ChoiceFieldState<T> extends State<ChoiceField<T>> {
  final _fieldKey = GlobalKey();

  // Measured when the menu opens (a LayoutBuilder would break inside dialogs,
  // which ask their contents for intrinsic sizes).
  double _width = 280;

  List<Choice<T>> get choices => widget.choices;
  T? get value => widget.value;
  InputDecoration? get decoration => widget.decoration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = choices.where((c) => c.value == value).firstOrNull;
    final style = widget.textStyle ?? theme.textTheme.bodyLarge;

    final width = _width;
    return KeyedSubtree(
      key: _fieldKey,
      child: Builder(
        builder: (context) {
          return MenuAnchor(
            crossAxisUnconstrained: false,
            style: MenuStyle(
              backgroundColor: WidgetStatePropertyAll(
                scheme.surfaceContainerLow,
              ),
              surfaceTintColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
              elevation: const WidgetStatePropertyAll(3),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(vertical: 4),
              ),
              minimumSize: WidgetStatePropertyAll(Size(width, 0)),
              maximumSize: WidgetStatePropertyAll(Size(width, 320)),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
              ),
            ),
            menuChildren: [
              for (final c in choices)
                MenuItemButton(
                  style: ButtonStyle(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 16),
                    ),
                    textStyle: WidgetStatePropertyAll(
                      theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: c.value == value
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
                  ),
                  trailingIcon: c.value == value
                      ? KeylineIcon(KeylineIcons.check, color: scheme.primary)
                      : null,
                  onPressed: () => widget.onChanged(c.value),
                  child: SizedBox(
                    width: width - 32 - (c.value == value ? 40 : 0),
                    child: Tip(
                      'Choose "${c.label.isEmpty ? 'No unit' : c.label}"',
                      child: Text(
                        c.label.isEmpty ? ' ' : c.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
            ],
            builder: (context, controller, _) {
              final label = Text(
                selected?.label ?? '',
                overflow: TextOverflow.ellipsis,
                style: style,
              );
              final chevron = KeylineIcon(
                KeylineIcons.chevronDown,
                color: scheme.onSurfaceVariant,
              );
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  if (controller.isOpen) return controller.close();
                  final size = _fieldKey.currentContext?.size;
                  if (size != null && size.width != _width) {
                    setState(() => _width = size.width);
                  }
                  controller.open();
                },
                child: decoration == null
                    ? Padding(
                        // 12 in from the edges, like the icons inside the search field.
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(child: label),
                            chevron,
                          ],
                        ),
                      )
                    : InputDecorator(
                        decoration: decoration!.copyWith(suffixIcon: chevron),
                        isEmpty: selected == null,
                        child: label,
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
