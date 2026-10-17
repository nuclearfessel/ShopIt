import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/keyline/keyline_icon.dart';
import '../../ui/tip.dart';

/// How a pantry list shows amounts: low or stocked, or an exact number,
/// applied to every item at once. A single item can still differ.
class PantryItemsSettingDialog extends ConsumerStatefulWidget {
  const PantryItemsSettingDialog({super.key, required this.list});

  final ShoppingList list;

  @override
  ConsumerState<PantryItemsSettingDialog> createState() =>
      _PantryItemsSettingDialogState();
}

class _PantryItemsSettingDialogState
    extends ConsumerState<PantryItemsSettingDialog> {
  late String _mode = widget.list.quantityMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget option(String value, String title, String subtitle) => ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: KeylineIcon(
        _mode == value ? KeylineIcons.circleCheck : KeylineIcons.circle,
      ),
      title: Tip(
        'Show every item as ${value == 'level' ? 'low or stocked' : 'an exact amount'}',
        child: Text(title),
      ),
      subtitle: Text(subtitle),
      onTap: () => setState(() => _mode = value),
    );

    return AlertDialog(
      title: Text('Amounts for "${widget.list.name}"'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How should the items on this list show how much you have?',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              option(
                'level',
                'Low or stocked',
                'Tap to switch an item between Low and Full.',
              ),
              option(
                'number',
                'Exact amounts',
                'Show an exact amount, like 3 cans, and count it up or down.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        Tip(
          'Close without changing anything',
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
        Tip(
          'Use this for every item on the list, and for new items',
          child: FilledButton(
            onPressed: () async {
              await ref
                  .read(databaseProvider)
                  .setPantryQuantityMode(widget.list.id, _mode);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Apply to all'),
          ),
        ),
      ],
    );
  }
}
