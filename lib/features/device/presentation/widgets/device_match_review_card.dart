import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/lang_keys.dart';
import '../../../../core/utils/name_matching.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/models/pending_employee_match.dart';
import '../cubit/device_cubit.dart';
import '../cubit/device_state.dart';
import '../../../../core/style/theme/context_extension.dart';

/// Terminal users the sync would not import on its own, because somebody
/// already on file answers to the same name.
///
/// The whole card is a question, never a report: the admin says whether the two
/// are one person. Until they do, nothing has been written — no employee
/// created, no id linked — and the punches wait in the log.
class DeviceMatchReviewCard extends StatelessWidget {
  const DeviceMatchReviewCard({super.key, required this.state});

  final DeviceState state;

  @override
  Widget build(BuildContext context) {
    if (!state.hasPendingMatches) return const SizedBox.shrink();
    final cubit = context.read<DeviceCubit>();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.help_outline,
                size: 18,
                color: context.color.warningSoft,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  LangKeys.deviceMatchReview.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.color.warningSoft.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${state.pendingMatches.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.color.warningSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            LangKeys.deviceMatchReviewHint.tr(),
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          ...state.pendingMatches.map(
            (match) => _MatchTile(
              match: match,
              isResolving: state.resolvingMatchFor == match.deviceUserId,
              isLocked: state.resolvingMatchFor != null,
              onLink: (employeeId) => cubit.confirmPendingMatch(
                deviceUserId: match.deviceUserId,
                employeeId: employeeId,
              ),
              onCreate: () => cubit.rejectPendingMatch(match.deviceUserId),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({
    required this.match,
    required this.isResolving,
    required this.isLocked,
    required this.onLink,
    required this.onCreate,
  });

  final PendingEmployeeMatch match;
  final bool isResolving;
  final bool isLocked;
  final void Function(String employeeId) onLink;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final faded = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.color.warningSoft.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${match.deviceUserId}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.color.warningSoft,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  match.deviceName.isEmpty
                      ? LangKeys.deviceMatchNoName.tr()
                      : match.deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isResolving)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            LangKeys.deviceMatchOnDevice.tr(),
            style: TextStyle(fontSize: 10, color: faded),
          ),
          const SizedBox(height: 10),
          Text(
            match.candidates.length == 1
                ? LangKeys.deviceMatchSamePersonQuestion.tr()
                : LangKeys.deviceMatchWhichPerson.tr(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          ...match.candidates.map(
            (candidate) => _candidateRow(context, candidate, faded),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: isLocked ? null : onCreate,
              icon: const Icon(Icons.person_add_alt, size: 15),
              style: TextButton.styleFrom(foregroundColor: faded),
              label: Text(
                LangKeys.deviceMatchNotTheSame.tr(),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _candidateRow(
    BuildContext context,
    EmployeeMatchCandidate candidate,
    Color faded,
  ) {
    final isExact = candidate.confidence == NameMatchConfidence.exact;
    final details = [
      if ((candidate.employeeNumber ?? '').isNotEmpty)
        candidate.employeeNumber!,
      if (candidate.department.isNotEmpty) candidate.department,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        candidate.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // A partial match is the keypad running out of room for a
                    // family name — worth showing, but the admin should look
                    // twice before taking it.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isExact
                                    ? context.color.success
                                    : context.color.warning)
                                .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isExact
                            ? LangKeys.deviceMatchExact.tr()
                            : LangKeys.deviceMatchPartial.tr(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isExact
                              ? context.color.success
                              : context.color.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: faded),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: isLocked ? null : () => onLink(candidate.employeeId),
            child: Text(
              LangKeys.deviceMatchLink.tr(),
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
