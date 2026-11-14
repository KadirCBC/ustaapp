import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ustaapp/core/services/app_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Mobil uygulamada tamamlanan hizmetin AppDataService ve Finans Masasına anında yansıması testi', () async {
    SharedPreferences.setMockInitialValues({});
    final appData = AppDataService();

    // 1. Mobil uygulamada tamamlanan çağrı verisi
    final completedService = {
      'id': 'TRX-1794613769383',
      'receipt_no': 'demo_pay_1794613769383',
      'cagri_id': 'cagri-bolvadin-1794613769',
      'hizmet_baslik': 'Standart Servis & Arıza Tespiti',
      'kategori': 'Elektrik & Aydınlatma',
      'musteri_ad': 'Zeynep Kaya',
      'musteri_tel': '+90 532 111 22 33',
      'musteri_adres': 'Ece Mahallesi, Sandıklı / Afyonkarahisar',
      'usta_ad': 'Kadir Usta',
      'usta_tel': '05524342069',
      'usta_meslek': 'Elektrik & Aydınlatma Teknisyeni',
      'usta_hakedis': 1750.0,
      'komisyon_tutari': 262.5,
      'komisyon_orani': 0.15,
      'toplam_tutar': 2012.5,
      'durum': 'Tamamlandı & Tahsil Edildi',
      'flow_step': 4,
      'payment_provider': 'İyzico Sanal POS • 3D Secure',
      'payment_status': 'Provizyon Kapandı / Tahsil Edildi',
      'puan': 5.0,
      'musteri_yorum': 'Hizmet zamanında ve kusursuz tamamlandı.',
      'created_at': '13.11.2026 • 23:49',
      'is_payout_transferred': true,
    };

    // 2. Mobil uygulama işi tamamlayıp AppDataService'e kaydettiğinde
    await appData.addOrUpdateFinancialTransaction(completedService);

    // 3. Admin panelinin aynı veriyi getFinancialTransactions ile okuyabildiğini doğrula
    final transactions = await appData.getFinancialTransactions();
    expect(transactions, isNotEmpty);
    expect(transactions.first['receipt_no'], equals('demo_pay_1794613769383'));
    expect(transactions.first['usta_ad'], equals('Kadir Usta'));
    expect(transactions.first['durum'], equals('Tamamlandı & Tahsil Edildi'));
    expect(transactions.first['toplam_tutar'], equals(2012.5));
    expect(transactions.first['flow_step'], equals(4));

    // 4. Müşteri değerlendirme yorumu eklediğinde anında güncellenme testi
    await appData.addOrUpdateFinancialTransaction({
      'receipt_no': 'demo_pay_1794613769383',
      'puan': 5.0,
      'musteri_yorum': 'Kadir Usta çok temiz çalıştı, tavsiye ederim.',
    });

    final updated = await appData.getFinancialTransactions();
    expect(updated.length, equals(1));
    expect(updated.first['musteri_yorum'], equals('Kadir Usta çok temiz çalıştı, tavsiye ederim.'));
    expect(updated.first['toplam_tutar'], equals(2012.5));
  });
}
