import 'package:flutter_test/flutter_test.dart';

import 'package:attendence/core/utils/name_matching.dart';

/// The two sides being compared are a name an admin typed into the form and a
/// name that came off the terminal keypad through the Windows-1256 decoder.
/// Every case here is a way those two disagree about the same person — or a way
/// they agree about two different ones.
void main() {
  group('key', () {
    test('folds every written form of alef together', () {
      const spellings = ['أبو خالد', 'إبو خالد', 'آبو خالد', 'ابو خالد'];
      expect(spellings.map(NameMatching.key).toSet(), hasLength(1));
    });

    test('drops tashkeel and the tatweel used to stretch a word', () {
      expect(NameMatching.key('مُحَمَّد'), NameMatching.key('محمد'));
      expect(NameMatching.key('محـــمد'), NameMatching.key('محمد'));
    });

    test('folds ta marbuta, alef maqsura and the hamza carriers', () {
      expect(NameMatching.key('فاطمة'), NameMatching.key('فاطمه'));
      expect(NameMatching.key('مصطفى'), NameMatching.key('مصطفي'));
      expect(NameMatching.key('مؤمن'), NameMatching.key('مومن'));
    });

    test(
      'collapses stray spacing and punctuation the keypad leaves behind',
      () {
        expect(NameMatching.key('  ابو   خالد '), 'ابو خالد');
        expect(NameMatching.key('ابو-خالد'), 'ابو خالد');
      },
    );

    test('is case blind for Latin names', () {
      expect(NameMatching.key('John Smith'), NameMatching.key('JOHN  smith'));
    });

    test('reads Arabic-Indic digits as the numbers they are', () {
      expect(NameMatching.key('عامل ٧'), 'عامل 7');
    });
  });

  group('compare', () {
    test('calls the same name, differently spelt, exact', () {
      expect(
        NameMatching.compare('أبو خالد', 'ابو  خالد'),
        NameMatchConfidence.exact,
      );
    });

    test('calls a name contained in a longer one partial', () {
      expect(
        NameMatching.compare('محمد علي', 'محمد علي الحربي'),
        NameMatchConfidence.partial,
      );
      expect(
        NameMatching.compare('محمد علي الحربي', 'محمد علي'),
        NameMatchConfidence.partial,
      );
    });

    test('refuses a single shared word', () {
      // Half the staff share a first name; treating that as evidence would
      // hold up every new hire behind a review.
      expect(NameMatching.compare('محمد الحربي', 'محمد السالم'), isNull);
      expect(NameMatching.compare('محمد', 'محمد الحربي'), isNull);
    });

    test('refuses two names that merely overlap', () {
      expect(
        NameMatching.compare('محمد علي الحربي', 'محمد سالم الحربي'),
        isNull,
      );
    });

    test('an empty name matches nobody', () {
      expect(NameMatching.compare('', 'ابو خالد'), isNull);
      expect(NameMatching.compare('   ', 'ابو خالد'), isNull);
    });
  });
}
