import 'package:flutter/material.dart';

/// How long a message with an Undo stays up before going away by itself.
const Duration kUndoSnackBarDuration = Duration(seconds: 5);

/// Shows [message] with an UNDO action.
///
/// A SnackBar with an action never goes away on its own in Flutter (it is
/// treated as needing the user's attention, for accessibility) unless told
/// not to, so this sets `persist: false` and a normal timeout. It also has a
/// close button, since a mouse user cannot swipe it away. Any earlier message
/// is replaced rather than queued behind this one.
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: kUndoSnackBarDuration,
      persist: false,
      showCloseIcon: true,
      action: SnackBarAction(label: 'UNDO', onPressed: onUndo),
    ),
  );
}

/// Shows a short message (no Undo). Like [showUndoSnackBar] it goes away by
/// itself and has a close button; a newer message replaces an older one.
void showInfoSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: kUndoSnackBarDuration,
      persist: false,
      showCloseIcon: true,
    ),
  );
}
