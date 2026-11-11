class NearbyUstaModel {
  final String ustaId;
  final String fullName;
  final String phone;
  final String? avatarUrl;
  final String kategori;
  final double puan;
  final int tamamlananIsSayisi;
  final double latitude;
  final double longitude;
  final double mesafeMetre;
  final double ustaHakedis;
  final double komisyonOrani;
  final double komisyonTutari;
  final double toplamTutar;

  NearbyUstaModel({
    required this.ustaId,
    required this.fullName,
    required this.phone,
    this.avatarUrl,
    required this.kategori,
    required this.puan,
    this.tamamlananIsSayisi = 48,
    required this.latitude,
    required this.longitude,
    required this.mesafeMetre,
    required this.ustaHakedis,
    required this.komisyonOrani,
    required this.komisyonTutari,
    required this.toplamTutar,
  });

  factory NearbyUstaModel.fromJson(Map<String, dynamic> json) {
    // PostGIS geography verisinden koordinat ayrıştırma
    double lat = 41.0082; // Varsayılan İstanbul
    double lng = 28.9784;

    final rawKonum = json['konum'];
    if (rawKonum is Map && rawKonum['coordinates'] is List) {
      // GeoJSON formatında: [longitude, latitude]
      final coords = rawKonum['coordinates'] as List;
      if (coords.length >= 2) {
        lng = (coords[0] as num).toDouble();
        lat = (coords[1] as num).toDouble();
      }
    } else if (rawKonum is String && rawKonum.contains('POINT')) {
      // WKT formatı: POINT(28.9784 41.0082)
      final parts = rawKonum
          .replaceAll('POINT(', '')
          .replaceAll(')', '')
          .trim()
          .split(' ');
      if (parts.length >= 2) {
        lng = double.tryParse(parts[0]) ?? lng;
        lat = double.tryParse(parts[1]) ?? lat;
      }
    }

    return NearbyUstaModel(
      ustaId: json['usta_id'] as String,
      fullName: json['full_name'] as String? ?? 'Usta',
      phone: json['phone'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      kategori: json['kategori'] as String? ?? 'elektrik',
      puan: (json['puan'] as num?)?.toDouble() ?? 5.0,
      tamamlananIsSayisi:
          (json['tamamlanan_is_sayisi'] as num?)?.toInt() ?? 48,
      latitude: lat,
      longitude: lng,
      mesafeMetre: (json['mesafe_metre'] as num?)?.toDouble() ?? 0.0,
      ustaHakedis: (json['usta_hakedis'] as num?)?.toDouble() ?? 0.0,
      komisyonOrani: (json['komisyon_orani'] as num?)?.toDouble() ?? 0.15,
      komisyonTutari: (json['komisyon_tutari'] as num?)?.toDouble() ?? 0.0,
      toplamTutar: (json['toplam_tutar'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Harita pini üzerinde kompakt isim (Örn: "Ahmet U.")
  String get shortDisplayName {
    final cleaned = fullName.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'Usta';
    if (parts.length == 1) return parts.first;
    final secondInitial = parts[1].isNotEmpty ? '${parts[1][0]}.' : '';
    return '${parts[0]} $secondInitial'.trim();
  }

  String get formattedDistance {
    if (mesafeMetre < 1000) {
      return '${mesafeMetre.toStringAsFixed(0)} m';
    }
    return '${(mesafeMetre / 1000).toStringAsFixed(1)} km';
  }

  String get formattedPrice => '${toplamTutar.toStringAsFixed(0)} ₺';

  int get tahminiVarisDakika {
    final distanceKm = mesafeMetre / 1000.0;
    return (distanceKm * 2.5 + 8).round().clamp(5, 60);
  }

  String get tahminiVarisSuresi {
    final minMinutes = tahminiVarisDakika;
    final maxMinutes = minMinutes + 7;
    return '$minMinutes - $maxMinutes dk';
  }
}
