import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/core/services/location_service.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';

class CustomerMapState {
  final double currentLat;
  final double currentLng;
  final String currentAddressLabel;
  final String selectedCategory; // 'elektrik', 'cilingir', 'tesisat'
  final int searchRadiusMeter; // varsayılan 10000 metre (10km)
  final List<NearbyUstaModel> nearbyUstalar;
  final NearbyUstaModel? selectedUsta;
  final bool isLoadingLocation;
  final bool isLoadingUstalar;
  final bool isCreatingCall;
  final String? activeCallId;
  final String? errorMessage;

  const CustomerMapState({
    this.currentLat = 40.9905, // Varsayılan Kadıköy, İstanbul
    this.currentLng = 29.0270,
    this.currentAddressLabel = 'Kadıköy, İstanbul',
    this.selectedCategory = 'elektrik',
    this.searchRadiusMeter = 10000,
    this.nearbyUstalar = const [],
    this.selectedUsta,
    this.isLoadingLocation = false,
    this.isLoadingUstalar = false,
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
    bool? isLoadingLocation,
    bool? isLoadingUstalar,
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
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
      isLoadingUstalar: isLoadingUstalar ?? this.isLoadingUstalar,
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
  return CustomerMapController(supabase, locationService);
});

class CustomerMapController extends StateNotifier<CustomerMapState> {
  final SupabaseClient _supabase;
  final LocationService _locationService;

  CustomerMapController(this._supabase, this._locationService)
      : super(const CustomerMapState()) {
    initCustomerLocationAndSearch();
  }

  /// Müşteri konumunu alır ve yakındaki ustaları otomatik arar
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
    await fetchNearbyUstalar();
  }

  /// PostGIS RPC fonksiyonu `yakin_ustalari_getir` ile çevredeki online ustaları çeker
  Future<void> fetchNearbyUstalar() async {
    state = state.copyWith(isLoadingUstalar: true, errorMessage: null);

    try {
      final response = await _supabase.rpc('yakin_ustalari_getir', params: {
        'p_lat': state.currentLat,
        'p_lng': state.currentLng,
        'p_kategori': state.selectedCategory,
        'p_radius_meter': state.searchRadiusMeter,
      }).timeout(const Duration(seconds: 4));
      if (!mounted) return;

      final List<dynamic> data = response as List<dynamic>? ?? [];
      List<NearbyUstaModel> ustalar = data
          .map((item) => NearbyUstaModel.fromJson(item as Map<String, dynamic>))
          .toList();

      if (ustalar.isEmpty) {
        ustalar = _getDemoUstalar();
      }

      state = state.copyWith(
        isLoadingUstalar: false,
        nearbyUstalar: ustalar,
        clearSelectedUsta: true,
      );
    } catch (e) {
      debugPrint('fetchNearbyUstalar hatası (demo verileri yükleniyor): $e');
      if (!mounted) return;
      final demoList = _getDemoUstalar();
      state = state.copyWith(
        isLoadingUstalar: false,
        nearbyUstalar: demoList,
        clearSelectedUsta: true,
        errorMessage: null,
      );
    }
  }

  List<NearbyUstaModel> _getDemoUstalar() {
    final lat = state.currentLat;
    final lng = state.currentLng;
    final cat = state.selectedCategory;

    return [
      NearbyUstaModel(
        ustaId: 'demo-usta-1',
        fullName: cat == 'elektrik'
            ? 'Ahmet Yılmaz'
            : (cat == 'tesisat' ? 'Murat Kaya' : 'Kemal Demir'),
        phone: '+90 532 111 22 33',
        kategori: cat,
        puan: 4.9,
        tamamlananIsSayisi: 142,
        latitude: lat + 0.0042,
        longitude: lng + 0.0034,
        mesafeMetre: 850,
        ustaHakedis: 800.0,
        komisyonOrani: 0.15,
        komisyonTutari: 120.0,
        toplamTutar: 920.0,
      ),
      NearbyUstaModel(
        ustaId: 'demo-usta-2',
        fullName: cat == 'elektrik'
            ? 'Hasan Çelik'
            : (cat == 'tesisat' ? 'Selim Arslan' : 'Oğuz Şahin'),
        phone: '+90 544 222 33 44',
        kategori: cat,
        puan: 4.8,
        tamamlananIsSayisi: 96,
        latitude: lat - 0.0052,
        longitude: lng - 0.0041,
        mesafeMetre: 1400,
        ustaHakedis: 650.0,
        komisyonOrani: 0.15,
        komisyonTutari: 97.5,
        toplamTutar: 747.5,
      ),
      NearbyUstaModel(
        ustaId: 'demo-usta-3',
        fullName: cat == 'elektrik'
            ? 'Serkan Yıldız'
            : (cat == 'tesisat' ? 'Burak Aydın' : 'İsmail Koç'),
        phone: '+90 555 333 44 55',
        kategori: cat,
        puan: 5.0,
        tamamlananIsSayisi: 215,
        latitude: lat + 0.0068,
        longitude: lng - 0.0058,
        mesafeMetre: 2400,
        ustaHakedis: 550.0,
        komisyonOrani: 0.15,
        komisyonTutari: 82.5,
        toplamTutar: 632.5,
      ),
    ];
  }

  static const Map<String, ({double lat, double lng, String label})>
      _knownLocations = {
    'kadikoy, istanbul': (lat: 40.9905, lng: 29.0270, label: 'Kadıköy, İstanbul'),
    'kadikoy': (lat: 40.9905, lng: 29.0270, label: 'Kadıköy, İstanbul'),
    'besiktas, istanbul': (lat: 41.0430, lng: 29.0072, label: 'Beşiktaş, İstanbul'),
    'besiktas': (lat: 41.0430, lng: 29.0072, label: 'Beşiktaş, İstanbul'),
    'uskudar, istanbul': (lat: 41.0233, lng: 29.0153, label: 'Üsküdar, İstanbul'),
    'sisli, istanbul': (lat: 41.0602, lng: 28.9877, label: 'Şişli, İstanbul'),
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
      isLoadingLocation: false,
    );

    await fetchNearbyUstalar();
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
        isLoadingLocation: false,
      );
      await fetchNearbyUstalar();
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

  /// Kategori değiştirme ('elektrik', 'cilingir', 'tesisat')
  void setCategory(String category) {
    if (state.selectedCategory != category) {
      state = state.copyWith(
        selectedCategory: category,
        clearSelectedUsta: true,
      );
      fetchNearbyUstalar();
    }
  }

  /// Arama yarıçapını değiştirme (metre)
  void setRadius(int meter) {
    if (state.searchRadiusMeter != meter) {
      state = state.copyWith(searchRadiusMeter: meter);
      fetchNearbyUstalar();
    }
  }

  /// Harita veya listeden bir usta seçme
  void selectUsta(NearbyUstaModel usta) {
    state = state.copyWith(selectedUsta: usta);
  }

  /// Usta seçimini kaldırarak özet bara geri dönme
  void clearSelectedUsta() {
    state = state.copyWith(clearSelectedUsta: true);
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
