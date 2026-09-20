import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../cubit/admin_password_cubit.dart';
import '../refactor/admin_password_body.dart';

/// Asks whoever is at the keyboard to prove they are still the account that
/// signed in, before something that cannot be undone goes through.
///
/// Returns true only on a confirmed password. Backing out, closing it, and
/// every kind of failure all return false — the caller can treat anything but
/// true as "do not proceed", which is the only safe way for a gate like this
/// to be read.
///
/// [reason] is the localization key for the line explaining what is being
/// authorised, so the dialog can front more than one action without pretending
/// they are the same one.
Future<bool> showAdminPasswordDialog(
  BuildContext context, {
  required String reason,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    // Dismissing by tapping outside is a "no", and that is fine — but it must
    // be a deliberate one, not something a stray tap does while the password
    // is half typed.
    barrierDismissible: false,
    builder: (_) => BlocProvider(
      create: (_) => getIt<AdminPasswordCubit>(),
      child: _AdminPasswordDialog(reason: reason),
    ),
  );
  return confirmed ?? false;
}

class _AdminPasswordDialog extends StatefulWidget {
  const _AdminPasswordDialog({required this.reason});
  final String reason;

  @override
  State<_AdminPasswordDialog> createState() => _AdminPasswordDialogState();
}

class _AdminPasswordDialogState extends State<_AdminPasswordDialog> {
  final _passwordCtrl = TextEditingController();
  bool _obscured = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_passwordCtrl.text.isEmpty) return;

    final navigator = Navigator.of(context);
    final ok = await context.read<AdminPasswordCubit>().verify(
      _passwordCtrl.text,
    );

    // A wrong password leaves the dialog open with the cubit's message under
    // the field, so the admin can try again rather than reopen it.
    if (ok && navigator.mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminPasswordCubit, AdminPasswordState>(
      builder: (context, state) {
        final canSubmit = !state.isChecking && _passwordCtrl.text.isNotEmpty;

        return Dialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AdminPasswordBody(
              reason: widget.reason,
              controller: _passwordCtrl,
              obscured: _obscured,
              isChecking: state.isChecking,
              errorKey: state.errorKey,
              onObscuredToggled: () => setState(() => _obscured = !_obscured),
              onChanged: (_) => setState(() {}),
              onSubmitted: () {
                if (!state.isChecking) _submit();
              },
              onCancel: () => Navigator.pop(context, false),
              onConfirm: canSubmit ? _submit : null,
            ),
          ),
        );
      },
    );
  }
}
