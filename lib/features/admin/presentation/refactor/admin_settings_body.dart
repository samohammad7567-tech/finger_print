import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../settings/presentation/cubit/settings_state.dart';
import '../widgets/admin_settings_links.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_icon_badge.dart';
import '../../../../core/widgets/app_tinted_pill.dart';
import '../../../../core/style/theme/app_text_styles.dart';
import '../../../../core/style/theme/app_dimens.dart';

class AdminSettingsBody extends StatelessWidget {
  const AdminSettingsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final authState = getIt<AuthCubit>().state;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LangKeys.settings.tr(),
                style: AppTextStyles.heading.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              GlassCard(
                child: Row(
                  children: [
                    AppIconBadge(
                      icon: Icons.shield,
                      color: context.color.primary,
                      size: 48,
                      radius: 16,
                    ),
                    const SizedBox(width: AppDimens.spaceMd),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.displayName,
                          style: AppTextStyles.brand.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        AppTintedPill(
                          label: LangKeys.adminSystemManager.tr(),
                          color: context.color.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          tintAlpha: 0.2,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.spaceSm,
                            vertical: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _tile(
                      context,
                      icon: state.isDark ? Icons.dark_mode : Icons.light_mode,
                      label: LangKeys.appearance.tr(),
                      trailing: Text(
                        state.isDark ? 'Dark' : 'Light',
                        style: AppTextStyles.caption.copyWith(
                          color: context.color.mutedForeground,
                        ),
                      ),
                      onTap: () => context.read<SettingsCubit>().toggleDark(),
                    ),
                    Divider(height: 1, color: context.color.border),
                    _tile(
                      context,
                      icon: Icons.language,
                      label: LangKeys.adminLanguage.tr(),
                      trailing: Text(
                        state.isArabic ? 'عربي' : 'English',
                        style: AppTextStyles.caption.copyWith(
                          color: context.color.mutedForeground,
                        ),
                      ),
                      onTap: () {
                        context.read<SettingsCubit>().toggleArabic();
                        context.setLocale(
                          state.isArabic
                              ? const Locale('en')
                              : const Locale('ar'),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              const AdminSettingsLinks(),
              const SizedBox(height: AppDimens.spaceXl),
              GestureDetector(
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
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: context.color.destructive,
                    borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.logout,
                        size: AppDimens.iconLg,
                        color: context.color.primaryForeground,
                      ),
                      const SizedBox(width: AppDimens.spaceSm),
                      Text(
                        LangKeys.signOut.tr(),
                        style: AppTextStyles.controlSemiBold.copyWith(
                          color: context.color.primaryForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceLg,
          vertical: 14,
        ),
        child: Row(
          children: [
            Icon(icon, size: AppDimens.iconLg, color: context.color.primary),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(child: Text(label, style: AppTextStyles.control)),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
