import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/style/theme/context_extension.dart';

class ModeSelector extends StatelessWidget {
  const ModeSelector({
    super.key,
    required this.currentMode,
    required this.onChanged,
  });

  final String currentMode;
  final ValueChanged<String> onChanged;

  /// The three modes and the semantic colour each one claims when selected.
  /// Built per call rather than held as a constant, because the colours now
  /// come from the active theme.
  List<(String, IconData, String, Color)> _modes(BuildContext context) => [
    ('checkin', Icons.login, 'check_in', context.color.success),
    ('checkout', Icons.logout, 'check_out', context.color.primary),
    ('absent', Icons.person_off, 'mark_absent', context.color.destructive),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _modes(context).map((m) {
        final active = currentMode == m.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(m.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: active ? m.$4 : context.color.muted,
                borderRadius: BorderRadius.circular(16),
                border: active
                    ? null
                    : Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.08),
                      ),
              ),
              child: Column(
                children: [
                  Icon(
                    m.$2,
                    size: 20,
                    color: active
                        ? context.color.primaryForeground
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m.$3.tr(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? context.color.primaryForeground
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
