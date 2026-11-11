class AppConstants {
  static const String appName = 'UstaGeldi';
  static const String defaultCountryCode = '+90';
  static const int phoneLengthWithoutCountryCode = 10; // 5XX XXX XX XX -> 10 hane
  static const int otpLength = 6;
  static const int otpResendSeconds = 60;

  static const String mapboxAccessToken =
      'pk.eyJ1IjoiYnlncmFmMDEiLCJhIjoiY213Y2o2dnpmMDM3OTJ5c2M4cjV3NThsZyJ9.3asuElOYlUMITRxJLGh2Hw';

  // Supabase Tablo İsimleri
  static const String profilesTable = 'profiles';
  static const String ustalarTable = 'ustalar';
  static const String cagrilarTable = 'cagrilar';
  static const String degerlendirmelerTable = 'degerlendirmeler';
  static const String sistemAyarlariTable = 'sistem_ayarlari';
}
