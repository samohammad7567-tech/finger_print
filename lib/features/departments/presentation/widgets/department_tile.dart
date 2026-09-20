import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../data/models/department_model.dart';
import '../../../../core/style/theme/context_extension.dart';

/// One department in the list: its name, how many people are in it, and the
/// two things an admin can do to it.
class DepartmentTile extends StatelessWidget {
  const DepartmentTile({
    super.key,
    required this.department,
    required this.onRename,
    required this.onDelete,
  });

  final DepartmentModel department;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final faded = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.apartment, size: 18, color: context.color.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  department.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // An unlisted department is one nobody added — it exists only
                  // because employees are filed under it. Saying so explains
                  // why it is here and invites the admin to adopt it.
                  department.isUnlisted
                      ? '${LangKeys.departmentInUse.tr(args: ['${department.inUse}'])}'
                            ' · ${LangKeys.departmentUnlisted.tr()}'
                      : LangKeys.departmentInUse.tr(
                          args: ['${department.inUse}'],
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: faded),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: LangKeys.departmentRename.tr(),
            onPressed: onRename,
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 18,
              color: context.color.destructive,
            ),
            tooltip: LangKeys.adminDelete.tr(),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
