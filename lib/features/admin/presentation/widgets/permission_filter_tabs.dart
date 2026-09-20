import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../cubit/admin_permissions_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';

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
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active == f
                        ? context.color.primary
                        : context.color.muted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    labels[f] ?? f,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active == f
                          ? context.color.primaryForeground
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
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
