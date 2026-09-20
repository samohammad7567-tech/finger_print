import 'package:flutter/material.dart';
import '../../../../core/style/theme/context_extension.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.items});

  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? context.color.borderSoft
                : context.color.primaryForeground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? context.color.borderSoft
                  : context.color.borderSoft,
            ),
          ),
          child: Column(
            children: List.generate(items.length * 2 - 1, (i) {
              if (i.isOdd) {
                return Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                );
              }
              return items[i ~/ 2];
            }),
          ),
        ),
      ],
    );
  }
}
