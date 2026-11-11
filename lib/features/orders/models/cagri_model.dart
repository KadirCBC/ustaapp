import 'package:geolocator/geolocator.dart';

enum CagriDurumu {
  bekliyor,
  kabulEdildi,
  yolda,
  tamamlandi,
  iptal;

  static CagriDurumu fromDbValue(String? value) {
    switch (value?.toLowerCase()) {
      case 'kabul_edildi':
        return CagriDurumu.kabulEdildi;
      case 'yolda':
        return CagriDurumu.yolda;
      case 'tamamlandi':
        return CagriDurumu.tamamlandi;
      case 'iptal':
        return CagriDurumu.iptal;
      case 'bekliyor':
      default:
        return CagriDurumu.bekliyor;
    }
  }

  String toDbValue() {
    switch (this) {
      case CagriDurumu.bekliyor:
        return 'bekliyor';
      case CagriDurumu.kabulEdildi:
        return 'kabul_edildi';
      case CagriDurumu.yolda:
        return 'yolda';
      case CagriDurumu.tamamlandi:
        return 'tamamlandi';
      case CagriDurumu.iptal:
        return 'iptal';
    }
  }

  String get displayName {
    switch (this) {
      case CagriDurumu.bekliyor:
        return 'Usta Onayı Bekleniyor';
      case CagriDurumu.kabulEdildi:
        return 'Çağrı Kabul Edildi';
      case CagriDurumu.yolda:
        return 'Usta Yolda';
      case CagriDurumu.tamamlandi:
        return 'İşlem Tamamlandı';
      case CagriDurumu.iptal:
        return 'Çağrı İptal Edildi';
    }
  }
}

class CagriModel {
  final String id;
  final String musteriId;
  final String? ustaId;
  final double musteriLat;
  final double musteriLng;
  final String? adresTarifi;
  final CagriDurumu durum;
  final double? ustaHakedis;
  final double? komisyonTutari;
  final double? toplamTutar;
  final String? paymentIntentId;
  final DateTime createdAt;
  final String? ustaFullName;
  final String? ustaPhone;
  final String? musteriFullName;
  final String? musteriPhone;

  CagriModel({
    required this.id,
    required this.musteriId,
    this.ustaId,
    required this.musteriLat,
    required this.musteriLng,
    this.adresTarifi,
    required this.durum,
    this.ustaHakedis,
    this.komisyonTutari,
    this.toplamTutar,
    this.paymentIntentId,
    required this.createdAt,
    this.ustaFullName,
    this.ustaPhone,
    this.musteriFullName,
    this.musteriPhone,
  });

