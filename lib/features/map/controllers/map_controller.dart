import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ustaapp/core/services/location_service.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';

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
      List<NearbyUstaModel> ustalar = data
          .map((item) => NearbyUstaModel.fromJson(item as Map<String, dynamic>))
          .toList();

      if (ustalar.isEmpty) {
        ustalar = _getDemoUstalar();
      }

      state = state.copyWith(
        isLoadingUstalar: false,
        nearbyUstalar: ustalar,
        selectedUsta: ustalar.isNotEmpty ? ustalar.first : null,
      );
    } catch (e) {
      debugPrint('fetchNearbyUstalar hatası (demo verileri yükleniyor): $e');
      final demoList = _getDemoUstalar();
      state = state.copyWith(
        isLoadingUstalar: false,
        nearbyUstalar: demoList,
        selectedUsta: demoList.isNotEmpty ? demoList.first : null,
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
            ? 'Hasan Usta (Elektrik)'
            : (cat == 'tesisat' ? 'Murat Usta (Sıhhi Tesisat)' : 'Kemal Usta (Çilingir)'),
        phone: '+90 532 111 22 33',
        kategori: cat,
        puan: 4.9,
        latitude: lat + 0.0045,
        longitude: lng + 0.0035,
        mesafeMetre: 620,
        ustaHakedis: 650.0,
        komisyonOrani: 0.15,
        komisyonTutari: 97.5,
        toplamTutar: 747.5,
      ),
      NearbyUstaModel(
        ustaId: 'demo-usta-2',
        fullName: cat == 'elektrik'
            ? 'Ahmet Usta (Akıllı Ev & Priz)'
            : (cat == 'tesisat' ? 'Selim Usta (Su Kaçağı & Tıkanıklık)' : 'Oğuz Usta (Oto & Kasa Çilingir)'),
        phone: '+90 544 222 33 44',
        kategori: cat,
        puan: 4.8,
        latitude: lat - 0.0055,
        longitude: lng - 0.0040,
        mesafeMetre: 1100,
        ustaHakedis: 800.0,
        komisyonOrani: 0.15,
        komisyonTutari: 120.0,
        toplamTutar: 920.0,
      ),
      NearbyUstaModel(
        ustaId: 'demo-usta-3',
        fullName: cat == 'elektrik'
            ? 'Serkan Usta (Sigorta & Avize)'
            : (cat == 'tesisat' ? 'Burak Usta (Kombi & Petek)' : 'İsmail Usta (Kapı Açma)'),
        phone: '+90 555 333 44 55',
        kategori: cat,
        puan: 5.0,
        latitude: lat + 0.0070,
        longitude: lng - 0.0065,
        mesafeMetre: 1650,
        ustaHakedis: 550.0,
        komisyonOrani: 0.15,
        komisyonTutari: 82.5,
        toplamTutar: 632.5,
      ),
    ];
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
            : 'Kadıköy Merkez Mah. Moda Cad. No:42 Daire:5',
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
