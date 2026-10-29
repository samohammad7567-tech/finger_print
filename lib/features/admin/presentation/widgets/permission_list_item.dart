import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../permissions/data/models/permission_request_model.dart';
import '../cubit/admin_permissions_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/app_dimens.dart';

class PermissionListItem extends StatelessWidget {
  const PermissionListItem({super.key, required this.permission});

  final PermissionRequestModel permission;

  @override
  Widget build(BuildContext context) {
    final p = permission;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.employeeName ?? '',
                      style: AppTextStyles.controlSemiBold,
                    ),
                    Text(
                      p.permissionType.tr(),
                      style: AppTextStyles.caption.copyWith(
                        color: context.color.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    p.date,
                    style: AppTextStyles.caption.copyWith(
                      color: context.color.mutedForeground,
                    ),
                  ),
                  _StatusLabel(status: p.status),
                ],
              ),
            ],
          ),
          if (p.reason != null && p.reason!.isNotEmpty) ...[
            const SizedBox(height: AppDimens.spaceSm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimens.spaceSm),
              decoration: BoxDecoration(
                color: context.color.muted,
                borderRadius: BorderRadius.circular(AppDimens.radius),
              ),
              child: Text(
                p.reason!,
                style: AppTextStyles.caption.copyWith(
                  color: context.color.mutedForeground,
                ),
              ),
            ),
          ],
          if (p.status == 'pending') ...[
            const SizedBox(height: AppDimens.spaceMd),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: LangKeys.adminApprove.tr(),
                    icon: Icons.check_circle,
                    color: context.color.success,
                    onTap: () => context
                        .read<AdminPermissionsCubit>()
                        .updateStatus(p.id, 'approved'),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: _ActionButton(
                    label: LangKeys.adminReject.tr(),
                    icon: Icons.cancel,
                    color: context.color.destructive,
                    onTap: () => context
                        .read<AdminPermissionsCubit>()
                        .updateStatus(p.id, 'rejected'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => context.color.success,
      'rejected' => context.color.destructive,
      _ => context.color.warning,
    };
    return Text(status.tr(), style: AppTextStyles.label.copyWith(color: color));
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AppDimens.iconSm,
              color: context.color.primaryForeground,
            ),
            const SizedBox(width: AppDimens.spaceXs),
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                color: context.color.primaryForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
