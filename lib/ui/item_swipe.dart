import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/swipe_actions.dart';

/// Swipe right or left to check or delete, using the settings for this device.
class ItemSwipe extends ConsumerWidget {
  const ItemSwipe({
    super.key,
    required this.swipeKey,
    required this.child,
    required this.onCheck,
    required this.onDelete,
  });

  final Key swipeKey;
  final Widget child;
  final VoidCallback onCheck;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(swipeActionsProvider);
    final desktop = swipeActionsUseDesktop;
    final right = actions.rightFor(desktop: desktop);
    final left = actions.leftFor(desktop: desktop);

    return Dismissible(
      key: swipeKey,
      direction: DismissDirection.horizontal,
      background: _background(right, Alignment.centerLeft),
      secondaryBackground: _background(left, Alignment.centerRight),
      confirmDismiss: (direction) async {
        final action = direction == DismissDirection.startToEnd ? right : left;
        if (action == ItemSwipeAction.check) {
          onCheck();
          return false;
        }
        return true;
      },
      onDismissed: (_) => onDelete(),
      child: child,
    );
  }
}

Widget _background(ItemSwipeAction action, Alignment alignment) {
  final check = action == ItemSwipeAction.check;
  return Container(
    color: check ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Text(
      check ? 'Check' : 'Delete',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    ),
  );
}
