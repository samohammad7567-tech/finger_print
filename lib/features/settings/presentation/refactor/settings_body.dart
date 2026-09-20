import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';
import '../widgets/settings_tile.dart';
import '../widgets/guard_profile_card.dart';
import '../widgets/settings_section.dart';
import '../widgets/logout_button.dart';

class SettingsBody extends StatelessWidget {
  const SettingsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final authState = getIt<AuthCubit>().state;
        final guardName = authState.displayName.isNotEmpty
            ? authState.displayName
            : LangKeys.guard.tr();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LangKeys.settings.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              GuardProfileCard(name: guardName),
              const SizedBox(height: 24),
              SettingsSection(
                title: LangKeys.appearance.tr(),
                items: [
                  SettingsTile(
                    icon: state.isDark ? Icons.dark_mode : Icons.light_mode,
                    label: LangKeys.darkMode.tr(),
                    toggle: state.isDark,
                    onTap: () => context.read<SettingsCubit>().toggleDark(),
                  ),
                  SettingsTile(
                    icon: Icons.language,
                    label: LangKeys.arabicRtl.tr(),
                    toggle: state.isArabic,
                    onTap: () {
                      context.read<SettingsCubit>().toggleArabic();
                      final newLocale = state.isArabic
                          ? const Locale('en')
                          : const Locale('ar');
                      context.setLocale(newLocale);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SettingsSection(
                title: LangKeys.notificationsSettings.tr(),
                items: [
                  SettingsTile(
                    icon: Icons.notifications,
                    label: LangKeys.lateArrivalAlerts.tr(),
                    toggle: state.lateAlerts,
                    onTap: () =>
                        context.read<SettingsCubit>().toggleLateAlerts(),
                  ),
                  SettingsTile(
                    icon: Icons.notifications,
                    label: LangKeys.missingCheckoutAlerts.tr(),
                    toggle: state.missingCheckoutAlerts,
                    onTap: () => context
                        .read<SettingsCubit>()
                        .toggleMissingCheckoutAlerts(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SettingsSection(
                title: LangKeys.account.tr(),
                items: [
                  SettingsTile(
                    icon: Icons.person,
                    label: guardName,
                    subtitle: LangKeys.securityGuard.tr(),
                    hasArrow: true,
                    onTap: () {},
                  ),
                  SettingsTile(
                    icon: Icons.shield,
                    label: LangKeys.aboutApp.tr(),
                    subtitle: 'SecureAttend v1.0',
                    hasArrow: true,
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const LogoutButton(),
            ],
          ),
        );
      },
    );
  }
}
