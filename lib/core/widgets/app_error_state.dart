import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../localization/lang_keys.dart';
import '../style/theme/app_dimens.dart';
import '../style/theme/app_text_styles.dart';
import '../style/theme/context_extension.dart';
import 'app_icon_badge.dart';

/// What a screen shows when its load failed.
///
/// Distinct from [AppEmptyState], and the distinction matters: empty means the
/// question was answered and the answer was nothing, which is ordinary.
/// This means the question was never answered — so it is drawn in the
/// destructive register and, above all, it offers the way out. A failure with
/// no retry leaves an operator restarting the app to reload a table.
///
/// [messageKey] is a key, not a sentence: the data sources map their failures
/// to the stable keys in [LangKeys] through `ErrorMapper`, and this translates
/// whichever one arrived. It falls back to the generic load failure, because a
/// cubit that forgot to set one should still produce a readable screen.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.messageKey,
    this.onRetry,
    this.isRetrying = false,
    this.icon = Icons.error_outline,
  });

  final String? messageKey;

  /// Omit only where there is genuinely nothing to try again — a screen whose
  /// failure was a refusal rather than a fault.
  final VoidCallback? onRetry;

  /// Disables the button and spins inside it, so a slow retry cannot be
  /// double-fired and does not look ignored.
  final bool isRetrying;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.space2xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppIconBadge.tinted(
              icon: icon,
              color: context.color.destructive,
              size: 48,
              radius: AppDimens.radiusLg,
              tintAlpha: 0.14,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              (messageKey ?? LangKeys.errorLoadFailed).tr(),
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: context.color.foreground,
              ),
            ),
            if (retry != null) ...<Widget>[
              const SizedBox(height: AppDimens.spaceLg),
              _RetryButton(onRetry: retry, isRetrying: isRetrying),
            ],
          ],
        ),
      ),
    );
  }
}

/// A quiet outlined button. The failure is already the loud thing on screen;
/// the way out of it does not need to compete.
class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.onRetry, required this.isRetrying});

  final VoidCallback onRetry;
  final bool isRetrying;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimens.controlHeight,
      child: OutlinedButton(
        onPressed: isRetrying ? null : onRetry,
        style: OutlinedButton.styleFrom(
          foregroundColor: context.color.foreground,
          side: BorderSide(color: context.color.border),
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radius),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (isRetrying)
              SizedBox(
                width: AppDimens.iconSm,
                height: AppDimens.iconSm,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.color.mutedForeground,
                ),
              )
            else
              Icon(
                Icons.refresh,
                size: AppDimens.iconSm,
                color: context.color.mutedForeground,
              ),
            const SizedBox(width: AppDimens.spaceSm),
            Text(LangKeys.retry.tr(), style: AppTextStyles.controlSemiBold),
          ],
        ),
      ),
    );
  }
}
