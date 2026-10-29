import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_icon_badge.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(LangKeys.logoutConfirmTitle.tr()),
            content: Text(LangKeys.logoutConfirmMsg.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(LangKeys.cancel.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  LangKeys.confirm.tr(),
                  style: TextStyle(color: context.color.destructive),
                ),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await getIt<AuthCubit>().signOut();
        if (context.mounted) context.go('/login');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? context.color.borderSoft
              : context.color.primaryForeground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? context.color.borderSoft
                : context.color.borderSoft,
          ),
        ),
        child: Row(
          children: [
            AppIconBadge.tinted(
              icon: Icons.logout,
              color: context.color.destructive,
              size: 32,
              radius: 10,
              tintAlpha: 0.2,
            ),
            const SizedBox(width: 12),
            Text(
              LangKeys.signOut.tr(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.color.destructive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
