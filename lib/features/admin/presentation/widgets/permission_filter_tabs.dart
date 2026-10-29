import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../cubit/admin_permissions_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/app_dimens.dart';

class PermissionFilterTabs extends StatelessWidget {
  const PermissionFilterTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final active = context.select<AdminPermissionsCubit, String>(
      (c) => c.state.filter,
    );

    const filters = ['all', 'pending', 'approved', 'rejected'];
    final labels = {
      'all': LangKeys.all.tr(),
      'pending': LangKeys.pending.tr(),
      'approved': LangKeys.approved.tr(),
      'rejected': LangKeys.adminRejected.tr(),
    };

    return Row(
      children: filters
          .map(
            (f) => Expanded(
              child: GestureDetector(
                onTap: () => context.read<AdminPermissionsCubit>().setFilter(f),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    color: active == f
                        ? context.color.primary
                        : context.color.muted,
                    borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  ),
                  child: Text(
                    labels[f] ?? f,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.label.copyWith(
                      color: active == f
                          ? context.color.primaryForeground
                          : context.color.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
