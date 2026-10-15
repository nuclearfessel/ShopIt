import 'package:flutter/material.dart';

import 'category_color.dart';
import 'tip.dart';

/// A category's header on a list: a colour bar and the name in capitals. Tap it
/// (when [onTap] is given) to change the category's colour.
class CategoryHeader extends StatelessWidget {
  const CategoryHeader(this.text, {super.key, this.color, this.onTap});

  final String text;

  /// The category's chosen colour; null means the automatic one.
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? automaticCategoryColor(text, theme.brightness);
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 16, 4),
      child: Row(
        children: [
          Container(width: 4, height: 22, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: accent,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Tip(
      'Change the color of "$text"',
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
