import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/models/data_maintenance_models.dart';
import '../../../../core/style/theme/context_extension.dart';

/// What the database is holding, in figures.
///
/// Sits directly above the two delete buttons because it is the only thing
/// that makes them judgeable: "clear old records" with no numbers beside it is
/// a button nobody can weigh, and the punch count is usually the surprise —
/// it dwarfs everything else in the file.
class BackupFootprintCard extends StatelessWidget {
  const BackupFootprintCard({super.key, required this.footprint});

  final DataFootprint footprint;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LangKeys.dataOnFile.tr(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          _row(
            context,
            LangKeys.dataEmployeesCount.tr(),
            '${footprint.employees}',
          ),
          _row(
            context,
            LangKeys.dataAttendanceDays.tr(),
            '${footprint.attendanceDays}',
          ),
          _row(context, LangKeys.dataPunches.tr(), '${footprint.punches}'),
          _row(
            context,
            LangKeys.dataSize.tr(),
            '${footprint.databaseSizeMb} MB',
          ),
          if (footprint.oldestAttendanceDate != null)
            _row(
              context,
              LangKeys.dataOldest.tr(),
              footprint.oldestAttendanceDate!,
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: context.color.mutedForeground,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
