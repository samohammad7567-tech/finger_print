import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/models/permission_request_model.dart';
import '../../../../core/style/theme/context_extension.dart';

class PermissionCard extends StatelessWidget {
  const PermissionCard({super.key, required this.permission});

  final PermissionRequestModel permission;

  /// Icon, colour and label per permission type. Built per call: the
  /// colours come from the active theme rather than from constants.
  Map<String, (IconData, Color, String)> _typeConfig(BuildContext context) => {
    'travel_permission': (
      Icons.flight,
      context.color.infoSoft,
      'travel_permission_type',
    ),
    'housing_early_leave': (
      Icons.home,
      context.color.success,
      'housing_early_leave',
    ),
    'approved_early_departure': (
      Icons.access_time,
      context.color.warning,
      'approved_early_departure',
    ),
    'vacation': (Icons.calendar_today, context.color.primary, 'vacation'),
  };

  @override
  Widget build(BuildContext context) {
    final cfg =
        _typeConfig(context)[permission.permissionType] ??
        (Icons.description, context.color.primary, permission.permissionType);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cfg.$2.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cfg.$2.withValues(alpha: 0.3)),
                ),
                child: Icon(cfg.$1, size: 20, color: cfg.$2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      permission.employeeName ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      cfg.$3.tr(),
                      style: TextStyle(fontSize: 12, color: cfg.$2),
                    ),
                  ],
                ),
              ),
              Text(
                permission.date,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          if (permission.reason != null && permission.reason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              permission.reason!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${LangKeys.by.tr()} ${permission.approvedBy ?? ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.color.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: context.color.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      LangKeys.approved.tr(),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.color.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
