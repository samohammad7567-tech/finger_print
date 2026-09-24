import 'package:flutter/material.dart';

import '../../../../core/widgets/glass_card.dart';

/// A labelled file path, selectable so an admin can copy it into Explorer.
class BackupPathCard extends StatelessWidget {
  const BackupPathCard({super.key, required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(path, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
