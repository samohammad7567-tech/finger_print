/// One stretch of days nobody in the company was expected to work.
///
/// A range rather than a single date: the holidays that matter come in runs,
/// and making an admin enter Eid one day at a time is how a calendar ends up
/// with gaps in it. A single-day holiday is simply a range whose ends match.
///
/// [isPaid] does not change any judgement the app makes today — a day off is a
/// day off either way. It is recorded because payroll needs it, and because
/// asking after the fact which of last year's shutdowns were paid is a
/// question nobody can answer from punches.
class HolidayModel {
  final String id;
  final String name;

  /// 'yyyy-MM-dd', inclusive at both ends.
  final String startDate;
  final String endDate;

  final bool isPaid;

  const HolidayModel({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.isPaid = true,
  });

  factory HolidayModel.fromJson(Map<String, dynamic> json) => HolidayModel(
    id: json['id'] as String? ?? '',
    name: (json['name'] as String? ?? '').trim(),
    startDate: json['start_date'] as String? ?? '',
    endDate: json['end_date'] as String? ?? '',
    // SQLite has no boolean type, so a row read back carries 1/0.
    isPaid: switch (json['is_paid']) {
      bool v => v,
      int v => v != 0,
      _ => true,
    },
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'start_date': startDate,
    'end_date': endDate,
    'is_paid': isPaid ? 1 : 0,
  };

  HolidayModel copyWith({
    String? name,
    String? startDate,
    String? endDate,
    bool? isPaid,
  }) => HolidayModel(
    id: id,
    name: name ?? this.name,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    isPaid: isPaid ?? this.isPaid,
  );

  DateTime? get start => DateTime.tryParse(startDate);
  DateTime? get end => DateTime.tryParse(endDate);

  /// True when [date] falls inside the range, both ends included.
  ///
  /// Compared as text rather than as dates: 'yyyy-MM-dd' sorts the same way it
  /// reads, and the column is stored that way, so the check here and the SQL
  /// that finds these rows can never disagree about a boundary.
  bool covers(String date) =>
      date.compareTo(startDate) >= 0 && date.compareTo(endDate) <= 0;

  /// How many days it runs for. Used to tell the admin what they are about to
  /// delete, and to catch a range typed backwards.
  int get dayCount {
    final from = start;
    final to = end;
    if (from == null || to == null) return 0;
    return to.difference(from).inDays + 1;
  }

  /// A range that can actually be a holiday.
  bool get isValid =>
      name.trim().isNotEmpty && start != null && end != null && dayCount >= 1;

  /// 'yyyy-MM-dd' for [day] — the one spelling the whole app stores dates in.
  static String isoDate(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
