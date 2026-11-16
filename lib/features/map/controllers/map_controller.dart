import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/core/services/app_data_service.dart';
import 'package:ustaapp/core/services/location_lookup_service.dart';
import 'package:ustaapp/core/services/location_service.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/features/map/models/isletme_model.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';

class CustomerMapState {
  final double currentLat;
  final double currentLng;
  final String currentAddressLabel;
  final String selectedCategory; // 'elektrik', 'cilingir', 'tesisat', 'tedarikciler'
  final int searchRadiusMeter; // varsayılan 25000 metre (25km)
  final List<NearbyUstaModel> nearbyUstalar;
  final NearbyUstaModel? selectedUsta;
  final List<IsletmeModel> isletmeler;
  final IsletmeModel? selectedIsletme;
  final bool isLoadingLocation;
  final bool isLoadingUstalar;
  final bool isLoadingIsletmeler;
  final bool isCreatingCall;
  final String? activeCallId;
  final String? errorMessage;

  const CustomerMapState({
    this.currentLat = 40.9905, // Varsayılan Kadıköy, İstanbul
    this.currentLng = 29.0270,
    this.currentAddressLabel = 'Kadıköy, İstanbul',
    this.selectedCategory = 'elektrik',
    this.searchRadiusMeter = 25000,
    this.nearbyUstalar = const [],
    this.selectedUsta,
    this.isletmeler = const [],
    this.selectedIsletme,
    this.isLoadingLocation = false,
    this.isLoadingUstalar = false,
    this.isLoadingIsletmeler = false,
    this.isCreatingCall = false,
    this.activeCallId,
    this.errorMessage,
  });

  CustomerMapState copyWith({
    double? currentLat,
    double? currentLng,
    String? currentAddressLabel,
    String? selectedCategory,
    int? searchRadiusMeter,
    List<NearbyUstaModel>? nearbyUstalar,
    NearbyUstaModel? selectedUsta,
    bool clearSelectedUsta = false,
    List<IsletmeModel>? isletmeler,
    IsletmeModel? selectedIsletme,
    bool clearSelectedIsletme = false,
    bool? isLoadingLocation,
    bool? isLoadingUstalar,
    bool? isLoadingIsletmeler,
    bool? isCreatingCall,
    String? activeCallId,
    String? errorMessage,
  }) {
    return CustomerMapState(
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      currentAddressLabel: currentAddressLabel ?? this.currentAddressLabel,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchRadiusMeter: searchRadiusMeter ?? this.searchRadiusMeter,
      nearbyUstalar: nearbyUstalar ?? this.nearbyUstalar,
      selectedUsta: clearSelectedUsta ? null : (selectedUsta ?? this.selectedUsta),
      isletmeler: isletmeler ?? this.isletmeler,
      selectedIsletme: clearSelectedIsletme ? null : (selectedIsletme ?? this.selectedIsletme),
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
      isLoadingUstalar: isLoadingUstalar ?? this.isLoadingUstalar,
      isLoadingIsletmeler: isLoadingIsletmeler ?? this.isLoadingIsletmeler,
      isCreatingCall: isCreatingCall ?? this.isCreatingCall,
      activeCallId: activeCallId ?? this.activeCallId,
      errorMessage: errorMessage,
    );
  }
}

final customerMapControllerProvider =
    StateNotifierProvider.autoDispose<CustomerMapController, CustomerMapState>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final locationService = ref.watch(locationServiceProvider);
  final appDataService = ref.watch(appDataServiceProvider);
  return CustomerMapController(supabase, locationService, appDataService);
});

class CustomerMapController extends StateNotifier<CustomerMapState> {
  final SupabaseClient _supabase;
  final LocationService _locationService;
  final AppDataService _appDataService;
  StreamSubscription<void>? _dataSubscription;

