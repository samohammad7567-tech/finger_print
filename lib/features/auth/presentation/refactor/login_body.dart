import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_toast.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import '../widgets/login_form.dart';
import '../../../../core/style/theme/context_extension.dart';

class LoginBody extends StatelessWidget {
  const LoginBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.isLoggedIn) {
          context.go(state.isAdmin ? '/admin' : '/');
        }
        if (state.passwordResetSent) {
          AppToast.success(context, LangKeys.passwordResetSent.tr());
        }
        if (state.error != null) {
          AppToast.error(context, state.error!.tr());
        }
      },
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          return Stack(
            children: [
              _buildContent(context),
              if (state.isLoading) _buildLoadingOverlay(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: context.color.background),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(context),
                  const SizedBox(height: 40),
                  _buildCard(context),
                  const SizedBox(height: 24),
                  Text(
                    LangKeys.contactAdmin.tr(),
                    style: TextStyle(
                      color: context.color.primaryForeground.withValues(
                        alpha: 0.5,
                      ),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(BuildContext context) {
    return Container(
      color: context.effects.scrim,
      child: Center(
        child: CircularProgressIndicator(
          color: context.color.primaryForeground,
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: context.color.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.shield,
            size: 40,
            color: context.color.primaryForeground,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          LangKeys.appName.tr(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: context.color.primaryForeground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          LangKeys.attendanceSystem.tr(),
          style: TextStyle(
            color: context.color.primaryForeground.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.color.borderSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.color.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LangKeys.signIn.tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.color.primaryForeground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            LangKeys.enterGuardCredentials.tr(),
            style: TextStyle(
              color: context.color.primaryForeground.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          const LoginForm(),
        ],
      ),
    );
  }
}
