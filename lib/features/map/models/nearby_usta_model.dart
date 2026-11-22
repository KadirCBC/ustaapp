class UstaHizmetIlan {
  final String id;
  final String baslik;
  final String aciklama;
  final double fiyat;
  final String tahminiSure;
  final String ikon;
  final bool isDefault;
  final String? konum;
  final double? lat;
  final double? lng;
  final String? kategori;

  const UstaHizmetIlan({
    required this.id,
    required this.baslik,
    required this.aciklama,
    required this.fiyat,
    this.tahminiSure = '30-45 dk',
    this.ikon = '⚡',
    this.isDefault = false,
    this.konum,
    this.lat,
    this.lng,
    this.kategori,
  });

  factory UstaHizmetIlan.fromJson(Map<String, dynamic> json) {
    return UstaHizmetIlan(
      id: json['id'] as String? ?? 'ilan-1',
      baslik: json['baslik'] as String? ?? 'Hizmet',
      aciklama: json['aciklama'] as String? ?? '',
      fiyat: (json['fiyat'] as num?)?.toDouble() ?? 0.0,
      tahminiSure: json['tahmini_sure'] as String? ?? '30 dk',
      ikon: json['ikon'] as String? ?? '🔧',
      isDefault: json['is_default'] as bool? ?? false,
      konum: json['konum'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      kategori: json['kategori'] as String? ?? json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'baslik': baslik,
    'aciklama': aciklama,
    'fiyat': fiyat,
    'tahmini_sure': tahminiSure,
    'ikon': ikon,
    'is_default': isDefault,
    if (konum != null) 'konum': konum,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    if (kategori != null) 'kategori': kategori,
    if (kategori != null) 'category': kategori,
  };

  UstaHizmetIlan copyWith({
    String? id,
    String? baslik,
    String? aciklama,
    double? fiyat,
    String? tahminiSure,
    String? ikon,
    bool? isDefault,
    String? konum,
    double? lat,
    double? lng,
    String? kategori,
  }) {
    return UstaHizmetIlan(
      id: id ?? this.id,
      baslik: baslik ?? this.baslik,
      aciklama: aciklama ?? this.aciklama,
      fiyat: fiyat ?? this.fiyat,
      tahminiSure: tahminiSure ?? this.tahminiSure,
      ikon: ikon ?? this.ikon,
      isDefault: isDefault ?? this.isDefault,
      konum: konum ?? this.konum,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      kategori: kategori ?? this.kategori,
    );
  }
}

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
  final double servisUcreti;
  final double kmBasiYakitUcreti;
  final double ucretsizMesafeKm;
  final double acilGeceUcreti;
  final double calismaYaricapiKm;
  final bool hasCustomTarife;
  final int deneyimYili;
  final String uzmanlikBasligi;
  final List<String> guvenceler;
  final List<UstaHizmetIlan> ilanlar;
  final bool isOnline;
  final bool isOnayli;

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
    this.servisUcreti = 0.0,
    this.kmBasiYakitUcreti = 0.0,
    this.ucretsizMesafeKm = 0.0,
    this.acilGeceUcreti = 0.0,
    this.calismaYaricapiKm = 20.0,
    this.hasCustomTarife = false,
    this.deneyimYili = 10,
    this.uzmanlikBasligi = 'Onaylı Uzman Usta',
    this.guvenceler = const [
      '30 Gün İşçilik Garantisi',
      'Sabit Fiyat Güvencesi',
      'MYK Belgeli',
    ],
    this.ilanlar = const [],
    this.isOnline = true,
    this.isOnayli = false,
  });

  factory NearbyUstaModel.fromJson(Map<String, dynamic> json) {
    // PostGIS geography verisinden koordinat ayrıştırma
    double lat = (json['latitude'] as num?)?.toDouble() ?? 41.0082; // Varsayılan İstanbul
    double lng = (json['longitude'] as num?)?.toDouble() ?? 28.9784;

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

    final rawIlanlar = json['ilanlar'] as List<dynamic>?;
    final List<UstaHizmetIlan> parsedIlanlar = rawIlanlar != null
        ? rawIlanlar
            .map((e) => UstaHizmetIlan.fromJson(e as Map<String, dynamic>))
            .toList()
        : const [];

    final rawGuvenceler = json['guvenceler'] as List<dynamic>?;
    final List<String> parsedGuvenceler = rawGuvenceler != null
        ? rawGuvenceler.map((e) => e.toString()).toList()
        : const [
            '30 Gün İşçilik Garantisi',
            'Sabit Fiyat Güvencesi',
            'MYK Belgeli',
          ];

    return NearbyUstaModel(
      ustaId: (json['usta_id'] ?? json['ustaId'] ?? json['id'] ?? 'usta-${DateTime.now().millisecondsSinceEpoch}').toString(),
      fullName: (json['full_name'] ?? json['fullName'] ?? json['name'] ?? 'Usta').toString(),
      phone: (json['phone'] ?? '').toString(),
      avatarUrl: json['avatar_url']?.toString() ?? json['avatarUrl']?.toString(),
      kategori: (json['kategori'] ?? json['category'] ?? 'elektrik').toString(),
      puan: (json['puan'] as num?)?.toDouble() ?? (json['rating'] as num?)?.toDouble() ?? 5.0,
      tamamlananIsSayisi:
          (json['tamamlanan_is_sayisi'] as num?)?.toInt() ?? (json['completed_jobs'] as num?)?.toInt() ?? 48,
      latitude: lat,
      longitude: lng,
      mesafeMetre: (json['mesafe_metre'] as num?)?.toDouble() ?? 0.0,
      ustaHakedis: (json['usta_hakedis'] as num?)?.toDouble() ?? (json['hakedis'] as num?)?.toDouble() ?? 0.0,
      komisyonOrani: (json['komisyon_orani'] as num?)?.toDouble() ?? 0.15,
      komisyonTutari: (json['komisyon_tutari'] as num?)?.toDouble() ?? 0.0,
      toplamTutar: (json['toplam_tutar'] as num?)?.toDouble() ?? (json['price'] as num?)?.toDouble() ?? 0.0,
      servisUcreti: (json['servis_ucreti'] as num?)?.toDouble() ?? 0.0,
      kmBasiYakitUcreti: (json['km_basi_yakit_ucreti'] as num?)?.toDouble() ?? (json['km_fee'] as num?)?.toDouble() ?? 0.0,
      ucretsizMesafeKm: (json['ucretsiz_mesafe_km'] as num?)?.toDouble() ?? 0.0,
      acilGeceUcreti: (json['acil_gece_ucreti'] as num?)?.toDouble() ?? 0.0,
      calismaYaricapiKm: (json['calisma_yaricapi_km'] as num?)?.toDouble() ?? 20.0,
      hasCustomTarife: json['has_custom_tarife'] as bool? ?? false,
      deneyimYili: (json['deneyim_yili'] as num?)?.toInt() ?? 10,
      uzmanlikBasligi:
          (json['uzmanlik_basligi'] ?? json['uzmanlikBasligi'] ?? json['location'] ?? 'Onaylı Uzman Usta').toString(),
      guvenceler: parsedGuvenceler,
      ilanlar: parsedIlanlar,
      isOnline: json['is_online'] as bool? ?? json['isOnline'] as bool? ?? true,
      isOnayli: json['is_onayli'] as bool? ??
          json['isOnayli'] as bool? ??
          json['is_verified'] as bool? ??
          false,
    );
  }

  /// Onaylı üye mi? (Yalnızca vergi/kimlik/yönetici onayı almış ustalarda true döner)
  bool get isApprovedMember =>
      isOnayli ||
      guvenceler.any((g) {
        final lower = g.toLowerCase();
        return lower.contains('vergi') || lower.contains('onay') || lower.contains('yetkili');
      });

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

  Map<String, dynamic> toJson() => {
    'usta_id': ustaId,
    'full_name': fullName,
    'phone': phone,
    'avatar_url': avatarUrl,
    'kategori': kategori,
    'puan': puan,
    'tamamlanan_is_sayisi': tamamlananIsSayisi,
    'latitude': latitude,
    'longitude': longitude,
    'mesafe_metre': mesafeMetre,
    'usta_hakedis': ustaHakedis,
    'komisyon_orani': komisyonOrani,
    'komisyon_tutari': komisyonTutari,
    'toplam_tutar': toplamTutar,
    'servis_ucreti': servisUcreti,
    'km_basi_yakit_ucreti': kmBasiYakitUcreti,
    'ucretsiz_mesafe_km': ucretsizMesafeKm,
    'acil_gece_ucreti': acilGeceUcreti,
    'calisma_yaricapi_km': calismaYaricapiKm,
    'has_custom_tarife': hasCustomTarife,
    'deneyim_yili': deneyimYili,
    'uzmanlik_basligi': uzmanlikBasligi,
    'guvenceler': guvenceler,
    'ilanlar': ilanlar.map((e) => e.toJson()).toList(),
    'is_online': isOnline,
    'isOnline': isOnline,
    'is_onayli': isOnayli,
  };

  NearbyUstaModel copyWith({
    String? ustaId,
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? kategori,
    double? puan,
    int? tamamlananIsSayisi,
    double? latitude,
    double? longitude,
    double? mesafeMetre,
    double? ustaHakedis,
    double? komisyonOrani,
    double? komisyonTutari,
    double? toplamTutar,
    double? servisUcreti,
    double? kmBasiYakitUcreti,
    double? ucretsizMesafeKm,
    double? acilGeceUcreti,
    double? calismaYaricapiKm,
    bool? hasCustomTarife,
    int? deneyimYili,
    String? uzmanlikBasligi,
    List<String>? guvenceler,
    List<UstaHizmetIlan>? ilanlar,
    bool? isOnline,
    bool? isOnayli,
  }) {
    return NearbyUstaModel(
      ustaId: ustaId ?? this.ustaId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      kategori: kategori ?? this.kategori,
      puan: puan ?? this.puan,
      tamamlananIsSayisi: tamamlananIsSayisi ?? this.tamamlananIsSayisi,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      mesafeMetre: mesafeMetre ?? this.mesafeMetre,
      ustaHakedis: ustaHakedis ?? this.ustaHakedis,
      komisyonOrani: komisyonOrani ?? this.komisyonOrani,
      komisyonTutari: komisyonTutari ?? this.komisyonTutari,
      toplamTutar: toplamTutar ?? this.toplamTutar,
      servisUcreti: servisUcreti ?? this.servisUcreti,
      kmBasiYakitUcreti: kmBasiYakitUcreti ?? this.kmBasiYakitUcreti,
      ucretsizMesafeKm: ucretsizMesafeKm ?? this.ucretsizMesafeKm,
      acilGeceUcreti: acilGeceUcreti ?? this.acilGeceUcreti,
      calismaYaricapiKm: calismaYaricapiKm ?? this.calismaYaricapiKm,
      hasCustomTarife: hasCustomTarife ?? this.hasCustomTarife,
      deneyimYili: deneyimYili ?? this.deneyimYili,
      uzmanlikBasligi: uzmanlikBasligi ?? this.uzmanlikBasligi,
      guvenceler: guvenceler ?? this.guvenceler,
      ilanlar: ilanlar ?? this.ilanlar,
      isOnline: isOnline ?? this.isOnline,
      isOnayli: isOnayli ?? this.isOnayli,
    );
  }
}
