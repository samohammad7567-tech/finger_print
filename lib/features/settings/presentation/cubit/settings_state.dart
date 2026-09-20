class SettingsState {
  final bool isDark;
  final bool isArabic;
  final bool lateAlerts;
  final bool missingCheckoutAlerts;

  const SettingsState({
    this.isDark = true,
    this.isArabic = false,
    this.lateAlerts = true,
    this.missingCheckoutAlerts = true,
  });

  SettingsState copyWith({
    bool? isDark,
    bool? isArabic,
    bool? lateAlerts,
    bool? missingCheckoutAlerts,
  }) => SettingsState(
    isDark: isDark ?? this.isDark,
    isArabic: isArabic ?? this.isArabic,
    lateAlerts: lateAlerts ?? this.lateAlerts,
    missingCheckoutAlerts: missingCheckoutAlerts ?? this.missingCheckoutAlerts,
  );
}
