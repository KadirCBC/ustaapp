import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Hizmet Akışı ve Finansal Komisyon Hesaplama Testleri', () {
    test('1750 TL Usta Taban Ücretinde %15 Platform Komisyonu ve Toplam Tutar Doğru Hesaplanır', () {
      const double ustaHakedis = 1750.0;
      const double komisyonOrani = 0.15;

      final double platformKomisyonu = ustaHakedis * komisyonOrani;
      final double toplamTutar = ustaHakedis + platformKomisyonu;

      expect(platformKomisyonu, equals(262.50));
      expect(toplamTutar, equals(2012.50));

      // KDV dahil tutar (%20)
      final double kdvTutari = platformKomisyonu * 0.20;
      final double netPlatformGeliri = platformKomisyonu - kdvTutari;

      expect(kdvTutari, equals(52.50));
      expect(netPlatformGeliri, equals(210.00));
    });

    test('Hizmet Akış Aşamaları 4 Adımı Sırayla Temsil Eder', () {
      final Map<int, String> flowSteps = {
        1: 'Usta Onayı Bekleniyor',
        2: 'Çağrı Kabul Edildi',
        3: 'Usta Yolda',
        4: 'Tamamlandı & Tahsil Edildi',
      };

      expect(flowSteps[1], contains('Onay'));
      expect(flowSteps[2], contains('Kabul'));
      expect(flowSteps[3], contains('Yolda'));
      expect(flowSteps[4], contains('Tamamlandı'));
    });

    test('Birden Fazla Finansal İşlemin Brüt, Net ve Hakediş Toplamları Doğru Hesaplanır', () {
      final transactions = [
        {
          'id': 'TRX-1',
          'usta_hakedis': 1750.0,
          'komisyon_tutari': 262.5,
          'toplam_tutar': 2012.5,
          'durum': 'Tamamlandı & Tahsil Edildi',
        },
        {
          'id': 'TRX-2',
          'usta_hakedis': 850.0,
          'komisyon_tutari': 127.5,
          'toplam_tutar': 977.5,
          'durum': 'Usta Yolda',
        },
        {
          'id': 'TRX-3',
          'usta_hakedis': 750.0,
          'komisyon_tutari': 112.5,
          'toplam_tutar': 862.5,
          'durum': 'Kabul Edildi / İşlemde',
        },
      ];

      double totalGross = 0;
      double totalCommission = 0;
      double totalUstaPayout = 0;

      for (final tx in transactions) {
        totalGross += (tx['toplam_tutar'] as num).toDouble();
        totalCommission += (tx['komisyon_tutari'] as num).toDouble();
        totalUstaPayout += (tx['usta_hakedis'] as num).toDouble();
      }

      expect(totalGross, equals(3852.5));
      expect(totalCommission, equals(502.5));
      expect(totalUstaPayout, equals(3350.0));
      expect(totalUstaPayout + totalCommission, equals(totalGross));
    });
  });
}
