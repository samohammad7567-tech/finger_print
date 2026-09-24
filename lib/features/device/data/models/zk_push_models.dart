import 'device_settings_model.dart';

/// One employee the app wants the terminal to know about.
class ZkPushTarget {
  /// The local employee row, so a newly allocated device id can be written
  /// back onto the right person afterwards.
  final String employeeId;

  final String fullName;

  /// What the terminal already files their punches under, when they have been
  /// enrolled or mapped before. Null means one has to be allocated.
  final String? deviceUserId;

  const ZkPushTarget({
    required this.employeeId,
    required this.fullName,
    this.deviceUserId,
  });
}

/// One resolved write: which slot on the terminal, under which id.
class ZkPushEntry {
  final ZkPushTarget target;

  /// The enrolment slot. Fingerprint templates hang off this, so an existing
  /// person's uid is reused rather than reallocated — reusing it is exactly
  /// what keeps their finger working after the write.
  final int uid;

  final String deviceUserId;

  /// The terminal does not hold this person yet.
  final bool isNew;

  /// The employee had no device id until now, so a successful write has to be
  /// saved back onto their record or the next push allocates another one.
  final bool assignsId;

  /// The name does not fit the terminal's 24-byte field and will show
  /// shortened on its screen.
  final bool nameTruncated;

  const ZkPushEntry({
    required this.target,
    required this.uid,
    required this.deviceUserId,
    required this.isNew,
    required this.assignsId,
    required this.nameTruncated,
  });
}

/// What a push would do, worked out against a fresh read of the terminal and
/// shown to the admin before anything is written.
class ZkPushPlan {
  final List<ZkPushEntry> entries;

  /// People the terminal holds that no employee here claims. Reported, never
  /// touched: the app cannot tell a stale enrolment from somebody whose record
  /// simply has not been created yet, and deleting takes their fingerprint
  /// with it.
  final List<ZkDeviceUserModel> extras;

  /// How many more people the terminal says it has room for, or null when it
  /// did not answer. Only a guard against a push that cannot finish.
  final int? freeSlots;

  /// How many people the terminal listed when the plan was made.
  final int onDevice;

  const ZkPushPlan({
    this.entries = const [],
    this.extras = const [],
    this.freeSlots,
    this.onDevice = 0,
  });

  Iterable<ZkPushEntry> get creations => entries.where((e) => e.isNew);
  Iterable<ZkPushEntry> get updates => entries.where((e) => !e.isNew);
  Iterable<ZkPushEntry> get truncated => entries.where((e) => e.nameTruncated);

  int get createCount => creations.length;
  int get updateCount => updates.length;

  bool get isEmpty => entries.isEmpty;

  /// The push would run the terminal out of enrolment slots partway through.
  bool get exceedsCapacity {
    final free = freeSlots;
    return free != null && createCount > free;
  }
}

/// What a push actually did.
class ZkPushReport {
  final List<ZkPushEntry> written;

  /// Rows the terminal refused, each with the key explaining why.
  final List<({ZkPushEntry entry, String errorKey})> failed;

  /// The run gave up early because the terminal stopped accepting writes.
  /// The remaining entries are in [failed], untried.
  final bool abortedEarly;

  const ZkPushReport({
    this.written = const [],
    this.failed = const [],
    this.abortedEarly = false,
  });

  int get writtenCount => written.length;
  int get failedCount => failed.length;
  bool get hasFailures => failed.isNotEmpty;
}
