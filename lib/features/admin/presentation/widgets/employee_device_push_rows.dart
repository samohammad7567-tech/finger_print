import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/style/theme/context_extension.dart';

/// One counted outcome. Zero still shows: "0 new" is the answer to "is this
/// going to add anybody", and hiding it leaves the question open.
class PushSummaryRow extends StatelessWidget {
  const PushSummaryRow({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    this.hint,
  });

  final IconData icon;
  final String label;
  final int count;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final hintText = hint;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: context.color.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count · ${label.tr()}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hintText != null)
                  Text(
                    hintText.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.color.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A tinted aside — reassurance or warning, same shape either way.
class PushSummaryNote extends StatelessWidget {
  const PushSummaryNote({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: color, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
