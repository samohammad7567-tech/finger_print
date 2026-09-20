import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/localization/lang_keys.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../attendance/data/models/employee_model.dart';
import '../../../../core/style/theme/context_extension.dart';

class CheckInForm extends StatelessWidget {
  const CheckInForm({
    super.key,
    required this.employee,
    required this.time,
    required this.notes,
    required this.mode,
    required this.isLoading,
    required this.isSuccess,
    required this.onTimeChanged,
    required this.onNotesChanged,
    required this.onSubmit,
  });

  final EmployeeModel employee;
  final String time;
  final String notes;
  final String mode;
  final bool isLoading;
  final bool isSuccess;
  final ValueChanged<String> onTimeChanged;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback onSubmit;

  Color _fill(BuildContext context) => switch (mode) {
    'checkin' => context.color.success,
    'checkout' => context.color.primary,
    'absent' => context.color.destructive,
    _ => context.color.warning,
  };

  String get _buttonLabel => switch (mode) {
    'checkin' => LangKeys.checkIn.tr(),
    'checkout' => LangKeys.checkOut.tr(),
    'absent' => LangKeys.markAbsent.tr(),
    _ => LangKeys.permission.tr(),
  };

  IconData get _buttonIcon => switch (mode) {
    'checkin' => Icons.login,
    'checkout' => Icons.logout,
    'absent' => Icons.person_off,
    _ => Icons.description,
  };

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          _buildEmployeeInfo(context),
          const SizedBox(height: 16),
          _buildTimeField(context),
          const SizedBox(height: 12),
          _buildNotesField(context),
          const SizedBox(height: 16),
          AppPrimaryButton(
            onPressed: isLoading || isSuccess
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onSubmit();
                  },
            label: isLoading
                ? LangKeys.saving.tr()
                : isSuccess
                ? LangKeys.saved.tr()
                : _buttonLabel,
            icon: isSuccess ? Icons.check_circle : _buttonIcon,
            isLoading: isLoading,
            color: _fill(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeInfo(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: context.color.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              employee.fullName.isNotEmpty
                  ? employee.fullName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: context.color.primaryForeground,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee.fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              if (employee.department.trim().isNotEmpty)
                Text(
                  employee.department,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (employee.hasHousing)
                    Text(
                      LangKeys.housing.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.color.success,
                      ),
                    ),
                  if (employee.hasHousing && employee.hasTravelPermission)
                    const SizedBox(width: 8),
                  if (employee.hasTravelPermission)
                    Text(
                      LangKeys.travelPerm.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.color.success,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LangKeys.time.tr(),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 4),
        AppTextField(
          hint: time,
          prefixIcon: Icons.access_time,
          readOnly: true,
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(
                hour: int.tryParse(time.split(':').first) ?? 0,
                minute: int.tryParse(time.split(':').last) ?? 0,
              ),
            );
            if (picked != null) {
              final h = picked.hour.toString().padLeft(2, '0');
              final m = picked.minute.toString().padLeft(2, '0');
              onTimeChanged('$h:$m');
            }
          },
        ),
      ],
    );
  }

  Widget _buildNotesField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LangKeys.notesOptional.tr(),
          style: TextStyle(
            fontSize: 12,
            color: context.color.primary.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 4),
        AppTextField(
          hint: LangKeys.addNote.tr(),
          maxLines: 2,
          onChanged: onNotesChanged,
        ),
      ],
    );
  }
}
