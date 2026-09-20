import '../../../../core/utils/name_matching.dart';

/// An employee already on file who could be the person the terminal is
/// reporting.
typedef EmployeeMatchCandidate = ({
  String employeeId,
  String fullName,
  String? employeeNumber,
  String department,
  NameMatchConfidence confidence,
});

/// A terminal user the import deliberately did not create, because somebody
/// already on file answers to the same name.
///
/// Held rather than resolved: the import cannot tell a returning employee from
/// a new hire who shares a name, and getting it wrong files one person's
/// attendance under another. Their punches keep arriving and are parked in the
/// punch log meanwhile, so nothing is lost by the wait — linking replays the
/// whole history through `refoldUnmapped`.
class PendingEmployeeMatch {
  /// The id this person is enrolled under on the terminal.
  final String deviceUserId;

  /// The name as the terminal spells it, for the admin to compare against.
  final String deviceName;

  /// Everyone it could be, best match first. More than one means the admin has
  /// a real choice to make; the import never picks for them.
  final List<EmployeeMatchCandidate> candidates;

  final DateTime detectedAt;

  const PendingEmployeeMatch({
    required this.deviceUserId,
    required this.deviceName,
    required this.candidates,
    required this.detectedAt,
  });

  /// One candidate, and its name is spelt the same once normalised — the case
  /// an admin can approve at a glance.
  bool get isUnambiguous =>
      candidates.length == 1 &&
      candidates.first.confidence == NameMatchConfidence.exact;
}
