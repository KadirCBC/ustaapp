import 'package:flutter_test/flutter_test.dart';
import 'package:ustaapp/features/map/models/isletme_model.dart';

void main() {
  group('İşletmeler ve Tedarikçiler Model & Filtreleme Testleri', () {
    test('IsletmeModel.fromJson Supabase formatını doğru parse eder', () {
      final jsonSupabase = {
        'id': 'isl-1',
        'ad': 'Kadıköy Elektrik Dünyası (Toptan & Perakende)',
        'kategori': 'Elektrik Malzemesi & Toptan',
        'konum': 'POINT(29.0285 40.9912)',
        'telefon': '+90 216 414 50 60',
        'adres': 'Osmanağa Mah. Söğütlüçeşme Cad. No:44, Kadıköy',
        'is_sponsored': true,
      };

      final isletme = IsletmeModel.fromJson(jsonSupabase);

      expect(isletme.id, 'isl-1');
      expect(isletme.ad, contains('Elektrik'));
      expect(isletme.kategori, contains('Elektrik'));
      expect(isletme.latitude, closeTo(40.9912, 0.0001));
      expect(isletme.longitude, closeTo(29.0285, 0.0001));
      expect(isletme.telefon, '+90 216 414 50 60');
      expect(isletme.adres, contains('Osmanağa'));
      expect(isletme.isSponsored, isTrue);
    });

    test('IsletmeModel Map/GeoJSON konum formatlarını da destekler', () {
      final jsonMapKonum = {
        'id': 'isl-2',
        'ad': 'Moda Teknik Sıhhi Tesisat Market',
        'kategori': 'Sıhhi Tesisat & Su Armatürleri',
        'konum': {
          'lat': 40.9850,
          'lng': 29.0240,
        },
        'telefon': '+90 216 330 12 12',
        'adres': 'Caferağa Mah. Moda Cad. No:88, Kadıköy',
        'is_sponsored': false,
      };

      final isletme = IsletmeModel.fromJson(jsonMapKonum);

      expect(isletme.id, 'isl-2');
      expect(isletme.latitude, closeTo(40.9850, 0.0001));
      expect(isletme.longitude, closeTo(29.0240, 0.0001));
      expect(isletme.isSponsored, isFalse);
    });

    test('Mesafe formatlama (formattedDistance)', () {
      const isletmeYakin = IsletmeModel(
        id: '1',
        ad: 'Dükkan 1',
        kategori: 'Hırdavat',
        latitude: 40.0,
        longitude: 29.0,
        telefon: '123',
        adres: 'Adres',
        mesafeMetre: 450,
      );

      const isletmeUzak = IsletmeModel(
        id: '2',
        ad: 'Dükkan 2',
        kategori: 'Elektrik',
        latitude: 40.0,
        longitude: 29.0,
        telefon: '123',
        adres: 'Adres',
        mesafeMetre: 3200,
      );

      expect(isletmeYakin.formattedDistance, '450 m');
      expect(isletmeUzak.formattedDistance, '3.2 km');
    });

    test('Sponsorlu dükkanlar sıralamada en üste geçer', () {
      final isletmeler = [
        const IsletmeModel(
          id: '1',
          ad: 'Normal Dükkan 1',
          kategori: 'Hırdavat',
          latitude: 40.0,
          longitude: 29.0,
          telefon: '',
          adres: '',
          isSponsored: false,
          mesafeMetre: 200,
        ),
        const IsletmeModel(
          id: '2',
          ad: 'Sponsorlu Dükkan',
          kategori: 'Hırdavat',
          latitude: 40.0,
          longitude: 29.0,
          telefon: '',
          adres: '',
          isSponsored: true,
          mesafeMetre: 500,
        ),
      ];

      isletmeler.sort((a, b) {
        if (a.isSponsored && !b.isSponsored) return -1;
        if (!a.isSponsored && b.isSponsored) return 1;
        return a.mesafeMetre.compareTo(b.mesafeMetre);
      });

      expect(isletmeler.first.id, '2');
      expect(isletmeler.first.isSponsored, isTrue);
    });
  });
}
