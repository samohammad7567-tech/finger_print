import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Everything on the confirm-identity dialog.
///
/// Split from the dialog that owns it so the dialog stays about behaviour —
/// what is typed, whether it checked out, what happens then — and this stays
/// about layout. It holds no state.
class AdminPasswordBody extends StatelessWidget {
  const AdminPasswordBody({
    super.key,
    required this.reason,
    required this.controller,
    required this.obscured,
    required this.isChecking,
    required this.errorKey,
    required this.onObscuredToggled,
    required this.onChanged,
    required this.onSubmitted,
    required this.onCancel,
    required this.onConfirm,
  });

  /// The localization key for the line explaining what is being authorised.
  final String reason;

  final TextEditingController controller;
  final bool obscured;
  final bool isChecking;

  /// A localization key, or null while nothing has gone wrong.
  final String? errorKey;

  final VoidCallback onObscuredToggled;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onCancel;

  /// Null while there is nothing to check, which is also what disables the
  /// button.
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: context.color.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.shield_outlined,
            size: 24,
            color: context.color.primary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          LangKeys.confirmIdentityTitle.tr(),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          reason.tr(),
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: scheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: controller,
          hint: LangKeys.confirmIdentityPassword.tr(),
          prefixIcon: Icons.lock_outline,
          obscureText: obscured,
          autofocus: true,
          onChanged: onChanged,
          onSubmitted: (_) => onSubmitted(),
          suffixIcon: IconButton(
            icon: Icon(
              obscured
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 18,
            ),
            onPressed: onObscuredToggled,
          ),
        ),
        if (errorKey != null) ...[
          const SizedBox(height: 8),
          Text(
            errorKey!.tr(),
            style: TextStyle(fontSize: 11, color: context.color.destructive),
          ),
        ],
        const SizedBox(height: 20),
        _actions(context),
      ],
    );
  }

  Widget _actions(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: isChecking ? null : onCancel,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(LangKeys.cancel.tr()),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: onConfirm != null
                ? context.color.primary
                : context.color.muted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: MaterialButton(
            onPressed: onConfirm,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: isChecking
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.color.primaryForeground,
                    ),
                  )
                : Text(
                    LangKeys.confirmIdentityConfirm.tr(),
                    style: TextStyle(
                      color: context.color.primaryForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    ],
  );
}
