import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/utils/app_regex.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import '../../../../core/style/theme/context_extension.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPass = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().signIn(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );
  }

  void _forgotPassword() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LangKeys.enterEmailForReset.tr()),
          backgroundColor: context.color.warning,
        ),
      );
      return;
    }
    context.read<AuthCubit>().sendPasswordReset(email);
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return LangKeys.fillAllFields.tr();
    }
    if (!AppRegex.isEmail(value)) {
      return LangKeys.errorInvalidEmail.tr();
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return LangKeys.fillAllFields.tr();
    }
    if (value.length < 6) {
      return LangKeys.errorWeakPassword.tr();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final disabled = state.isLoading;
        return AbsorbPointer(
          absorbing: disabled,
          child: Opacity(
            opacity: disabled ? 0.6 : 1.0,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildField(
                    controller: _emailCtrl,
                    hint: LangKeys.email.tr(),
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _passwordCtrl,
                    hint: LangKeys.password.tr(),
                    icon: Icons.lock_outline,
                    obscure: !_showPass,
                    validator: _validatePassword,
                    suffix: IconButton(
                      icon: Icon(
                        _showPass ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                        color: context.color.primaryForeground.withValues(
                          alpha: 0.54,
                        ),
                      ),
                      onPressed: () => setState(() => _showPass = !_showPass),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: GestureDetector(
                      onTap: _forgotPassword,
                      child: Text(
                        LangKeys.forgotPassword.tr(),
                        style: TextStyle(
                          color: context.color.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSubmit(disabled),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: context.color.primaryForeground, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: context.color.primaryForeground.withValues(alpha: 0.4),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          size: 18,
          color: context.color.primaryForeground.withValues(alpha: 0.54),
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: context.color.borderSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.color.borderSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.color.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.color.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.color.destructive),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.color.destructive, width: 2),
        ),
        errorStyle: TextStyle(color: context.color.destructive, fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildSubmit(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          color: context.color.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: MaterialButton(
          onPressed: isLoading ? null : _submit,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.color.primaryForeground,
                  ),
                )
              : Text(
                  LangKeys.signIn.tr(),
                  style: TextStyle(
                    color: context.color.primaryForeground,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    );
  }
}
