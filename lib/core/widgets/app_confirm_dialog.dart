import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../localization/lang_keys.dart';
import '../style/theme/app_dimens.dart';
import '../style/theme/app_text_styles.dart';
import '../style/theme/context_extension.dart';
import 'app_icon_badge.dart';
import 'app_note_banner.dart';

/// Asks before an action that cannot be taken back, and says what it costs.
///
/// Five features had written this dialog out by hand — delete an employee, a
/// department, a shift, a holiday, wipe the terminal — and each copy carried
/// the same badge, the same two buttons, and a different spelling of the same
/// consequence line. The shape is here; what differs between them is the
/// sentence, which is the only part worth writing twice.
///
/// Resolves to `true` only when the confirm button is pressed; dismissing it
/// any other way resolves to `false`, so a caller can treat the result as the
/// permission it is.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  IconData icon = Icons.warning_amber,
  Color? accent,
  String? warning,
  List<AppConfirmNote> notes = const <AppConfirmNote>[],
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AppConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon,
      accent: accent,
      warning: warning,
      notes: notes,
    ),
  );
  return confirmed == true;
}

/// One boxed line of consequence shown under the dialog's message — a warning
/// about what goes, or a reassurance about what stays.
class AppConfirmNote {
  const AppConfirmNote(this.text, this.color);

  final String text;
  final Color color;
}

class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel,
    this.cancelLabel,
    this.icon = Icons.warning_amber,
    this.accent,
    this.warning,
    this.notes = const <AppConfirmNote>[],
  });

  final String title;

  /// What is about to happen, named concretely — the record, the count, the
  /// date — rather than the verb alone.
  final String message;

  /// Defaults to the shared "delete" and "cancel" keys.
  final String? confirmLabel;
  final String? cancelLabel;

  final IconData icon;

  /// The badge and confirm button fill. Defaults to destructive, because that
  /// is what a confirmation almost always guards.
  final Color? accent;

  /// An unboxed consequence line, in the softer warning tint. For the cases
  /// where only the list in front of the admin hides the catch — people left
  /// without a department, a fingerprint cleared along with its owner.
  final String? warning;

  /// Boxed notes, for dialogs whose consequences need more separation than a
  /// tinted sentence gives.
  final List<AppConfirmNote> notes;

  @override
  Widget build(BuildContext context) {
    final fill = accent ?? context.color.destructive;

    // No fill, shape or barrier of its own: AppTheme's dialogTheme already
    // gives a dialog the popover surface, a hairline border, radiusXl and the
    // hand-tuned plane-4 shadow. Restating them here is what made this dialog
    // the one rounded thing in an almost-square product.
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconBadge(
              icon: icon,
              color: fill,
              size: 48,
              radius: AppDimens.radiusLg,
              iconSize: AppDimens.icon2xl,
            ),
            const SizedBox(height: AppDimens.spaceLg),
            Text(
              title,
              style: AppTextStyles.subheading.copyWith(
                color: context.color.popoverForeground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              message,
              style: AppTextStyles.body.copyWith(
                color: context.color.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
            if (warning != null) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                warning!,
                style: AppTextStyles.meta.copyWith(
                  color: context.color.warningSoft,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            for (final note in notes) ...[
              const SizedBox(height: AppDimens.spaceSm),
              AppNoteBanner(
                text: note.text,
                color: note.color,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.spaceSm,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppDimens.spaceXl),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AppDimens.controlHeightLg,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.color.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimens.radius),
                        ),
                      ),
                      child: Text(
                        cancelLabel ?? LangKeys.cancel.tr(),
                        style: AppTextStyles.controlSemiBold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: Container(
                    height: AppDimens.controlHeightLg,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(AppDimens.radius),
                    ),
                    child: MaterialButton(
                      onPressed: () => Navigator.pop(context, true),
                      elevation: 0,
                      hoverElevation: 0,
                      highlightElevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radius),
                      ),
                      child: Text(
                        confirmLabel ?? LangKeys.adminDelete.tr(),
                        style: AppTextStyles.controlSemiBold.copyWith(
                          color: context.color.primaryForeground,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
