import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ustaapp/core/services/location_lookup_service.dart';
import 'package:ustaapp/features/map/controllers/map_controller.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';

void main() {
  group('Konum ve Mesafe Yarıçapı Filtreleme Testleri', () {
    test('Bolvadin usta mesafesi: Kadıköy vs Bolvadin', () {
      const kadikoyLat = 40.9905;
      const kadikoyLng = 29.0270;

      const bolvadinLat = 38.710617;
      const bolvadinLng = 31.047974;

      final distFromKadikoy = Geolocator.distanceBetween(
        kadikoyLat,
        kadikoyLng,
        bolvadinLat,
        bolvadinLng,
      );

      final distFromBolvadin = Geolocator.distanceBetween(
        38.7106,
        31.0505,
        bolvadinLat,
        bolvadinLng,
      );

      // Kadıköy - Bolvadin arası kuş uçuşu ~350 km (> 300.000 metre)
      expect(distFromKadikoy, greaterThan(300000));

      // Bolvadin merkezi ile usta arası < 1 km (< 1000 metre)
      expect(distFromBolvadin, lessThan(1000));

      // 25 km yarıçap kontrolü
      const maxRadius = 25000.0;
      expect(distFromKadikoy <= maxRadius, isFalse);
      expect(distFromBolvadin <= maxRadius, isTrue);
    });

    test('CustomerMapController bilinen konumlarda Bolvadin ve Sandıklı çözümlemesi', () {
      final bolvadinMatch = CustomerMapController.resolveKnownLocation('Bolvadin, Afyonkarahisar');
      expect(bolvadinMatch, isNotNull);
      expect(bolvadinMatch!.lat, closeTo(38.71, 0.05));
      expect(bolvadinMatch.lng, closeTo(31.05, 0.05));

      final bolvadinShortMatch = CustomerMapController.resolveKnownLocation('bolvadin');
      expect(bolvadinShortMatch, isNotNull);
      expect(bolvadinShortMatch!.label, contains('Bolvadin'));

      final kadikoyMatch = CustomerMapController.resolveKnownLocation('Kadıköy, İstanbul');
      expect(kadikoyMatch, isNotNull);
      expect(kadikoyMatch!.lat, closeTo(40.99, 0.01));
    });

    test('LocationLookupService Bolvadin tekil çözümleme', () async {
      final match = await LocationLookupService.resolveBestMatch('Bolvadin');
      expect(match, isNotNull);
      expect(match!.lat, closeTo(38.71, 0.05));
      expect(match.lng, closeTo(31.05, 0.05));
    });

    test('Usta listesi yarıçap filtreleme mantığı', () {
      final kadirUsta = NearbyUstaModel(
        ustaId: 'usta-bolvadin-1',
        fullName: 'Kadir Usta',
        phone: '5524342069',
        kategori: 'elektrik',
        puan: 5.0,
        tamamlananIsSayisi: 12,
        latitude: 38.710617,
        longitude: 31.047974,
        mesafeMetre: 0,
        ustaHakedis: 1750,
        komisyonOrani: 0.15,
        komisyonTutari: 262.5,
        toplamTutar: 2012.5,
        servisUcreti: 150,
        deneyimYili: 10,
        uzmanlikBasligi: 'Bolvadin, Afyonkarahisar',
        guvenceler: const ['Garantili Hizmet'],
        ilanlar: const [],
      );

      final ahmetUsta = NearbyUstaModel(
        ustaId: 'usta-kadikoy-1',
        fullName: 'Ahmet Usta',
        phone: '5551112233',
        kategori: 'elektrik',
        puan: 4.9,
        tamamlananIsSayisi: 45,
        latitude: 40.9910,
        longitude: 29.0280,
        mesafeMetre: 0,
        ustaHakedis: 950,
        komisyonOrani: 0.15,
        komisyonTutari: 142.5,
        toplamTutar: 1092.5,
        servisUcreti: 100,
        deneyimYili: 8,
        uzmanlikBasligi: 'Kadıköy, İstanbul',
        guvenceler: const ['MYK Belgeli'],
        ilanlar: const [],
      );

      final allUstalar = [kadirUsta, ahmetUsta];
      const maxRadius = 25000.0; // 25 km

      // Kadıköy'deki müşteri (40.9905, 29.0270)
      final ustalarKadikoy = allUstalar.where((u) {
        final dist = Geolocator.distanceBetween(
          40.9905,
          29.0270,
          u.latitude,
          u.longitude,
        );
        return dist <= maxRadius;
      }).toList();

      expect(ustalarKadikoy.length, 1);
      expect(ustalarKadikoy.first.fullName, 'Ahmet Usta');

      // Bolvadin'deki müşteri (38.7106, 31.0505)
      final ustalarBolvadin = allUstalar.where((u) {
        final dist = Geolocator.distanceBetween(
          38.7106,
          31.0505,
          u.latitude,
          u.longitude,
        );
        return dist <= maxRadius;
      }).toList();

      expect(ustalarBolvadin.length, 1);
      expect(ustalarBolvadin.first.fullName, 'Kadir Usta');
    });
  });
}