  factory CagriModel.fromJson(Map<String, dynamic> json) {
    double lat = 41.0082;
    double lng = 28.9784;

    final rawKonum = json['musteri_konum'];
    if (rawKonum is Map && rawKonum['coordinates'] is List) {
      final coords = rawKonum['coordinates'] as List;
      if (coords.length >= 2) {
        lng = (coords[0] as num).toDouble();
        lat = (coords[1] as num).toDouble();
      }
    } else if (rawKonum is String && rawKonum.contains('POINT')) {
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

    return CagriModel(
      id: json['id'] as String,
      musteriId: json['musteri_id'] as String,
      ustaId: json['usta_id'] as String?,
      musteriLat: lat,
      musteriLng: lng,
      adresTarifi: json['adres_tarifi'] as String?,
      durum: CagriDurumu.fromDbValue(json['durum'] as String?),
      ustaHakedis: (json['usta_hakedis'] as num?)?.toDouble(),
      komisyonTutari: (json['komisyon_tutari'] as num?)?.toDouble(),
      toplamTutar: (json['toplam_tutar'] as num?)?.toDouble(),
      paymentIntentId: json['payment_intent_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      ustaFullName: json['usta_full_name'] as String?,
      ustaPhone: json['usta_phone'] as String?,
      musteriFullName: json['musteri_full_name'] as String?,
      musteriPhone: json['musteri_phone'] as String?,
    );
  }

  bool get isPending => durum == CagriDurumu.bekliyor;
  bool get isAccepted => durum == CagriDurumu.kabulEdildi;
  bool get isOnTheWay => durum == CagriDurumu.yolda;
  bool get isCompleted => durum == CagriDurumu.tamamlandi;
  bool get isCancelled => durum == CagriDurumu.iptal;

  CagriModel copyWith({
    String? id,
    String? musteriId,
    String? ustaId,
    double? musteriLat,
    double? musteriLng,
    String? adresTarifi,
    CagriDurumu? durum,
    double? ustaHakedis,
    double? komisyonTutari,
    double? toplamTutar,
    String? paymentIntentId,
    DateTime? createdAt,
    String? ustaFullName,
    String? ustaPhone,
    String? musteriFullName,
    String? musteriPhone,
  }) {
    return CagriModel(
      id: id ?? this.id,
      musteriId: musteriId ?? this.musteriId,
      ustaId: ustaId ?? this.ustaId,
      musteriLat: musteriLat ?? this.musteriLat,
      musteriLng: musteriLng ?? this.musteriLng,
      adresTarifi: adresTarifi ?? this.adresTarifi,
      durum: durum ?? this.durum,
      ustaHakedis: ustaHakedis ?? this.ustaHakedis,
      komisyonTutari: komisyonTutari ?? this.komisyonTutari,
      toplamTutar: toplamTutar ?? this.toplamTutar,
      paymentIntentId: paymentIntentId ?? this.paymentIntentId,
      createdAt: createdAt ?? this.createdAt,
      ustaFullName: ustaFullName ?? this.ustaFullName,
      ustaPhone: ustaPhone ?? this.ustaPhone,
      musteriFullName: musteriFullName ?? this.musteriFullName,
      musteriPhone: musteriPhone ?? this.musteriPhone,
    );
  }

  /// Usta konumu ile müşteri evi arasındaki mesafe (metre)
  double distanceInMetersFrom(double fromLat, double fromLng) {
    return Geolocator.distanceBetween(fromLat, fromLng, musteriLat, musteriLng);
  }

  /// Formatlanmış mesafe metni (Örn: "850 m" veya "1.4 km")
  String formattedDistanceFrom(double fromLat, double fromLng) {
    final meters = distanceInMetersFrom(fromLat, fromLng);
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} metre';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}

class DemoWorkflowState {
  final bool ustaArrived;
  final DateTime? arrivedAt;
  final bool completionRequested;
  final String? reportedIssue;
  final String? receiptId;
  final double? ustaAverageRating;

  const DemoWorkflowState({
    this.ustaArrived = false,
    this.arrivedAt,
    this.completionRequested = false,
    this.reportedIssue,
    this.receiptId,
    this.ustaAverageRating,
  });

  DemoWorkflowState copyWith({
    bool? ustaArrived,
    DateTime? arrivedAt,
    bool? completionRequested,
    String? reportedIssue,
    String? receiptId,
    double? ustaAverageRating,
    bool clearIssue = false,
  }) {
    return DemoWorkflowState(
      ustaArrived: ustaArrived ?? this.ustaArrived,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      completionRequested: completionRequested ?? this.completionRequested,
      reportedIssue: clearIssue ? null : (reportedIssue ?? this.reportedIssue),
      receiptId: receiptId ?? this.receiptId,
      ustaAverageRating: ustaAverageRating ?? this.ustaAverageRating,
    );
  }
}

/// Çevrimdışı / Demo modunda çağrı eşleşme döngüsünü tutan bellek içi depo
class DemoCallRepository {
  static final Map<String, CagriModel> _calls = {};
  static final Map<String, DemoWorkflowState> _workflows = {};

  static void save(CagriModel call) {
    _calls[call.id] = call;
  }

  static CagriModel? get(String id) => _calls[id];

  static void updateStatus(String id, CagriDurumu status) {
    final existing = _calls[id];
    if (existing != null) {
      _calls[id] = existing.copyWith(durum: status);
    }
  }

  static DemoWorkflowState getWorkflow(String id) =>
      _workflows[id] ?? const DemoWorkflowState();

  static void saveWorkflow(String id, DemoWorkflowState state) {
    _workflows[id] = state;
  }
}
