import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/style/theme/context_extension.dart';
import '../../../../core/widgets/app_icon_badge.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _Action(
        Icons.login,
        LangKeys.checkIn.tr(),
        context.color.success,
        '/checkin?mode=checkin',
      ),
      _Action(
        Icons.logout,
        LangKeys.checkOut.tr(),
        context.color.primary,
        '/checkin?mode=checkout',
      ),
      _Action(
        Icons.person_off,
        LangKeys.markAbsent.tr(),
        context.color.destructive,
        '/checkin?mode=absent',
      ),
    ];

    return Row(
      children: actions
          .map(
            (a) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onTap: () => context.push(a.path),
                  child: Column(
                    children: [
                      AppIconBadge(
                        icon: a.icon,
                        color: a.color,
                        size: 40,
                        radius: 12,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        a.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Action {
  final IconData icon;
  final String label;
  final Color color;
  final String path;
  const _Action(this.icon, this.label, this.color, this.path);
}
