import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ustaapp/core/services/location_service.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';

class CustomerMapState {
  final double currentLat;
  final double currentLng;
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
    this.currentLat = 41.0082, // Varsayılan İstanbul
    this.currentLng = 28.9784,
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
    String? selectedCategory,
    int? searchRadiusMeter,
    List<NearbyUstaModel>? nearbyUstalar,
    NearbyUstaModel? selectedUsta,
    bool? isLoadingLocation,
    bool? isLoadingUstalar,
    bool? isCreatingCall,
    String? activeCallId,
    String? errorMessage,
  }) {
    return CustomerMapState(
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchRadiusMeter: searchRadiusMeter ?? this.searchRadiusMeter,
      nearbyUstalar: nearbyUstalar ?? this.nearbyUstalar,
      selectedUsta: selectedUsta ?? this.selectedUsta,
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
      if (hasPermission) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
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
      state = state.copyWith(isLoadingLocation: false);
    }

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
      });

      final List<dynamic> data = response as List<dynamic>? ?? [];
      final ustalar = data
          .map((item) => NearbyUstaModel.fromJson(item as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        isLoadingUstalar: false,
        nearbyUstalar: ustalar,
        selectedUsta: ustalar.isNotEmpty ? ustalar.first : null,
      );
    } catch (e) {
      debugPrint('fetchNearbyUstalar hatası: $e');
      state = state.copyWith(
        isLoadingUstalar: false,
        errorMessage: 'Yakındaki ustalar listelenirken hata oluştu: $e',
      );
    }
  }

  /// Kategori değiştirme ('elektrik', 'cilingir', 'tesisat')
  void setCategory(String category) {
    if (state.selectedCategory != category) {
      state = state.copyWith(selectedCategory: category, selectedUsta: null);
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

  /// Seçili ustaya doğrudan çağrı oluşturma (durum: 'bekliyor')
  Future<String?> createCagri({
    required NearbyUstaModel usta,
    required String adresTarifi,
  }) async {
    final customerId = _supabase.auth.currentUser?.id;
    if (customerId == null) {
      state = state.copyWith(errorMessage: 'Lütfen çağrı açmak için giriş yapın.');
      return null;
    }

    state = state.copyWith(isCreatingCall: true, errorMessage: null);

    try {
      final customerPointWkt =
          'SRID=4326;POINT(${state.currentLng} ${state.currentLat})';

      final insertData = {
        'musteri_id': customerId,
        'usta_id': usta.ustaId,
        'musteri_konum': customerPointWkt,
        'adres_tarifi': adresTarifi.trim(),
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
