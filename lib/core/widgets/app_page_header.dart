import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization/lang_keys.dart';
import '../style/theme/app_dimens.dart';
import '../style/theme/app_text_styles.dart';
import '../style/theme/context_extension.dart';

/// Title row for a page that was pushed onto the stack.
///
/// The tab shell's app bar is the same on every page of a tab, so it cannot
/// carry the way back — the back button belongs beside the page title, where
/// the admin expects to find it. The arrow flips itself in Arabic.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({super.key, required this.title, this.fallbackLocation});

  final String title;

  /// Where to go when the page was opened directly rather than pushed — a
  /// deep link leaves nothing to pop back to.
  final String? fallbackLocation;

  @override
  Widget build(BuildContext context) {
    final muted = context.color.mutedForeground;

    return Row(
      children: [
        Tooltip(
          message: LangKeys.back.tr(),
          child: Material(
            color: muted.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppDimens.radius),
            child: InkWell(
              onTap: () => _goBack(context),
              borderRadius: BorderRadius.circular(AppDimens.radius),
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceXs),
                child: Icon(
                  Icons.arrow_back,
                  size: AppDimens.iconMd,
                  color: muted,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppDimens.spaceMd),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.heading.copyWith(
              color: context.color.foreground,
            ),
          ),
        ),
      ],
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final fallback = fallbackLocation;
    if (fallback != null) context.go(fallback);
  }
}
