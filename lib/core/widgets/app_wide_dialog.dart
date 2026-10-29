import 'package:flutter/material.dart';

import '../style/theme/app_dimens.dart';

/// An [AlertDialog] sized for content rather than for a sentence.
///
/// Six dialogs in the app show a list, a plan or a path, and every one of them
/// had to widen itself by hand: an [AlertDialog] sizes to its text, so a table
/// of push rows or a full backup path either wraps to a column or overflows.
/// 460 logical pixels is the width they all settled on.
///
/// The icon beside the title is the other repeated part — it is what tells an
/// admin at a glance whether the dialog is reporting, warning or asking.
class AppWideDialog extends StatelessWidget {
  const AppWideDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon,
    this.iconColor,
    this.width = 460,
    this.scrollable = true,
  });

  final String title;

  /// Drawn before the title, tinted by [iconColor].
  final IconData? icon;
  final Color? iconColor;

  /// The dialog's body. Wrapped in a scroll view unless [scrollable] is off —
  /// turn it off when the body manages its own scrolling, e.g. a [Flexible]
  /// list under a fixed hint line.
  final Widget content;

  final List<Widget> actions;
  final double width;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final heading = Text(title);

    return AlertDialog(
      title: icon == null
          ? heading
          : Row(
              children: [
                Icon(icon, size: AppDimens.iconXl, color: iconColor),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(child: heading),
              ],
            ),
      content: SizedBox(
        width: width,
        child: scrollable ? SingleChildScrollView(child: content) : content,
      ),
      actions: actions,
    );
  }
}
