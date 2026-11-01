/// One in/out pair read from the order of the day's scans.
///
/// Either side may be missing: a person who only checked in has no check-out
/// yet, and an odd number of scans leaves the last one standing on its own.
class PunchPair {
  final String? checkIn;
  final String? checkOut;

  const PunchPair({this.checkIn, this.checkOut});
}

class PunchPairs {
  const PunchPairs._();

  /// Pairs [scans] from the start of the day, two at a time.
  ///
  /// The last scan of an odd day is always a check-out, with no check-in to
  /// pair it with. A person who stepped out for a break and forgot to scan back
  /// leaves an odd number of scans, and the scan they never skip is the one
  /// that ends the day.
  static List<PunchPair> fromOrdered(List<String> scans) {
    if (scans.isEmpty) return const [];

    final pairs = <PunchPair>[];
    final complete = scans.length.isOdd ? scans.length - 1 : scans.length;

    for (var i = 0; i < complete; i += 2) {
      pairs.add(PunchPair(checkIn: scans[i], checkOut: scans[i + 1]));
    }

    if (scans.length.isOdd) {
      pairs.add(PunchPair(checkOut: scans.last));
    }

    return pairs;
  }
}
