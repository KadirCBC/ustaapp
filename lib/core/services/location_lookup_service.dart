import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:ustaapp/core/constants/app_constants.dart';

class LocationSuggestion {
  final String label;
  final String shortLabel;
  final double lat;
  final double lng;

  const LocationSuggestion({
    required this.label,
    required this.shortLabel,
    required this.lat,
    required this.lng,
  });

  @override
  String toString() => '$label ($lat, $lng)';
}

/// Google Haritalar benzeri adres arama ve koordinat çözümleme servisi.
/// Kullanıcı adres, semt, cadde veya şehir yazdığında gerçek zamanlı Mapbox Geocoding
/// ve yerel Türkiye il/ilçe veritabanı üzerinden anında koordinat ve konum bilgisi üretir.
class LocationLookupService {
  // Yerel Çevrimdışı / Hızlı Türkiye İl ve İlçe Veritabanı
  static final Map<String, ({double lat, double lng, String label, String shortLabel})> _localLocations = {
    // İstanbul
    'kadikoy': (lat: 40.9905, lng: 29.0270, label: 'Kadıköy, İstanbul', shortLabel: 'Kadıköy'),
    'moda': (lat: 40.9850, lng: 29.0285, label: 'Moda, Kadıköy, İstanbul', shortLabel: 'Kadıköy / Moda'),
    'bagdat caddesi': (lat: 40.9634, lng: 29.0664, label: 'Bağdat Caddesi, Kadıköy, İstanbul', shortLabel: 'Bağdat Caddesi'),
    'caddebostan': (lat: 40.9667, lng: 29.0612, label: 'Caddebostan, Kadıköy, İstanbul', shortLabel: 'Caddebostan'),
    'suadiye': (lat: 40.9600, lng: 29.0833, label: 'Suadiye, Kadıköy, İstanbul', shortLabel: 'Suadiye'),
    'bostanci': (lat: 40.9531, lng: 29.0947, label: 'Bostancı, Kadıköy, İstanbul', shortLabel: 'Bostancı'),
    'besiktas': (lat: 41.0430, lng: 29.0072, label: 'Beşiktaş, İstanbul', shortLabel: 'Beşiktaş'),
    'ortakoy': (lat: 41.0483, lng: 29.0261, label: 'Ortaköy, Beşiktaş, İstanbul', shortLabel: 'Beşiktaş / Ortaköy'),
    'levent': (lat: 41.0822, lng: 29.0116, label: 'Levent, Beşiktaş, İstanbul', shortLabel: 'Levent'),
    'etiler': (lat: 41.0839, lng: 29.0308, label: 'Etiler, Beşiktaş, İstanbul', shortLabel: 'Etiler'),
    'uskudar': (lat: 41.0233, lng: 29.0153, label: 'Üsküdar, İstanbul', shortLabel: 'Üsküdar'),
    'sisli': (lat: 41.0602, lng: 28.9877, label: 'Şişli, İstanbul', shortLabel: 'Şişli'),
    'mecidiyekoy': (lat: 41.0665, lng: 28.9942, label: 'Mecidiyeköy, Şişli, İstanbul', shortLabel: 'Mecidiyeköy'),
    'atasehir': (lat: 40.9847, lng: 29.1067, label: 'Ataşehir, İstanbul', shortLabel: 'Ataşehir'),
    'umraniye': (lat: 41.0256, lng: 29.1161, label: 'Ümraniye, İstanbul', shortLabel: 'Ümraniye'),
    'maltepe': (lat: 40.9248, lng: 29.1311, label: 'Maltepe, İstanbul', shortLabel: 'Maltepe'),
    'kartal': (lat: 40.8886, lng: 29.1856, label: 'Kartal, İstanbul', shortLabel: 'Kartal'),
    'pendik': (lat: 40.8797, lng: 29.2331, label: 'Pendik, İstanbul', shortLabel: 'Pendik'),
    'bakirkoy': (lat: 40.9801, lng: 28.8721, label: 'Bakırköy, İstanbul', shortLabel: 'Bakırköy'),
    'beyoglu': (lat: 41.0369, lng: 28.9775, label: 'Beyoğlu, İstanbul', shortLabel: 'Beyoğlu'),
    'taksim': (lat: 41.0370, lng: 28.9850, label: 'Taksim, Beyoğlu, İstanbul', shortLabel: 'Taksim'),
    'fatih': (lat: 41.0186, lng: 28.9497, label: 'Fatih, İstanbul', shortLabel: 'Fatih'),
    'sariyer': (lat: 41.1667, lng: 29.0500, label: 'Sarıyer, İstanbul', shortLabel: 'Sarıyer'),
    'beylikduzu': (lat: 41.0019, lng: 28.6419, label: 'Beylikdüzü, İstanbul', shortLabel: 'Beylikdüzü'),

    // Ankara
    'cankaya': (lat: 39.9035, lng: 32.8597, label: 'Çankaya, Ankara', shortLabel: 'Çankaya'),
    'kizilay': (lat: 39.9208, lng: 32.8541, label: 'Kızılay, Çankaya, Ankara', shortLabel: 'Kızılay'),
    'tunali': (lat: 39.9010, lng: 32.8610, label: 'Tunalı Hilmi, Çankaya, Ankara', shortLabel: 'Tunalı'),
    'yenimahalle': (lat: 39.9678, lng: 32.8058, label: 'Yenimahalle, Ankara', shortLabel: 'Yenimahalle'),
    'kecioren': (lat: 39.9772, lng: 32.8653, label: 'Keçiören, Ankara', shortLabel: 'Keçiören'),
    'etimesgut': (lat: 39.9458, lng: 32.6833, label: 'Etimesgut, Ankara', shortLabel: 'Etimesgut'),
    'ankara': (lat: 39.9334, lng: 32.8597, label: 'Ankara', shortLabel: 'Ankara'),

    // İzmir
    'karsiyaka': (lat: 38.4590, lng: 27.1100, label: 'Karşıyaka, İzmir', shortLabel: 'Karşıyaka'),
    'alsancak': (lat: 38.4389, lng: 27.1436, label: 'Alsancak, Konak, İzmir', shortLabel: 'Alsancak'),
    'konak': (lat: 38.4189, lng: 27.1287, label: 'Konak, İzmir', shortLabel: 'Konak'),
    'bornova': (lat: 38.4697, lng: 27.2183, label: 'Bornova, İzmir', shortLabel: 'Bornova'),
    'buca': (lat: 38.3881, lng: 27.1772, label: 'Buca, İzmir', shortLabel: 'Buca'),
    'izmir': (lat: 38.4237, lng: 27.1428, label: 'İzmir', shortLabel: 'İzmir'),

    // Afyonkarahisar & Kullanıcının Bölgesi
    'sandikli': (lat: 38.4647, lng: 30.2719, label: 'Sandıklı, Afyonkarahisar', shortLabel: 'Sandıklı'),
    'ece sandikli': (lat: 38.4601, lng: 30.2655, label: 'Ece Mah., Sandıklı, Afyonkarahisar', shortLabel: 'Ece, Sandıklı'),
    'ece fidan sokak': (lat: 38.4615, lng: 30.2670, label: 'Ece Mah. Fidan Sk., Sandıklı', shortLabel: 'Ece, Fidan Sokak'),
    'fidan sokak': (lat: 38.4615, lng: 30.2670, label: 'Fidan Sokak, Sandıklı', shortLabel: 'Fidan Sokak'),
    'cakir sandikli': (lat: 38.4669, lng: 30.2711, label: 'Çakır Mah., Sandıklı, Afyonkarahisar', shortLabel: 'Çakır, Sandıklı'),
    'cakir': (lat: 38.4669, lng: 30.2711, label: 'Çakır Mah., Sandıklı, Afyonkarahisar', shortLabel: 'Çakır, Sandıklı'),
    'ece': (lat: 38.4601, lng: 30.2655, label: 'Ece Mah., Sandıklı, Afyonkarahisar', shortLabel: 'Ece, Sandıklı'),
    'hisar': (lat: 38.4650, lng: 30.2680, label: 'Hisar Mah., Sandıklı, Afyonkarahisar', shortLabel: 'Hisar, Sandıklı'),
    'afyonkarahisar': (lat: 38.7507, lng: 30.5567, label: 'Afyonkarahisar', shortLabel: 'Afyonkarahisar'),
    'afyon': (lat: 38.7507, lng: 30.5567, label: 'Afyonkarahisar', shortLabel: 'Afyonkarahisar'),
    'dinar': (lat: 38.0650, lng: 30.1656, label: 'Dinar, Afyonkarahisar', shortLabel: 'Dinar'),
    'bolvadin': (lat: 38.7117, lng: 31.0489, label: 'Bolvadin, Afyonkarahisar', shortLabel: 'Bolvadin'),

    // Diğer Büyük Şehirler
    'bursa': (lat: 40.1885, lng: 29.0610, label: 'Bursa', shortLabel: 'Bursa'),
    'nilufer': (lat: 40.2144, lng: 28.9819, label: 'Nilüfer, Bursa', shortLabel: 'Nilüfer'),
    'antalya': (lat: 36.8969, lng: 30.7133, label: 'Antalya', shortLabel: 'Antalya'),
    'muratpasa': (lat: 36.8841, lng: 30.7056, label: 'Muratpaşa, Antalya', shortLabel: 'Muratpaşa'),
    'adana': (lat: 37.0000, lng: 35.3213, label: 'Adana', shortLabel: 'Adana'),
    'kocaeli': (lat: 40.7654, lng: 29.9408, label: 'Kocaeli (İzmit)', shortLabel: 'Kocaeli'),
    'izmit': (lat: 40.7654, lng: 29.9408, label: 'İzmit, Kocaeli', shortLabel: 'İzmit'),
    'eskisehir': (lat: 39.7767, lng: 30.5206, label: 'Eskişehir', shortLabel: 'Eskişehir'),
    'tepebasi': (lat: 39.7925, lng: 30.5111, label: 'Tepebaşı, Eskişehir', shortLabel: 'Tepebaşı'),
    'gaziantep': (lat: 37.0662, lng: 37.3833, label: 'Gaziantep', shortLabel: 'Gaziantep'),
    'konya': (lat: 37.8746, lng: 32.4932, label: 'Konya', shortLabel: 'Konya'),
  };

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Verilen adres veya konum metni için en uygun öneri ve koordinatları döner.
  static Future<List<LocationSuggestion>> searchAddress(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final suggestions = <LocationSuggestion>[];
    final normalized = _normalize(cleanQuery);

    // 1. Canlı Mapbox Geocoding API Sorgusu (Gerçek adresler, caddeler, sokaklar için)
    try {
      const token = AppConstants.mapboxAccessToken;
      final encoded = Uri.encodeComponent(cleanQuery);
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json?access_token=$token&country=tr&language=tr&limit=5',
      );

      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>?;
        if (features != null && features.isNotEmpty) {
          for (final f in features) {
            final center = f['center'] as List<dynamic>?;
            if (center != null && center.length >= 2) {
              final lng = (center[0] as num).toDouble();
              final lat = (center[1] as num).toDouble();

              final detailed = formatTurkishDetailedAddress(f);

              suggestions.add(LocationSuggestion(
                label: detailed,
                shortLabel: detailed,
                lat: lat,
                lng: lng,
              ));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[LocationLookupService] Mapbox arama hatası: $e');
    }

    // 2. Yerel Sözlük Eşleştirmesi (Hızlı sonuç ve çevrimdışı fallback)
    for (final entry in _localLocations.entries) {
      if (entry.key.contains(normalized) || normalized.contains(entry.key)) {
        final loc = entry.value;
        // Eğer zaten Mapbox'tan çok yakın bir sonuç eklenmemişse ekle
        final alreadyAdded = suggestions.any((s) => (s.lat - loc.lat).abs() < 0.01 && (s.lng - loc.lng).abs() < 0.01);
        if (!alreadyAdded) {
          suggestions.add(LocationSuggestion(
            label: loc.label,
            shortLabel: loc.shortLabel,
            lat: loc.lat,
            lng: loc.lng,
          ));
        }
      }
    }

    return suggestions;
  }

  /// Hızlı tekil çözümleme: Verilen adresten direkt koordinat çifti döner
  static Future<LocationSuggestion?> resolveBestMatch(String query) async {
    final list = await searchAddress(query);
    if (list.isNotEmpty) return list.first;

    // Son çare: Yerel sözlükten parça eşleştirme
    final normalized = _normalize(query);
    for (final entry in _localLocations.entries) {
      if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
        final loc = entry.value;
        return LocationSuggestion(
          label: loc.label,
          shortLabel: loc.shortLabel,
          lat: loc.lat,
          lng: loc.lng,
        );
      }
    }
    return null;
  }

  /// Mapbox Geocoding sonucunu Türkiye standartlarında tam açık adrese (Mahalle, Sokak/Cadde, Kapı No, İlçe, İl) dönüştürür.
  static String formatTurkishDetailedAddress(Map<String, dynamic> feature) {
    final street = (feature['text_tr'] ?? feature['text'] ?? '').toString().trim();
    final houseNumber = (feature['address'] ?? '').toString().trim();

    String locality = '';
    String place = '';
    String region = '';

    final context = feature['context'] as List<dynamic>?;
    if (context != null) {
      for (final c in context) {
        final id = (c['id'] ?? '').toString();
        final text = (c['text_tr'] ?? c['text'] ?? '').toString().trim();
        if (id.startsWith('locality') || id.startsWith('neighborhood')) {
          locality = text;
        } else if (id.startsWith('place') || id.startsWith('district')) {
          place = text;
        } else if (id.startsWith('region')) {
          region = text;
        }
      }
    }

    final buffer = <String>[];
    if (locality.isNotEmpty) {
      buffer.add(locality.endsWith('Mahallesi') || locality.endsWith('Mah.') || locality.endsWith('Mah')
          ? locality
          : '$locality Mah.');
    }
    if (street.isNotEmpty) {
      if (houseNumber.isNotEmpty) {
        buffer.add('$street No:$houseNumber');
      } else {
        buffer.add(street);
      }
    }

    String distCity = '';
    if (place.isNotEmpty && region.isNotEmpty) {
      distCity = '$place, $region';
    } else if (place.isNotEmpty) {
      distCity = place;
    } else if (region.isNotEmpty) {
      distCity = region;
    }

    if (buffer.isNotEmpty) {
      final streetPart = buffer.join(' ');
      return distCity.isNotEmpty ? '$streetPart, $distCity' : streetPart;
    }

    // Fallback: raw place_name'i temizle
    final raw = (feature['place_name_tr'] ?? feature['place_name'] ?? '').toString();
    return raw
        .replaceAll(', Türkiye', '')
        .replaceAll(', Turkey', '')
        .replaceAll(RegExp(r'\b\d{5}\b\s*'), '')
        .replaceAll('/', ', ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Koordinattan (lat, lng) tam ve doğru Türkçe adres (Mahalle, Sokak, Kapı No, İlçe, İl) çözer.
  static Future<LocationSuggestion> reverseGeocode(double lat, double lng) async {
    try {
      const token = AppConstants.mapboxAccessToken;
      if (token.isNotEmpty) {
        final uri = Uri.https(
          'api.mapbox.com',
          '/geocoding/v5/mapbox.places/$lng,$lat.json',
          {
            'access_token': token,
            'language': 'tr',
            'limit': '1',
          },
        );

        final res = await http.get(uri).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          final features = data['features'] as List<dynamic>?;
          if (features != null && features.isNotEmpty) {
            final first = features.first as Map<String, dynamic>;
            final detailedAddress = formatTurkishDetailedAddress(first);

            return LocationSuggestion(
              label: detailedAddress,
              shortLabel: detailedAddress,
              lat: lat,
              lng: lng,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[LocationLookupService] Reverse geocode hatası: $e');
    }

    // Çevrimdışı / Hızlı Yerel Sözlük Fallback: En yakın bilinen il/ilçe
    double minDistance = double.infinity;
    LocationSuggestion? closest;
    for (final entry in _localLocations.values) {
      final d = Geolocator.distanceBetween(lat, lng, entry.lat, entry.lng);
      if (d < minDistance) {
        minDistance = d;
        closest = LocationSuggestion(
          label: entry.label,
          shortLabel: entry.shortLabel,
          lat: lat,
          lng: lng,
        );
      }
    }
    if (closest != null && minDistance < 45000) {
      return closest;
    }

    return LocationSuggestion(
      label: 'Konum (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})',
      shortLabel: '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
      lat: lat,
      lng: lng,
    );
  }

  /// Senkron hızlı çözümleme: Verilen adresi yerel sözlükten anında çözer
  static LocationSuggestion? resolveSync(String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return null;
    for (final entry in _localLocations.entries) {
      if (normalized == entry.key || normalized.contains(entry.key) || entry.key.contains(normalized)) {
        final loc = entry.value;
        return LocationSuggestion(
          label: loc.label,
          shortLabel: loc.shortLabel,
          lat: loc.lat,
          lng: loc.lng,
        );
      }
    }
    return null;
  }
}
