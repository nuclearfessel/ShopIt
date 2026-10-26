import 'package:flutter_test/flutter_test.dart';
import 'package:shop_it/features/settings/swipe_actions.dart';

void main() {
  test('swipe actions default to check on the right and delete on the left', () {
    final actions = swipeActionsFromPrefs(const {});
    expect(actions.phoneRight, ItemSwipeAction.check);
    expect(actions.phoneLeft, ItemSwipeAction.delete);
    expect(actions.rightFor(desktop: true), ItemSwipeAction.check);
    expect(actions.leftFor(desktop: true), ItemSwipeAction.delete);
    expect(actions.rightFor(desktop: false), ItemSwipeAction.check);
  });

  test('each side can be stored as check or delete', () {
    final actions = swipeActionsFromPrefs(const {
      'swipe_phone_right': 'delete',
      'swipe_phone_left': 'check',
      'swipe_desktop_right': 'delete',
      'swipe_desktop_left': 'check',
    });
    expect(actions.phoneRight, ItemSwipeAction.delete);
    expect(actions.phoneLeft, ItemSwipeAction.check);
    expect(actions.desktopRight, ItemSwipeAction.delete);
    expect(actions.desktopLeft, ItemSwipeAction.check);
    expect(ItemSwipeAction.check.label, 'Check or uncheck');
    expect(ItemSwipeAction.delete.label, 'Delete');
  });
}
