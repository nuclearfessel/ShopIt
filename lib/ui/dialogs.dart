import 'package:flutter/material.dart';

import 'tip.dart';

/// Asks the user to confirm something. Returns true only on the confirm button.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  String confirmTip = 'Go ahead',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        Tip(
          'Close without changing anything',
          child: TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
        ),
        Tip(
          confirmTip,
          child: FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Asks for a name. Returns null if cancelled or left empty.
Future<String?> askNameDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String confirmLabel = 'Create',
  String confirmTip = 'Create it',
}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        Tip(
          'Close without changing anything',
          child: TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ),
        Tip(
          confirmTip,
          child: FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: Text(confirmLabel),
          ),
        ),
      ],
    ),
  ).then((v) => (v == null || v.isEmpty) ? null : v);
}
