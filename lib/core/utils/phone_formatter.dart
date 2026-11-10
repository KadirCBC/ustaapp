import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class PhoneFormatter {
  // Türk GSM formatı: 5XX XXX XX XX
  static MaskTextInputFormatter get trPhoneMask {
    return MaskTextInputFormatter(
      mask: '### ### ## ##',
      filter: {"#": RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy,
    );
  }

  /// Kullanıcının girdiği maskeli veya maskesiz telefon numarasını E.164 formatına çevirir
  /// Örnek: "532 123 45 67" -> "+905321234567"
  static String toE164(String rawInput, {String countryCode = '+90'}) {
    // Sadece rakamları al
    String digits = rawInput.replaceAll(RegExp(r'\D'), '');

    // Başında 0 varsa kaldır (örn: 0532 -> 532)
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    // Başında 90 varsa kaldır (örn: 90532 -> 532)
    if (digits.startsWith('90') && digits.length > 10) {
      digits = digits.substring(2);
    }

    return '$countryCode$digits';
  }

  /// Telefon numarasının geçerli bir Türk GSM numarası olup olmadığını kontrol eder
  static bool isValidTrPhone(String rawInput) {
    String digits = rawInput.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.startsWith('90') && digits.length > 10) digits = digits.substring(2);

    // Türkiye cep numaraları 5 ile başlar ve toplam 10 hanedir
    return digits.length == 10 && digits.startsWith('5');
  }
}
