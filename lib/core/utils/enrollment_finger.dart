/// The finger slots a ZKTeco terminal keeps per person.
///
/// The protocol stores up to ten templates per user, indexed 0..9. The order is
/// fixed by the firmware and is what the enrolment command's finger byte means.
class EnrollmentFinger {
  EnrollmentFinger._();

  static const int count = 10;

  static const int rightThumb = 0;
  static const int rightIndex = 1;
  static const int rightMiddle = 2;
  static const int rightRing = 3;
  static const int rightLittle = 4;
  static const int leftThumb = 5;
  static const int leftIndex = 6;
  static const int leftMiddle = 7;
  static const int leftRing = 8;
  static const int leftLittle = 9;
}
