import 'package:flutter/material.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_icon_badge.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.toggle,
    this.hasArrow = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool? toggle;
  final bool hasArrow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            AppIconBadge.tinted(
              icon: icon,
              color: context.color.primary,
              size: 32,
              radius: 10,
              tintAlpha: 0.1,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
            if (toggle != null) _buildToggle(context, toggle!),
            if (hasArrow)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(BuildContext context, bool value) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 40,
      height: 24,
      decoration: BoxDecoration(
        color: value ? context.color.primary : context.color.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: context.color.primaryForeground,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
