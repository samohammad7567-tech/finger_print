import 'package:flutter/material.dart';

import '../style/theme/app_dimens.dart';
import '../style/theme/app_text_styles.dart';
import '../style/theme/context_extension.dart';

/// The app's single-line input.
///
/// Deliberately thin: the fill, the borders, the focus ring, the content
/// padding and the hint style all come from `AppTheme`'s
/// `inputDecorationTheme`, which already says an input is a *recess* taking
/// the plane below whatever it sits on. This widget used to restate every one
/// of those — a different fill, a 12px radius against the system's 4, 16/14
/// padding against 9/7 — which is why a form inside a card never quite matched
/// the controls beside it.
///
/// What is left here is the part the theme cannot know: which icon leads the
/// field, and how it behaves.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;

  /// Takes the keyboard as soon as it appears. For a field that is the only
  /// thing being asked for — a password in a confirm dialog.
  final bool autofocus;

  /// Enter, for the same case: a one-field dialog should not need the mouse.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      autofocus: autofocus,
      onSubmitted: onSubmitted,
      style: AppTextStyles.body.copyWith(color: context.color.foreground),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(
                prefixIcon,
                size: AppDimens.iconMd,
                color: context.color.subtleForeground,
              ),
        // Keeps the glyph from forcing the field taller than
        // `AppDimens.controlHeight`, which Material's 48px default would.
        prefixIconConstraints: const BoxConstraints(
          minWidth: AppDimens.iconButtonWidth,
          minHeight: AppDimens.controlHeight,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
