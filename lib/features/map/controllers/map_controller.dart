import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/core/services/app_data_service.dart';
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
      }
    });
    initCustomerLocationAndSearch();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
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

  /// PostGIS RPC fonksiyonu `yakin_ustalari_getir` veya Admin Panelinin yönettiği canlı usta verisini çeker
  Future<void> fetchNearbyUstalar() async {
    state = state.copyWith(isLoadingUstalar: true, errorMessage: null);

    List<NearbyUstaModel> ustalar = [];

    try {
      final response = await _supabase.rpc('yakin_ustalari_getir', params: {
        'p_lat': state.currentLat,
        'p_lng': state.currentLng,
        'p_kategori': state.selectedCategory,
        'p_radius_meter': state.searchRadiusMeter,
      }).timeout(const Duration(seconds: 3));

      final List<dynamic> data = response as List<dynamic>? ?? [];
      ustalar = data
          .map((item) => NearbyUstaModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {}

    if (!mounted) return;

    if (ustalar.isEmpty) {
      // Admin Panelinin yönettiği dinamik usta verisini getir
      final managedUstalar = await _appDataService.getNearbyUstalar(
        category: state.selectedCategory,
        customerLat: state.currentLat,
        customerLng: state.currentLng,
      );

      if (managedUstalar.isNotEmpty) {
        ustalar = managedUstalar.map((u) {
          final dist = Geolocator.distanceBetween(
            state.currentLat,
            state.currentLng,
            u.latitude,
            u.longitude,
          );
          return u.copyWith(mesafeMetre: dist > 0 ? dist : u.mesafeMetre);
        }).toList();
      } else {
        ustalar = [];
      }
    }

    if (!mounted) return;

    state = state.copyWith(
      isLoadingUstalar: false,
      nearbyUstalar: ustalar,
      clearSelectedUsta: true,
      errorMessage: null,
    );
  }

  List<NearbyUstaModel> _getDemoUstalar() {
    final lat = state.currentLat;
    final lng = state.currentLng;
    final cat = state.selectedCategory;

    if (cat == 'cilingir') {
      return [
        NearbyUstaModel(
          ustaId: 'demo-cilingir-1',
          fullName: 'Kemal Demir',
          phone: '+90 532 111 22 33',
          kategori: 'cilingir',
          puan: 4.9,
          tamamlananIsSayisi: 174,
          latitude: lat + 0.0042,
          longitude: lng + 0.0034,
          mesafeMetre: 850,
          ustaHakedis: 800.0,
          komisyonOrani: 0.15,
          komisyonTutari: 120.0,
          toplamTutar: 920.0,
          servisUcreti: 200.0,
          deneyimYili: 15,
          uzmanlikBasligi: 'Yetkili Çilingir & Kilit Güvenlik Uzmanı',
          guvenceler: const [
            'Hasarsız Açım Garantisi',
            '30 Gün İşçilik Garantisi',
            'Orijinal Kale / Yale Kilit',
            'MYK Yetki Belgeli',
          ],
          ilanlar: const [
            UstaHizmetIlan(
              id: 'c1-1',
              baslik: 'Çelik Kapı / Kilit Açımı (Hasarsız)',
              aciklama: 'Özel aparatlarla kapı ve kasaya hasar vermeden kilit açımı.',
              fiyat: 800.0,
              tahminiSure: '15-20 dk',
              ikon: '🔑',
              isDefault: true,
            ),
            UstaHizmetIlan(
              id: 'c1-2',
              baslik: 'Barel (Göbek) Değişimi & 3 Anahtar',
              aciklama: 'Yüksek güvenlikli bilyalı barel montajı ve yeni anahtar teslimi.',
              fiyat: 650.0,
              tahminiSure: '20 dk',
              ikon: '🔒',
            ),
            UstaHizmetIlan(
              id: 'c1-3',
              baslik: 'Tuzaklı Zırhlı Barel & Rozet Montajı',
              aciklama: 'Hırsızlığa ve delinmeye karşı zırhlı çelik koruma kiti.',
              fiyat: 950.0,
              tahminiSure: '35 dk',
              ikon: '🛡️',
            ),
            UstaHizmetIlan(
              id: 'c1-4',
              baslik: 'Oto Kapı Açımı (Hasarsız Acil)',
              aciklama: 'Otomobil cam fitili veya kapısına sıfır hasarla açım.',
              fiyat: 1100.0,
              tahminiSure: '20 dk',
              ikon: '🚗',
            ),
          ],
        ),
        NearbyUstaModel(
          ustaId: 'demo-cilingir-2',
          fullName: 'Oğuz Şahin',
          phone: '+90 544 222 33 44',
          kategori: 'cilingir',
          puan: 4.8,
          tamamlananIsSayisi: 112,
          latitude: lat - 0.0052,
          longitude: lng - 0.0041,
          mesafeMetre: 1400,
          ustaHakedis: 650.0,
          komisyonOrani: 0.15,
          komisyonTutari: 97.5,
          toplamTutar: 747.5,
          servisUcreti: 150.0,
          deneyimYili: 10,
          uzmanlikBasligi: 'Acil Çilingir & Kapı Mekanizma Ustası',
          guvenceler: const [
            'Hızlı Varış (~12 dk)',
            'Sabit Fiyat Güvencesi',
            'Faturalı Hizmet',
          ],
          ilanlar: const [
            UstaHizmetIlan(
              id: 'c2-1',
              baslik: 'Acil Kapı Açma Hizmeti',
              aciklama: 'Çekili kapılar için kilidi bozmadan hızlı açım.',
              fiyat: 650.0,
              tahminiSure: '15 dk',
              ikon: '🔑',
              isDefault: true,
            ),
            UstaHizmetIlan(
              id: 'c2-2',
              baslik: 'Barel Değişimi ve Bakımı',
              aciklama: 'Standart kapı bareli değişimi ve mekanizma yağlama.',
              fiyat: 450.0,
              tahminiSure: '20 dk',
              ikon: '🔒',
            ),
            UstaHizmetIlan(
              id: 'c2-3',
              baslik: 'Asma Kilit / Kepenk Kilidi Açımı',
              aciklama: 'Garaj, dükkan kepengi veya depo kilit açımı.',
              fiyat: 400.0,
              tahminiSure: '20 dk',
              ikon: '⛓️',
            ),
          ],
        ),
        NearbyUstaModel(
          ustaId: 'demo-cilingir-3',
          fullName: 'İsmail Koç',
          phone: '+90 555 333 44 55',
          kategori: 'cilingir',
          puan: 5.0,
          tamamlananIsSayisi: 228,
          latitude: lat + 0.0068,
          longitude: lng - 0.0058,
          mesafeMetre: 2400,
          ustaHakedis: 550.0,
          komisyonOrani: 0.15,
          komisyonTutari: 82.5,
          toplamTutar: 632.5,
          servisUcreti: 120.0,
          deneyimYili: 8,
          uzmanlikBasligi: 'Pratik Çilingir & Kilit Bakım Ustası',
          guvenceler: const [
            'Uygun Fiyat Garantisi',
            'İşçilik Garantisi',
            'Temiz İşçilik',
          ],
          ilanlar: const [
            UstaHizmetIlan(
              id: 'c3-1',
              baslik: 'Hızlı Kilit Açımı & Ayar',
              aciklama: 'Sürtünen kapı ayarı ve kilit açımı.',
              fiyat: 550.0,
              tahminiSure: '15 dk',
              ikon: '🔑',
              isDefault: true,
            ),
            UstaHizmetIlan(
              id: 'c3-2',
              baslik: 'Oda / Ahşap Kapı Kilit Tamiri',
              aciklama: 'İç kapı mekanizması onarımı ve kol değişimi.',
              fiyat: 320.0,
              tahminiSure: '20 dk',
              ikon: '🚪',
            ),
          ],
        ),
      ];
    }

    if (cat == 'tesisat') {
      return [
        NearbyUstaModel(
          ustaId: 'demo-tesisat-1',
          fullName: 'Murat Kaya',
          phone: '+90 532 111 22 33',
          kategori: 'tesisat',
          puan: 4.9,
          tamamlananIsSayisi: 189,
          latitude: lat + 0.0042,
          longitude: lng + 0.0034,
          mesafeMetre: 850,
          ustaHakedis: 800.0,
          komisyonOrani: 0.15,
          komisyonTutari: 120.0,
          toplamTutar: 920.0,
          servisUcreti: 200.0,
          deneyimYili: 16,
          uzmanlikBasligi: 'Sıhhi Tesisat & Termal Kaçak Tespiti Uzmanı',
          guvenceler: const [
            'Kırmadan Cihazlı Tespit',
            '30 Gün İşçilik Garantisi',
            'TSE Belgeli Malzeme',
            'Garantili Onarım',
          ],
          ilanlar: const [
            UstaHizmetIlan(
              id: 't1-1',
              baslik: 'Cihazla Kırmadan Su Kaçağı Tespiti',
              aciklama: 'Termal kamera ve akustik frekans dinleme ile noktasal tespit.',
              fiyat: 800.0,
              tahminiSure: '30-45 dk',
              ikon: '🔍',
              isDefault: true,
            ),
            UstaHizmetIlan(
              id: 't1-2',
              baslik: 'Robot Makineyle Tıkanıklık Açma',
              aciklama: 'Spiral çelik robotla banyo, mutfak pimaş gideri açımı.',
              fiyat: 850.0,
              tahminiSure: '40 dk',
              ikon: '🚿',
            ),
            UstaHizmetIlan(
              id: 't1-3',
              baslik: 'Batarya / Musluk Değişimi & Montajı',
              aciklama: 'Aç-kapa lavabo veya eviye bataryası montajı ve sızdırmazlık.',
              fiyat: 400.0,
              tahminiSure: '25 dk',
              ikon: '🚰',
            ),
            UstaHizmetIlan(
              id: 't1-4',
              baslik: 'Gömme Rezervuar / Sifon Tamiri',
              aciklama: 'Klozet su akıtma arızası, şamandıra ve conta yenileme.',
              fiyat: 550.0,
              tahminiSure: '35 dk',
              ikon: '🚽',
            ),
          ],
        ),
        NearbyUstaModel(
          ustaId: 'demo-tesisat-2',
          fullName: 'Selim Arslan',
          phone: '+90 544 222 33 44',
          kategori: 'tesisat',
          puan: 4.8,
          tamamlananIsSayisi: 130,
          latitude: lat - 0.0052,
          longitude: lng - 0.0041,
          mesafeMetre: 1400,
          ustaHakedis: 650.0,
          komisyonOrani: 0.15,
          komisyonTutari: 97.5,
          toplamTutar: 747.5,
          servisUcreti: 150.0,
          deneyimYili: 11,
          uzmanlikBasligi: 'Acil Tesisatçı & Musluk / Gider Ustası',
          guvenceler: const [
            'Hızlı Müdahale',
            'İşçilik Garantisi',
            'Orijinal Parça Garantisi',
          ],
          ilanlar: const [
            UstaHizmetIlan(
              id: 't2-1',
              baslik: 'Acil Tesisat Onarımı & Keşif',
              aciklama: 'Patlayan boru, damlatan vana tespiti ve acil tamir.',
              fiyat: 650.0,
              tahminiSure: '30 dk',
              ikon: '🔧',
              isDefault: true,
            ),
            UstaHizmetIlan(
              id: 't2-2',
              baslik: 'Musluk Tamiri & Salmastra Değişimi',
              aciklama: 'Su damlatan muslukların conta ve salmastra onarımı.',
              fiyat: 320.0,
              tahminiSure: '20 dk',
              ikon: '💧',
            ),
            UstaHizmetIlan(
              id: 't2-3',
              baslik: 'Çamaşır / Bulaşık Makinesi Tesisat Bağlantısı',
              aciklama: 'Temiz su ve atık su hortum bağlantılarının yapılması.',
              fiyat: 350.0,
              tahminiSure: '25 dk',
              ikon: '🧼',
            ),
          ],
        ),
        NearbyUstaModel(
          ustaId: 'demo-tesisat-3',
          fullName: 'Burak Aydın',
          phone: '+90 555 333 44 55',
          kategori: 'tesisat',
          puan: 5.0,
          tamamlananIsSayisi: 245,
          latitude: lat + 0.0068,
          longitude: lng - 0.0058,
          mesafeMetre: 2400,
          ustaHakedis: 550.0,
          komisyonOrani: 0.15,
          komisyonTutari: 82.5,
          toplamTutar: 632.5,
          servisUcreti: 120.0,
          deneyimYili: 9,
          uzmanlikBasligi: 'Pratik Tesisat & Gider Temizleme Ustası',
          guvenceler: const [
            'Ekonomik Fiyat',
            'Hızlı Servis',
            'Müşteri Memnuniyeti',
          ],
          ilanlar: const [
            UstaHizmetIlan(
              id: 't3-1',
              baslik: 'Lavabo / Eviye Gider Temizliği',
              aciklama: 'Tıkanan eviye sifonunun temizlenmesi ve conta yenileme.',
              fiyat: 550.0,
              tahminiSure: '20 dk',
              ikon: '🚿',
              isDefault: true,
            ),
            UstaHizmetIlan(
              id: 't3-2',
              baslik: 'Ara Musluk & Filtreli Vana Değişimi',
              aciklama: 'Kireçlenmiş ara muslukların yenisiyle değiştirilmesi.',
              fiyat: 280.0,
              tahminiSure: '15 dk',
              ikon: '🚰',
            ),
          ],
        ),
      ];
    }

    // Varsayılan 'elektrik' kategorisi
    return [
      NearbyUstaModel(
        ustaId: 'demo-usta-1',
        fullName: 'Ahmet Yılmaz',
        phone: '+90 532 111 22 33',
        kategori: 'elektrik',
        puan: 4.9,
        tamamlananIsSayisi: 142,
        latitude: lat + 0.0042,
        longitude: lng + 0.0034,
        mesafeMetre: 850,
        ustaHakedis: 800.0,
        komisyonOrani: 0.15,
        komisyonTutari: 120.0,
        toplamTutar: 920.0,
        servisUcreti: 200.0,
        deneyimYili: 14,
        uzmanlikBasligi: 'Yetkili Elektrik & Akıllı Ev Teknisyeni',
        guvenceler: const [
          '30 Gün İşçilik Garantisi',
          'Sabit Fiyat Güvencesi',
          'MYK Belgeli',
          'Hızlı Varış',
        ],
        ilanlar: const [
          UstaHizmetIlan(
            id: 'e1-1',
            baslik: 'Temel Arıza Tespiti & Sigorta Kontrolü',
            aciklama: 'Yerinde voltaj ölçümü, arızalı hat izolasyonu ve güvenli onarım.',
            fiyat: 800.0,
            tahminiSure: '30 dk',
            ikon: '⚡',
            isDefault: true,
          ),
          UstaHizmetIlan(
            id: 'e1-2',
            baslik: 'Sigorta Panosu & Kaçak Akım Rölesi Montajı',
            aciklama: 'Eski sigortaların yenilenmesi, yangın ve kaçak koruma rölesi.',
            fiyat: 950.0,
            tahminiSure: '45 dk',
            ikon: '🛡️',
          ),
          UstaHizmetIlan(
            id: 'e1-3',
            baslik: 'Priz / Anahtar Hat Çekimi & Değişimi',
            aciklama: 'Yanmış/kırık prizlerin değişimi veya sıva üstü yeni hat çekimi.',
            fiyat: 400.0,
            tahminiSure: '25 dk',
            ikon: '🔌',
          ),
          UstaHizmetIlan(
            id: 'e1-4',
            baslik: 'Avize & LED Aydınlatma Montajı',
            aciklama: 'Tavana sağlam dübelleme, dimmer ve modern aydınlatma montajı.',
            fiyat: 500.0,
            tahminiSure: '35 dk',
            ikon: '💡',
          ),
          UstaHizmetIlan(
            id: 'e1-5',
            baslik: 'Termosifon / Şofben Elektrik Hattı',
            aciklama: 'Yüksek akım korumalı bağımsız sigortalı kablolama.',
            fiyat: 650.0,
            tahminiSure: '40 dk',
            ikon: '🔥',
          ),
        ],
      ),
      NearbyUstaModel(
        ustaId: 'demo-usta-2',
        fullName: 'Hasan Çelik',
        phone: '+90 544 222 33 44',
        kategori: 'elektrik',
        puan: 4.8,
        tamamlananIsSayisi: 96,
        latitude: lat - 0.0052,
        longitude: lng - 0.0041,
        mesafeMetre: 1400,
        ustaHakedis: 650.0,
        komisyonOrani: 0.15,
        komisyonTutari: 97.5,
        toplamTutar: 747.5,
        servisUcreti: 150.0,
        deneyimYili: 9,
        uzmanlikBasligi: 'Acil Elektrik & Tesisat Tamir Uzmanı',
        guvenceler: const [
          'Aynı Gün Hızlı Servis',
          '30 Gün İşçilik Garantisi',
          'Güvenli Ödeme',
        ],
        ilanlar: const [
          UstaHizmetIlan(
            id: 'e2-1',
            baslik: 'Arıza Tespiti ve Acil Müdahale',
            aciklama: 'Priz, sigorta veya buat arızasının tespiti ve hızlı onarımı.',
            fiyat: 650.0,
            tahminiSure: '25 dk',
            ikon: '⚡',
            isDefault: true,
          ),
          UstaHizmetIlan(
            id: 'e2-2',
            baslik: 'Priz / Buat Tamiri & Değişimi',
            aciklama: 'Kısa devre temizliği ve yeni topraklı priz montajı.',
            fiyat: 350.0,
            tahminiSure: '20 dk',
            ikon: '🔌',
          ),
          UstaHizmetIlan(
            id: 'e2-3',
            baslik: 'LED Şerit & Spot Aydınlatma Kurulumu',
            aciklama: 'Mutfak tezgah üstü veya salon LED trafo bağlantısı.',
            fiyat: 550.0,
            tahminiSure: '40 dk',
            ikon: '💡',
          ),
          UstaHizmetIlan(
            id: 'e2-4',
            baslik: 'Zil & Diafon Arıza Onarımı',
            aciklama: 'Kapı zili trafosu ve diafon ses hattı onarımı.',
            fiyat: 400.0,
            tahminiSure: '30 dk',
            ikon: '🔔',
          ),
        ],
      ),
      NearbyUstaModel(
        ustaId: 'demo-usta-3',
        fullName: 'Serkan Yıldız',
        phone: '+90 555 333 44 55',
        kategori: 'elektrik',
        puan: 5.0,
        tamamlananIsSayisi: 215,
        latitude: lat + 0.0068,
        longitude: lng - 0.0058,
        mesafeMetre: 2400,
        ustaHakedis: 550.0,
        komisyonOrani: 0.15,
        komisyonTutari: 82.5,
        toplamTutar: 632.5,
        servisUcreti: 120.0,
        deneyimYili: 7,
        uzmanlikBasligi: 'Pratik Elektrikçi & Montaj Ustası',
        guvenceler: const [
          'Ekonomik Tarife',
          'Hızlı Servis',
          'Temiz İşçilik',
        ],
        ilanlar: const [
          UstaHizmetIlan(
            id: 'e3-1',
            baslik: 'Hızlı Kontrol & Priz Onarımı',
            aciklama: 'Genel kontrol ve tekli priz/anahtar değişimi.',
            fiyat: 550.0,
            tahminiSure: '20 dk',
            ikon: '🔌',
            isDefault: true,
          ),
          UstaHizmetIlan(
            id: 'e3-2',
            baslik: 'Anahtar & Düğme Yenileme',
            aciklama: 'İkili veya tekli aydınlatma anahtarlarının değiştirilmesi.',
            fiyat: 280.0,
            tahminiSure: '15 dk',
            ikon: '💡',
          ),
          UstaHizmetIlan(
            id: 'e3-3',
            baslik: 'Kablo Kanalı & Hat Düzenleme',
            aciklama: 'Açıkta duran kabloların estetik kanala alınması.',
            fiyat: 420.0,
            tahminiSure: '30 dk',
            ikon: '📏',
          ),
        ],
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
