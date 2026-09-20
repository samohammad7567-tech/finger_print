import '../../../attendance/data/models/attendance_record_model.dart';

/// One day read off the terminal: what each scan turned out to mean.
class ResolvedPunchDay {
  final String? checkIn;
  final String? checkOut;

  /// Every break of the day, in order. A break with no return recorded stays
  /// in the list with an open end rather than being dropped.
  final List<AttendanceBreak> breaks;

  final String? overtimeIn;
  final String? overtimeOut;

  const ResolvedPunchDay({
    this.checkIn,
    this.checkOut,
    this.breaks = const [],
    this.overtimeIn,
    this.overtimeOut,
  });

  /// The first departure of the day, for the summary column that predates
  /// there being a list.
  String? get firstBreakOut => breaks.isEmpty ? null : breaks.first.out;

  /// The last return, which is not necessarily the last break's — somebody can
  /// leave for the last time and never come back.
  String? get lastBreakIn {
    for (final b in breaks.reversed) {
      if (b.isClosed) return b.backIn;
    }
    return null;
  }
}

/// Decides what every scan of one person's day means, from its time and its
/// place in the day's sequence.
///
/// Nobody presses a mode key on the terminal any more — the operator would have
/// to remember which of the six modes applied, and the whole existing backlog
/// on this device carries no mode at all. So the punch mode the device reports
/// is ignored and the day is read the way a person would read it: scans
/// alternate between arriving and leaving, every departure they come back from
/// is a break of its own, and anything after the scheduled end of the day is
/// overtime.
class PunchTypeResolver {
  const PunchTypeResolver._();

  /// Reads [times] — already debounced and in any order — as one person's day.
  /// [dayEndMinutes] is when this employee's day is scheduled to end, which is
  /// what separates a break from a departure and a departure from overtime.
  static ResolvedPunchDay resolve(
    List<DateTime> times, {
    required int dayEndMinutes,
  }) {
    if (times.isEmpty) return const ResolvedPunchDay();

    final sorted = [...times]..sort();

    // A single scan is normally somebody who arrived and has not left yet. Late
    // in the day it is the opposite: they were already here and only recorded
    // leaving.
    if (sorted.length == 1) {
      final only = hhmm(sorted.first);
      return _minutesOf(sorted.first) >= dayEndMinutes
          ? ResolvedPunchDay(checkOut: only)
          : ResolvedPunchDay(checkIn: only);
    }

    String? checkIn;
    String? checkOut;
    String? overtimeIn;
    String? overtimeOut;
    final breaks = <AttendanceBreak>[];

    // Whether the person is on site, and whether they have already finished the
    // working day — the two facts that turn the next scan into a break or into
    // overtime.
    var onSite = false;
    var dayFinished = false;

    for (var i = 0; i < sorted.length; i++) {
      final at = sorted[i];
      final isLast = i == sorted.length - 1;

      // Somebody who scanned out for a break and forgot to scan back in leaves
      // an odd number of punches, which would make their last scan of the day
      // look like an arrival. The final scan of the day, at or after the
      // scheduled end, is always a departure — that is the one people do not
      // skip.
      final closesTheDay = isLast && _minutesOf(at) >= dayEndMinutes;

      if (!onSite && !closesTheDay) {
        if (dayFinished) {
          // Back after finishing — the earliest return is when overtime began.
          overtimeIn ??= hhmm(at);
        } else if (checkIn == null) {
          checkIn = hhmm(at);
        } else if (breaks.isNotEmpty && !breaks.last.isClosed) {
          // Back from the break that is still open. Every break keeps its own
          // pair, so a second and a third one are not folded into the first.
          breaks[breaks.length - 1] = AttendanceBreak(
            out: breaks.last.out,
            backIn: hhmm(at),
          );
        }
        onSite = true;
        continue;
      }

      // A departure. It ends the day when there is nothing after it, or when it
      // falls at or after the scheduled end — otherwise they are coming back,
      // which makes it a break.
      if (dayFinished && overtimeIn == null) {
        // Nothing recorded them coming back, so the earlier departure was not
        // the end of the day after all — this scan is. Their time past the
        // scheduled end still counts, it is just not a separate overtime shift.
        checkOut = hhmm(at);
      } else if (dayFinished) {
        overtimeOut = hhmm(at);
      } else if (isLast || _minutesOf(at) >= dayEndMinutes) {
        checkOut = hhmm(at);
        dayFinished = true;
      } else {
        breaks.add(AttendanceBreak(out: hhmm(at)));
      }
      onSite = false;
    }

    return ResolvedPunchDay(
      checkIn: checkIn,
      checkOut: checkOut,
      breaks: breaks,
      overtimeIn: overtimeIn,
      overtimeOut: overtimeOut,
    );
  }

  /// Collapses scans that fall inside [window] of the one before them. A
  /// fingerprint reader commonly registers the same finger two or three times
  /// in a couple of seconds.
  static List<DateTime> debounce(List<DateTime> times, Duration window) {
    if (times.isEmpty) return const [];
    final sorted = [...times]..sort();
    final result = <DateTime>[sorted.first];
    for (final time in sorted.skip(1)) {
      if (time.difference(result.last) > window) result.add(time);
    }
    return result;
  }

  static String hhmm(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  static int _minutesOf(DateTime time) => time.hour * 60 + time.minute;
}
