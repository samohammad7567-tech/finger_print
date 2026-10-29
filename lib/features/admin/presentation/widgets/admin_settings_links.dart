import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/app_dimens.dart';

/// The admin's tools: the hours everything is judged by, the terminal, and the
/// backup. The punch report is not here — it lives on the bottom bar, because
/// it is a place to work rather than a setting.
class AdminSettingsLinks extends StatelessWidget {
  const AdminSettingsLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final links = [
      (Icons.schedule, LangKeys.scheduleTitle, '/admin/work-schedule'),
      (Icons.access_time, LangKeys.shiftsTitle, '/admin/shifts'),
      (Icons.event_busy, LangKeys.holidaysTitle, '/admin/holidays'),
      (Icons.apartment, LangKeys.departmentsTitle, '/admin/departments'),
      (Icons.fingerprint, LangKeys.deviceTitle, '/admin/device'),
      (Icons.backup_outlined, LangKeys.backupTitle, '/admin/backup'),
    ];

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (index, link) in links.indexed) ...[
            if (index > 0) Divider(height: 1, color: context.color.border),
            InkWell(
              onTap: () => context.push(link.$3),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceLg,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      link.$1,
                      size: AppDimens.iconLg,
                      color: context.color.primary,
                    ),
                    const SizedBox(width: AppDimens.spaceMd),
                    Expanded(
                      child: Text(link.$2.tr(), style: AppTextStyles.control),
                    ),
                    const Icon(Icons.chevron_right, size: AppDimens.iconLg),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
