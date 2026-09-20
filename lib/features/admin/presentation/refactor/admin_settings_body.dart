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

class AdminSettingsBody extends StatelessWidget {
  const AdminSettingsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final authState = getIt<AuthCubit>().state;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LangKeys.settings.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: context.color.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.shield,
                        size: 24,
                        color: context.color.primaryForeground,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.displayName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.color.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            LangKeys.adminSystemManager.tr(),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.color.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      onTap: () => context.read<SettingsCubit>().toggleDark(),
                    ),
                    Divider(
                      height: 1,
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.3),
                    ),
                    _tile(
                      context,
                      icon: Icons.language,
                      label: LangKeys.adminLanguage.tr(),
                      trailing: Text(
                        state.isArabic ? 'عربي' : 'English',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
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
              const SizedBox(height: 16),
              const AdminSettingsLinks(),
              const SizedBox(height: 24),
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.logout,
                        size: 18,
                        color: context.color.primaryForeground,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        LangKeys.signOut.tr(),
                        style: TextStyle(
                          color: context.color.primaryForeground,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.color.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
