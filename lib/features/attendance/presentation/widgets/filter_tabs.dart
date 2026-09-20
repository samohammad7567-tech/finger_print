import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/style/theme/context_extension.dart';

class FilterTabs extends StatelessWidget {
  const FilterTabs({
    super.key,
    required this.activeFilter,
    required this.onChanged,
  });

  final String activeFilter;
  final ValueChanged<String> onChanged;

  static const _filters = [
    ('all', 'all'),
    ('present', 'present'),
    ('late', 'late'),
    ('absent', 'absent'),
    ('early_leave', 'early_leave'),
    ('travel_permission', 'travel'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((f) {
          final active = activeFilter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(f.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: active ? context.color.primary : context.color.muted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  f.$2.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? context.color.primaryForeground
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
