import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_note_banner.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/app_dimens.dart';

/// One counted outcome. Zero still shows: "0 new" is the answer to "is this
/// going to add anybody", and hiding it leaves the question open.
class PushSummaryRow extends StatelessWidget {
  const PushSummaryRow({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    this.hint,
  });

  final IconData icon;
  final String label;
  final int count;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final hintText = hint;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppDimens.iconMd, color: context.color.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count · ${label.tr()}',
                  style: AppTextStyles.bodySemiBold,
                ),
                if (hintText != null)
                  Text(
                    hintText.tr(),
                    style: AppTextStyles.meta.copyWith(
                      color: context.color.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A tinted aside — reassurance or warning, same shape either way.
class PushSummaryNote extends StatelessWidget {
  const PushSummaryNote({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppNoteBanner(
      icon: icon,
      text: text,
      color: color,
      iconSize: 16,
      borderAlpha: 0.30,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: AppDimens.spaceSm,
      ),
    );
  }
}
