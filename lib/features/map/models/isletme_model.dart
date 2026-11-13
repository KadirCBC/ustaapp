class IsletmeModel {
  final String id;
  final String ad;
  final String kategori;
  final double latitude;
  final double longitude;
  final String telefon;
  final String adres;
  final bool isSponsored;
  final double mesafeMetre;

  const IsletmeModel({
    required this.id,
    required this.ad,
    required this.kategori,
    required this.latitude,
    required this.longitude,
    required this.telefon,
    required this.adres,
    this.isSponsored = false,
    this.mesafeMetre = 0.0,
  });

  factory IsletmeModel.fromJson(Map<String, dynamic> json) {
    double lat = 0.0;
    double lng = 0.0;

    // 1. Doğrudan latitude / longitude kontrolü
    if (json['latitude'] != null) {
      lat = (json['latitude'] as num).toDouble();
    }
    if (json['longitude'] != null) {
      lng = (json['longitude'] as num).toDouble();
    }

    // 2. 'lat' / 'lng' ve Türkçe 'enlem' / 'boylam' kontrolü
    if (lat == 0.0 && json['lat'] != null) {
      lat = (json['lat'] as num).toDouble();
    }
    if (lng == 0.0 && json['lng'] != null) {
      lng = (json['lng'] as num).toDouble();
    }
    if (lat == 0.0 && json['enlem'] != null) {
      lat = (json['enlem'] as num).toDouble();
    }
    if (lng == 0.0 && json['boylam'] != null) {
      lng = (json['boylam'] as num).toDouble();
    }

    // 3. 'konum' sütunu (PostGIS Point, GeoJSON veya Map/String) kontrolü
    final konum = json['konum'];
    if (konum != null) {
      if (konum is Map) {
        if (konum['lat'] != null) lat = (konum['lat'] as num).toDouble();
        if (konum['lng'] != null) lng = (konum['lng'] as num).toDouble();
        if (konum['latitude'] != null) lat = (konum['latitude'] as num).toDouble();
        if (konum['longitude'] != null) lng = (konum['longitude'] as num).toDouble();
        if (konum['coordinates'] is List && (konum['coordinates'] as List).length >= 2) {
          final coords = konum['coordinates'] as List;
          lng = (coords[0] as num).toDouble();
          lat = (coords[1] as num).toDouble();
        }
      } else if (konum is String) {
        final clean = konum.replaceAll('POINT(', '').replaceAll(')', '').trim();
        if (clean.contains(' ')) {
          final parts = clean.split(' ');
          if (parts.length >= 2) {
            lng = double.tryParse(parts[0]) ?? lng;
            lat = double.tryParse(parts[1]) ?? lat;
          }
        } else if (clean.contains(',')) {
          final parts = clean.split(',');
          if (parts.length >= 2) {
            lat = double.tryParse(parts[0].trim()) ?? lat;
            lng = double.tryParse(parts[1].trim()) ?? lng;
          }
        }
      }
    }

    final ad = json['ad'] as String? ??
        json['business_name'] as String? ??
        json['name'] as String? ??
        'İşletme / Tedarikçi';

    final isSponsored = json['is_sponsored'] as bool? ??
        json['isSponsored'] as bool? ??
        json['is_featured'] as bool? ??
        false;

    return IsletmeModel(
      id: json['id']?.toString() ?? 'isletme-${DateTime.now().millisecondsSinceEpoch}',
      ad: ad,
      kategori: json['kategori'] as String? ?? 'Hırdavat & Nalburiye',
      latitude: lat,
      longitude: lng,
      telefon: json['telefon'] as String? ?? json['phone'] as String? ?? '',
      adres: json['adres'] as String? ?? json['address'] as String? ?? '',
      isSponsored: isSponsored,
      mesafeMetre: (json['mesafe_metre'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ad': ad,
    'kategori': kategori,
    'latitude': latitude,
    'longitude': longitude,
    'telefon': telefon,
    'adres': adres,
    'is_sponsored': isSponsored,
    'mesafe_metre': mesafeMetre,
  };

  IsletmeModel copyWith({
    String? id,
    String? ad,
    String? kategori,
    double? latitude,
    double? longitude,
    String? telefon,
    String? adres,
    bool? isSponsored,
    double? mesafeMetre,
  }) {
    return IsletmeModel(
      id: id ?? this.id,
      ad: ad ?? this.ad,
      kategori: kategori ?? this.kategori,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      telefon: telefon ?? this.telefon,
      adres: adres ?? this.adres,
      isSponsored: isSponsored ?? this.isSponsored,
      mesafeMetre: mesafeMetre ?? this.mesafeMetre,
    );
  }

  String get formattedDistance {
    if (mesafeMetre <= 0) return '';
    if (mesafeMetre < 1000) {
      return '${mesafeMetre.toStringAsFixed(0)} m';
    }
    return '${(mesafeMetre / 1000).toStringAsFixed(1)} km';
  }
}
