import 'package:flutter/material.dart';

import '../style/theme/app_dimens.dart';
import '../style/theme/app_text_styles.dart';
import '../style/theme/context_extension.dart';

/// Dims a screen and spins over it while a slow action finishes.
///
/// Used where the work cannot be cancelled and a half-interactive screen would
/// invite a second tap — signing in, or pushing a staff list to the terminal.
/// Stack it over the page content and gate it on the cubit's loading flag;
/// [AppLoadingOverlay.maybe] returns nothing when the flag is down, so the
/// call site stays a single line.
class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({super.key, this.message, this.spinnerColor});

  /// Named so the wait is accountable — "reading the device", not a bare
  /// spinner over a frozen screen.
  final String? message;

  final Color? spinnerColor;

  /// Renders nothing while [isLoading] is false.
  static Widget maybe(bool isLoading, {String? message, Color? spinnerColor}) =>
      isLoading
      ? AppLoadingOverlay(message: message, spinnerColor: spinnerColor)
      : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: context.effects.scrim,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: spinnerColor),
              if (message != null) ...[
                const SizedBox(height: AppDimens.spaceLg),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: context.color.primaryForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