  CustomerMapController(this._supabase, this._locationService, this._appDataService)
      : super(const CustomerMapState()) {
    _dataSubscription = _appDataService.onDataChanged.listen((_) {
      if (mounted) {
        fetchNearbyUstalar();
        fetchIsletmeler();
      }
    });
    initCustomerLocationAndSearch();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  /// Müşteri konumunu alır ve yakındaki ustaları ve işletmeleri otomatik arar
  Future<void> initCustomerLocationAndSearch() async {
    state = state.copyWith(isLoadingLocation: true, errorMessage: null);

    try {
      final hasPermission = await _locationService.checkAndRequestPermissions();
      if (!mounted) return;
      if (hasPermission) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 4),
        );
        if (!mounted) return;
        state = state.copyWith(
          currentLat: position.latitude,
          currentLng: position.longitude,
          isLoadingLocation: false,
        );
      } else {
        state = state.copyWith(isLoadingLocation: false);
      }
    } catch (e) {
      debugPrint('Müşteri konumu alınamadı (varsayılan kullanılıyor): $e');
      if (!mounted) return;
      state = state.copyWith(isLoadingLocation: false);
    }

    if (!mounted) return;
    await Future.wait([
      fetchNearbyUstalar(),
      fetchIsletmeler(),
    ]);
  }

  List<NearbyUstaModel> _filterAndSortUstalar(List<NearbyUstaModel> list) {
    final mapped = list.map((u) {
      final dist = Geolocator.distanceBetween(
        state.currentLat,
        state.currentLng,
        u.latitude,
        u.longitude,
      );
      return u.copyWith(mesafeMetre: dist > 0 ? dist : u.mesafeMetre);
    }).toList();
    // Türkiye genelindeki tüm aktif ustaları haritada göster, mesafeye göre sırala
    mapped.sort((a, b) => a.mesafeMetre.compareTo(b.mesafeMetre));
    return mapped;
  }

  /// PostGIS RPC fonksiyonu `yakin_ustalari_getir` veya Admin Panelinin yönettiği canlı usta verisini çeker
  Future<void> fetchNearbyUstalar() async {
    // Eğer kategori 'tedarikciler' ise usta araması yapılmaz, sadece dükkanlar listelenir
    if (state.selectedCategory == 'tedarikciler') {
      state = state.copyWith(
        isLoadingUstalar: false,
        nearbyUstalar: [],
        clearSelectedUsta: true,
      );
      return;
    }

    // 1. Anında yerel önbellek / sync servisinden yükle (0 ms gecikme)
    try {
      final managedUstalar = await _appDataService.getNearbyUstalar(
        category: state.selectedCategory,
        customerLat: state.currentLat,
        customerLng: state.currentLng,
        maxRadiusMeter: state.searchRadiusMeter.toDouble(),
      );
      if (mounted) {
        state = state.copyWith(
          nearbyUstalar: _filterAndSortUstalar(managedUstalar),
          isLoadingUstalar: false,
          clearSelectedUsta: managedUstalar.isEmpty,
        );
      }
    } catch (_) {}

    state = state.copyWith(
      isLoadingUstalar: state.nearbyUstalar.isEmpty,
      errorMessage: null,
    );

    List<NearbyUstaModel> ustalar = [];

    try {
      final response = await _supabase.rpc('yakin_ustalari_getir', params: {
        'p_lat': state.currentLat,
        'p_lng': state.currentLng,
        'p_kategori': state.selectedCategory,
        'p_radius_meter': state.searchRadiusMeter,
      }).timeout(const Duration(milliseconds: 1500));

      final List<dynamic> data = response as List<dynamic>? ?? [];
      ustalar = data
          .map((item) => NearbyUstaModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {}

    if (!mounted) return;

    if (ustalar.isNotEmpty) {
      state = state.copyWith(
        isLoadingUstalar: false,
        nearbyUstalar: _filterAndSortUstalar(ustalar),
        clearSelectedUsta: true,
        errorMessage: null,
      );
    } else if (state.nearbyUstalar.isEmpty) {
      state = state.copyWith(
        isLoadingUstalar: false,
        nearbyUstalar: [],
        clearSelectedUsta: true,
      );
    }
  }

  List<IsletmeModel> _processAndFilterIsletmeler(List<IsletmeModel> rawList) {
    final mapped = rawList.map((item) {
      final dist = Geolocator.distanceBetween(
        state.currentLat,
        state.currentLng,
        item.latitude,
        item.longitude,
      );
      return item.copyWith(mesafeMetre: dist > 0 ? dist : item.mesafeMetre);
    }).toList();

    final result = (state.selectedCategory == 'tedarikciler')
        ? mapped
        : mapped.where((b) {
            final cat = b.kategori.toLowerCase();
            final sel = state.selectedCategory.toLowerCase();
            return cat.contains(sel) || sel.contains(cat) || b.isSponsored;
          }).toList();

    result.sort((a, b) {
      if (a.isSponsored && !b.isSponsored) return -1;
      if (!a.isSponsored && b.isSponsored) return 1;
      return a.mesafeMetre.compareTo(b.mesafeMetre);
    });
    return result;
  }

  /// Supabase `isletmeler` tablosundan veya yerel tedarikçilerden dükkanları anında çeker
  Future<void> fetchIsletmeler() async {
    // 1. ANINDA YEREL ÖNBELLEKTEN YÜKLE (Gecikmesiz, 0 ms)
    try {
      final local = await _appDataService.getNearbyTedarikciler(
        customerLat: state.currentLat,
        customerLng: state.currentLng,
        maxRadiusMeter: state.searchRadiusMeter.toDouble(),
      );
      if (local.isNotEmpty && mounted) {
        final localList = local.map((item) => IsletmeModel.fromJson(item)).toList();
        final processed = _processAndFilterIsletmeler(localList);
        state = state.copyWith(
          isletmeler: processed,
          isLoadingIsletmeler: false,
        );
      }
    } catch (e) {
      debugPrint('Yerel işletme okuma uyarısı: $e');
    }

    // 2. Supabase'den arka planda veri çekme (Kısa timeout: 1.5 sn)
    try {
      final response = await _supabase
          .from('isletmeler')
          .select('id, ad, kategori, konum, telefon, adres, is_sponsored')
          .timeout(const Duration(milliseconds: 1500));

      final List<dynamic> data = response as List<dynamic>? ?? [];
      if (data.isNotEmpty && mounted) {
        final remoteList = data
            .map((item) => IsletmeModel.fromJson(item as Map<String, dynamic>))
            .toList();
        final processed = _processAndFilterIsletmeler(remoteList);
        state = state.copyWith(
          isletmeler: processed,
          isLoadingIsletmeler: false,
        );
      }
    } catch (e) {
      debugPrint('Supabase isletmeler sorgu uyarısı: $e');
    } finally {
      if (mounted && state.isLoadingIsletmeler) {
        state = state.copyWith(isLoadingIsletmeler: false);
      }
    }
  }

  static const Map<String, ({double lat, double lng, String label})>
      _knownLocations = {
    'kadikoy, istanbul': (lat: 40.9905, lng: 29.0270, label: 'Kadıköy, İstanbul'),
    'kadikoy': (lat: 40.9905, lng: 29.0270, label: 'Kadıköy, İstanbul'),
    'besiktas, istanbul': (lat: 41.0430, lng: 29.0072, label: 'Beşiktaş, İstanbul'),
    'besiktas': (lat: 41.0430, lng: 29.0072, label: 'Beşiktaş, İstanbul'),
    'uskudar, istanbul': (lat: 41.0233, lng: 29.0153, label: 'Üsküdar, İstanbul'),
    'sisli, istanbul': (lat: 41.0602, lng: 28.9877, label: 'Şişli, İstanbul'),
    'bolvadin, afyonkarahisar': (
      lat: 38.7106,
      lng: 31.0505,
      label: 'Bolvadin, Afyonkarahisar',
    ),
    'bolvadin': (
      lat: 38.7106,
      lng: 31.0505,
      label: 'Bolvadin, Afyonkarahisar',
    ),
    'sandikli, afyonkarahisar': (
      lat: 38.4647,
      lng: 30.2719,
      label: 'Sandıklı, Afyonkarahisar',
    ),
    'sandikli': (lat: 38.4647, lng: 30.2719, label: 'Sandıklı, Afyonkarahisar'),
    'afyonkarahisar': (lat: 38.7507, lng: 30.5567, label: 'Afyonkarahisar'),
    'afyon': (lat: 38.7507, lng: 30.5567, label: 'Afyonkarahisar'),
    'cankaya, ankara': (lat: 39.9035, lng: 32.8597, label: 'Çankaya, Ankara'),
    'cankaya': (lat: 39.9035, lng: 32.8597, label: 'Çankaya, Ankara'),
    'ankara': (lat: 39.9334, lng: 32.8597, label: 'Ankara'),
    'karsiyaka, izmir': (lat: 38.4590, lng: 27.1100, label: 'Karşıyaka, İzmir'),
    'karsiyaka': (lat: 38.4590, lng: 27.1100, label: 'Karşıyaka, İzmir'),
    'izmir': (lat: 38.4237, lng: 27.1428, label: 'İzmir'),
    'istanbul': (lat: 41.0082, lng: 28.9784, label: 'İstanbul'),
  };

  static String _normalizeAddressKey(String input) {
    return input
        .trim()
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s*,\s*'), ', ');
  }

  Future<({double lat, double lng, String label})?> _queryMapboxGeocoding(
    String pathSegment,
    Map<String, String> queryParams,
  ) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.https(
        'api.mapbox.com',
        '/geocoding/v5/mapbox.places/$pathSegment.json',
        {
          'language': 'tr',
          'limit': '1',
          'access_token': AppConstants.mapboxAccessToken,
          ...queryParams,
        },
      );
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 5));
      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final features = decoded['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) return null;

      final first = features.first as Map<String, dynamic>;
      final center = first['center'] as List<dynamic>?;
      if (center == null || center.length < 2) return null;

      final lng = (center[0] as num).toDouble();
      final lat = (center[1] as num).toDouble();
      final placeName =
          (first['place_name_tr'] ?? first['place_name'] ?? '') as String;
      final parts = placeName
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && e != 'Türkiye' && e != 'Turkey')
          .toList();
      final shortLabel = parts.take(2).join(', ');
      return (lat: lat, lng: lng, label: shortLabel);
    } catch (e) {
      debugPrint('Mapbox geocoding hatası: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<({double lat, double lng, String label})?> _geocodeAddressWithMapbox(
    String query,
  ) {
    return _queryMapboxGeocoding(
      Uri.encodeComponent(query),
      const {'country': 'tr'},
    );
  }

  Future<String?> _reverseGeocodeWithMapbox(double lat, double lng) async {
    final result = await _queryMapboxGeocoding(
      '$lng,$lat',
      const {'types': 'district,place,locality'},
    );
    return (result != null && result.label.isNotEmpty) ? result.label : null;
  }

  /// Bilinen ilçe/şehir isimlerini veya normalleştirilmiş sorguyu koordinata çözer.
  static ({double lat, double lng, String label})? resolveKnownLocation(
    String address,
  ) {
    final normalized = _normalizeAddressKey(address);
    final exact = _knownLocations[normalized];
    if (exact != null) return exact;

    for (final entry in _knownLocations.entries) {
      if (normalized.contains(entry.key) && entry.key.contains(',')) {
        return entry.value;
      }
    }
    return null;
  }

  /// Seçilen veya yazılan adresi koordinata çözer, haritayı ve yakındaki ustaları günceller.
  Future<bool> updateLocationByAddress(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return false;

    state = state.copyWith(isLoadingLocation: true, errorMessage: null);

    var resolved = resolveKnownLocation(trimmed);
    if (resolved == null) {
      final match = await LocationLookupService.resolveBestMatch(trimmed);
      if (match != null) {
        resolved = (lat: match.lat, lng: match.lng, label: match.shortLabel);
      }
    }
    resolved ??= await _geocodeAddressWithMapbox(trimmed);
    if (!mounted) return false;

    if (resolved == null) {
      state = state.copyWith(isLoadingLocation: false);
      return false;
    }

    state = state.copyWith(
      currentLat: resolved.lat,
      currentLng: resolved.lng,
      currentAddressLabel: trimmed.contains(',') ? trimmed : resolved.label,
      clearSelectedUsta: true,
      clearSelectedIsletme: true,
      isLoadingLocation: false,
    );

    await Future.wait([
      fetchNearbyUstalar(),
      fetchIsletmeler(),
    ]);
    return true;
  }

  /// Cihaz GPS konumunu alarak haritayı ve yakındaki ustaları günceller.
  Future<bool> useCurrentGpsLocation() async {
    state = state.copyWith(isLoadingLocation: true, errorMessage: null);
    try {
      final hasPermission = await _locationService.checkAndRequestPermissions();
      if (!mounted) return false;
      if (!hasPermission) {
        state = state.copyWith(isLoadingLocation: false);
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      if (!mounted) return false;

      final label = await _reverseGeocodeWithMapbox(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return false;

      state = state.copyWith(
        currentLat: position.latitude,
        currentLng: position.longitude,
        currentAddressLabel: label ?? 'Mevcut Konumum',
        clearSelectedUsta: true,
        clearSelectedIsletme: true,
        isLoadingLocation: false,
      );
      await Future.wait([
        fetchNearbyUstalar(),
        fetchIsletmeler(),
      ]);
      return true;
    } catch (e) {
      debugPrint('GPS konumu alınamadı: $e');
      if (!mounted) return false;
      state = state.copyWith(isLoadingLocation: false);
      return false;
    }
  }

  /// Müşterinin görünen adres/semt başlığını günceller ve haritayı o konuma taşır.
  Future<void> setAddressLabel(String address) async {
    await updateLocationByAddress(address);
  }

  /// Kategori değiştirme ('elektrik', 'cilingir', 'tesisat', 'tedarikciler')
  void setCategory(String category) {
    if (state.selectedCategory != category) {
      state = state.copyWith(
        selectedCategory: category,
        clearSelectedUsta: true,
        clearSelectedIsletme: true,
      );
      if (category == 'tedarikciler') {
        state = state.copyWith(nearbyUstalar: [], isLoadingUstalar: false);
        fetchIsletmeler();
      } else {
        fetchNearbyUstalar();
        fetchIsletmeler();
      }
    }
  }

  /// Arama yarıçapını değiştirme (metre)
  void setRadius(int meter) {
    if (state.searchRadiusMeter != meter) {
      state = state.copyWith(searchRadiusMeter: meter);
      fetchNearbyUstalar();
      fetchIsletmeler();
    }
  }

  /// Harita veya listeden bir usta seçme
  void selectUsta(NearbyUstaModel usta) {
    state = state.copyWith(selectedUsta: usta, clearSelectedIsletme: true);
  }

  /// Usta seçimini kaldırarak özet bara geri dönme
  void clearSelectedUsta() {
    state = state.copyWith(clearSelectedUsta: true);
  }

  /// Harita veya listeden bir dükkan/tedarikçi işletme seçme
  void selectIsletme(IsletmeModel isletme) {
    state = state.copyWith(selectedIsletme: isletme, clearSelectedUsta: true);
  }

  /// İşletme seçimini kaldırma
  void clearSelectedIsletme() {
    state = state.copyWith(clearSelectedIsletme: true);
  }

  /// Seçili ustaya doğrudan çağrı oluşturma (durum: 'bekliyor')
  Future<String?> createCagri({
    required NearbyUstaModel usta,
    required String adresTarifi,
  }) async {
    final customerId = _supabase.auth.currentUser?.id;

    state = state.copyWith(isCreatingCall: true, errorMessage: null);

    // Demo oturumunda yerel çağrı kaydı oluştur
    if (customerId == null) {
      final demoId = 'demo-cagri-${DateTime.now().millisecondsSinceEpoch}';
      final demoCall = CagriModel(
        id: demoId,
        musteriId: 'demo-musteri-id',
        ustaId: usta.ustaId,
        musteriLat: state.currentLat,
        musteriLng: state.currentLng,
        adresTarifi: adresTarifi.trim().isNotEmpty
            ? adresTarifi.trim()
            : state.currentAddressLabel,
        durum: CagriDurumu.bekliyor,
        ustaHakedis: usta.ustaHakedis,
        komisyonTutari: usta.komisyonTutari,
        toplamTutar: usta.toplamTutar,
        createdAt: DateTime.now(),
        ustaFullName: usta.fullName,
        ustaPhone: usta.phone,
        musteriFullName: 'Ahmet Demir',
        musteriPhone: '+90 532 999 88 77',
      );
      DemoCallRepository.save(demoCall);

      final now = DateTime.now();
      final dateStr =
          '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} • ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      _appDataService.addOrUpdateFinancialTransaction({
        'id': 'TRX-${demoId.replaceAll(RegExp(r'[^0-9]'), '')}',
        'receipt_no': 'demo_pay_${now.millisecondsSinceEpoch}',
        'cagri_id': demoId,
        'hizmet_baslik': usta.ilanlar.isNotEmpty ? usta.ilanlar.first.baslik : 'Standart Servis & Arıza Tespiti',
        'kategori': usta.kategori == 'elektrik'
            ? 'Elektrik & Aydınlatma'
            : (usta.kategori == 'tesisat' ? 'Sıhhi Tesisat & Su Kaçağı' : 'Çilingir & Kapı Açma'),
        'musteri_ad': 'Zeynep Kaya',
        'musteri_tel': '+90 532 111 22 33',
        'musteri_adres': adresTarifi.trim().isNotEmpty ? adresTarifi.trim() : state.currentAddressLabel,
        'usta_ad': usta.fullName,
        'usta_tel': usta.phone,
        'usta_meslek': usta.uzmanlikBasligi,
        'usta_hakedis': usta.ustaHakedis,
        'komisyon_tutari': usta.komisyonTutari,
        'komisyon_orani': 0.15,
        'toplam_tutar': usta.toplamTutar,
        'durum': 'Usta Onayı Bekleniyor',
        'flow_step': 1,
        'payment_provider': 'İyzico Provizyon (Askıda)',
        'payment_status': 'Ön Provizyon Alındı',
        'puan': 0.0,
        'musteri_yorum': '',
        'created_at': dateStr,
        'is_payout_transferred': false,
      });

      state = state.copyWith(
        isCreatingCall: false,
        activeCallId: demoId,
      );
      return demoId;
    }

    try {
      final customerPointWkt =
          'SRID=4326;POINT(${state.currentLng} ${state.currentLat})';

      final insertData = {
        'musteri_id': customerId,
        'usta_id': usta.ustaId,
        'musteri_konum': customerPointWkt,
        'adres_tarifi': adresTarifi.trim().isNotEmpty
            ? adresTarifi.trim()
            : state.currentAddressLabel,
        'durum': 'bekliyor',
        'usta_hakedis': usta.ustaHakedis,
        'komisyon_tutari': usta.komisyonTutari,
        'toplam_tutar': usta.toplamTutar,
      };

      final response = await _supabase
          .from('cagrilar')
          .insert(insertData)
          .select('id')
          .single();

      final cagriId = response['id'] as String;

      state = state.copyWith(
        isCreatingCall: false,
        activeCallId: cagriId,
      );

      return cagriId;
    } catch (e) {
      debugPrint('createCagri hatası: $e');
      state = state.copyWith(
        isCreatingCall: false,
        errorMessage: 'Çağrı oluşturulamadı: $e',
      );
      return null;
    }
  }
}
