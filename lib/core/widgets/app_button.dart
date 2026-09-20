import 'package:flutter/material.dart';
import '../style/theme/context_extension.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.color,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;

  /// Overrides the fill for buttons that carry a semantic other than the
  /// primary action — a destructive confirm, a success path. Flat: the design
  /// system's own brand gradient has two identical stops.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null;
    final Color fill = disabled
        ? context.color.muted
        : (color ?? context.color.primary);
    final Color ink = disabled
        ? context.color.subtleForeground
        : context.color.primaryForeground;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: MaterialButton(
        onPressed: isLoading ? null : onPressed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: ink),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: ink, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
