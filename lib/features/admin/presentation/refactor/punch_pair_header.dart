import 'package:easy_localization/easy_localization.dart';

import '../../../../core/localization/lang_keys.dart';

/// The heading for the [index]th scan pair, numbered from one.
///
/// The first two pairs are named, because "first check-in" is how an admin
/// talks about a day. From the third on the number carries the meaning, and a
/// heading that kept inventing ordinals would stop being readable.
String punchPairHeader(int index, {required bool checkIn}) {
  if (index == 1) {
    return (checkIn
            ? LangKeys.reportFirstCheckIn
            : LangKeys.reportFirstCheckOut)
        .tr();
  }
  if (index == 2) {
    return (checkIn
            ? LangKeys.reportSecondCheckIn
            : LangKeys.reportSecondCheckOut)
        .tr();
  }
  return (checkIn
          ? LangKeys.reportCheckInNumbered
          : LangKeys.reportCheckOutNumbered)
      .tr(args: ['$index']);
}
