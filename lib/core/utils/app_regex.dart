/// Shared input patterns, so a rule is written once and every form agrees.
class AppRegex {
  AppRegex._();

  /// Email addresses.
  ///
  /// The top-level domain is deliberately unbounded at the top end. An earlier
  /// version capped it at four characters, which quietly rejected every
  /// `.local` address — including the app's own default admin account — as well
  /// as ordinary public domains such as `.online` and `.technology`.
  ///
  /// The local part allows `+` so plus-addressing (`name+tag@example.com`)
  /// works.
  static final RegExp email = RegExp(r'^[\w.+-]+@([\w-]+\.)+[A-Za-z]{2,}$');

  /// A time of day as the app stores it: "HH:mm", 24-hour.
  static final RegExp time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  /// A calendar day as the app stores it: "yyyy-MM-dd".
  static final RegExp date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// An IPv4 address, for the terminal's connection settings.
  static final RegExp ipv4 = RegExp(
    r'^((25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}'
    r'(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)$',
  );

  static bool isEmail(String? value) =>
      value != null && email.hasMatch(value.trim());

  static bool isIpv4(String? value) =>
      value != null && ipv4.hasMatch(value.trim());
}
