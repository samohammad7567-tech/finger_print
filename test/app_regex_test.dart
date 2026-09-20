import 'package:flutter_test/flutter_test.dart';

import 'package:attendence/core/utils/app_regex.dart';

void main() {
  group('email', () {
    test('accepts a top-level domain longer than four characters', () {
      // The rule that used to break login: a {2,4} cap rejected every one of
      // these, including the app's own default admin account.
      expect(AppRegex.isEmail('guard@guardsync.local'), isTrue);
      expect(AppRegex.isEmail('admin@guardsync.local'), isTrue);
      expect(AppRegex.isEmail('someone@example.online'), isTrue);
      expect(AppRegex.isEmail('someone@example.technology'), isTrue);
    });

    test('accepts ordinary addresses', () {
      expect(AppRegex.isEmail('mohammadwork199700@gmail.com'), isTrue);
      expect(AppRegex.isEmail('a@b.co'), isTrue);
      expect(AppRegex.isEmail('first.last@sub.domain.org'), isTrue);
      expect(AppRegex.isEmail('name+tag@example.com'), isTrue);
      expect(AppRegex.isEmail('  padded@example.com  '), isTrue);
    });

    test('rejects malformed addresses', () {
      expect(AppRegex.isEmail(''), isFalse);
      expect(AppRegex.isEmail(null), isFalse);
      expect(AppRegex.isEmail('no-at-sign'), isFalse);
      expect(AppRegex.isEmail('missing@domain'), isFalse);
      expect(AppRegex.isEmail('@example.com'), isFalse);
      expect(AppRegex.isEmail('spaces in@example.com'), isFalse);
      // A single-letter TLD is not valid.
      expect(AppRegex.isEmail('a@b.c'), isFalse);
    });
  });

  group('ipv4', () {
    test('accepts terminal addresses', () {
      expect(AppRegex.isIpv4('192.168.1.201'), isTrue);
      expect(AppRegex.isIpv4('10.0.0.1'), isTrue);
      expect(AppRegex.isIpv4('255.255.255.255'), isTrue);
    });

    test('rejects out-of-range and malformed', () {
      expect(AppRegex.isIpv4('192.168.1.256'), isFalse);
      expect(AppRegex.isIpv4('192.168.1'), isFalse);
      expect(AppRegex.isIpv4('192.168.1.1.1'), isFalse);
      expect(AppRegex.isIpv4('not.an.ip.address'), isFalse);
    });
  });

  group('time and date', () {
    test('matches the formats the app stores', () {
      expect(AppRegex.time.hasMatch('08:05'), isTrue);
      expect(AppRegex.time.hasMatch('23:59'), isTrue);
      expect(AppRegex.time.hasMatch('24:00'), isFalse);
      expect(AppRegex.time.hasMatch('8:05'), isFalse);

      expect(AppRegex.date.hasMatch('2026-08-16'), isTrue);
      expect(AppRegex.date.hasMatch('2026-8-16'), isFalse);
    });
  });
}
