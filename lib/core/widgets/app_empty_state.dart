import 'package:flutter/material.dart';

import '../style/theme/app_dimens.dart';
import '../style/theme/app_text_styles.dart';
import '../style/theme/context_extension.dart';
import 'app_icon_badge.dart';

/// What a list shows when the answer is legitimately nothing.
///
/// Not an error and not a wait: the query ran, and there is no data. Said in
/// the muted register, with the subtitle carrying what the operator could do
/// about it — "add the first employee", not just "no employees".
///
/// The subtitle used to read `textTheme.bodySmall`, which `AppTheme` never
/// fills in, so it silently rendered in Material's default face at Material's
/// default size. It reads from the scale now.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.space2xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppIconBadge.tinted(
              icon: icon,
              color: iconColor ?? context.color.primary,
              size: 48,
              radius: AppDimens.radiusLg,
              tintAlpha: 0.14,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.cardTitle.copyWith(
                color: context.color.foreground,
              ),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: AppDimens.spaceXs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: context.color.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
