/// Compares people's names that reached the app by two very different routes.
///
/// One side an admin typed into the employee form; the other came off the
/// terminal keypad and through the Windows-1256 decoder. The same person is
/// written differently on each side — "أبو خالد" against "ابو خالد", a stray
/// tatweel, a doubled space, a middle name the keypad had no room for — so a
/// raw `==` matches almost nothing and the device import creates a second copy
/// of somebody who is already on file.
///
/// Nothing here decides anything on its own. A match is a question put to an
/// admin, never an answer: see the review step in `DeviceSyncDataSource`.
class NameMatching {
  NameMatching._();

  /// Tashkeel, the Quranic marks that ride along with it, and the tatweel used
  /// to stretch a word for justification. None of them change the word.
  static final _marks = RegExp('[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]');

  /// Alef in each of its written forms, plus the Persian/Urdu letters a keypad
  /// sometimes emits for kaf and yeh.
  static const _letterFolds = {
    '\u0622': '\u0627', // آ
    '\u0623': '\u0627', // أ
    '\u0625': '\u0627', // إ
    '\u0671': '\u0627', // ٱ
    '\u0649': '\u064A', // ى
    '\u0626': '\u064A', // ئ
    '\u06CC': '\u064A', // ی
    '\u0624': '\u0648', // ؤ
    '\u0629': '\u0647', // ة
    '\u06A9': '\u0643', // ک
  };

  /// Arabic letters, Latin letters and digits survive; everything else — dots,
  /// dashes, the zero-width joiner the keypad leaves behind — becomes a space.
  static final _notALetter = RegExp('[^\u0621-\u064Aa-zA-Z0-9 ]+');

  static final _arabicDigits = RegExp('[\u0660-\u0669\u06F0-\u06F9]');
  static final _runsOfSpace = RegExp(r'\s+');

  /// The comparable form of [name]: one spelling per letter, no marks, single
  /// spaced, lowercased. Two names are the same name when their keys match.
  static String key(String name) {
    var text = name.replaceAll(_marks, '');

    for (final entry in _letterFolds.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }

    text = text.replaceAllMapped(_arabicDigits, (match) {
      final code = match.group(0)!.codeUnitAt(0);
      final base = code >= 0x06F0 ? 0x06F0 : 0x0660;
      return '${code - base}';
    });

    return text
        .replaceAll(_notALetter, ' ')
        .replaceAll(_runsOfSpace, ' ')
        .trim()
        .toLowerCase();
  }

  /// How alike two names are, or null when they are not alike enough to be
  /// worth an admin's time.
  static NameMatchConfidence? compare(String a, String b) {
    final left = key(a);
    final right = key(b);
    if (left.isEmpty || right.isEmpty) return null;
    if (left == right) return NameMatchConfidence.exact;

    final leftWords = left.split(' ').toSet();
    final rightWords = right.split(' ').toSet();

    // One shared word is a coincidence, not a person: half the staff share a
    // first name. A shorter name fully contained in a longer one is not — that
    // is the keypad running out of room for the family name.
    if (leftWords.length < 2 || rightWords.length < 2) return null;
    if (leftWords.containsAll(rightWords) ||
        rightWords.containsAll(leftWords)) {
      return NameMatchConfidence.partial;
    }
    return null;
  }
}

/// How strongly two names agree. Both are shown to the admin; neither is ever
/// acted on without them.
enum NameMatchConfidence {
  /// The same name once both sides are normalised.
  exact,

  /// One name's words are all present in the other's — a missing middle or
  /// family name, most often.
  partial,
}
