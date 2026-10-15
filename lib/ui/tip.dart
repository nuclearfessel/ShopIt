import 'package:flutter/material.dart';

/// A tooltip with the app's standard timing. Every control the user can click
/// or tap should have one; wrap buttons (which have no tooltip of their own)
/// and the text of tappable rows in a [Tip].
class Tip extends StatelessWidget {
  const Tip(this.message, {super.key, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: message,
    waitDuration: const Duration(milliseconds: 500),
    child: child,
  );
}
