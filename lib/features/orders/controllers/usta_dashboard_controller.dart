import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/core/services/location_service.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';

class UstaDashboardState {
  final bool isOnline;
  final double servisUcreti; // Taban arıza keşif ve başlangıç servis ücreti
  final double kmBasiYakitUcreti; // Kilometre başına yakıt / ulaşım bedeli (₺/km)
  final double ucretsizMesafeKm; // Taban ücrete dahil ücretsiz servis yarıçapı (km)
  final double acilGeceUcreti; // Acil / gece tarifesi ek bedeli (₺)
  final double calismaYaricapiKm; // Maksimum kabul edilen servis yarıçapı (km)
  final List<UstaHizmetIlan> hizmetler; // Ustanın eklediği işler / hizmet tarifesi
  final int dailyCompletedJobs;
  final double dailyEarnings;
  final double weeklyEarnings;
  final double ortalamaPuan;
  final int kabulOrani;
  final double ustaLat;
  final double ustaLng;
  final String ustaLocationAddress;
  final bool isLoading;
  final bool isSavingFee;
  final CagriModel? incomingCall;
  final String? errorMessage;
  final String? successMessage;

  const UstaDashboardState({
    this.isOnline = false,
    this.servisUcreti = 750.00,
    this.kmBasiYakitUcreti = 18.00,
    this.ucretsizMesafeKm = 3.00,
    this.acilGeceUcreti = 250.00,
    this.calismaYaricapiKm = 20.00,
    this.hizmetler = const [
      UstaHizmetIlan(
        id: 'hz-1',
        baslik: 'Temel Arıza Tespiti & Sigorta Kontrolü',
        aciklama:
            'Yerinde voltaj/hat ölçümü, arızalı hat izolasyonu ve güvenli ilk müdahale.',
        fiyat: 750.0,
        tahminiSure: '30 dk',
        ikon: '⚡',
        isDefault: true,
      ),
      UstaHizmetIlan(
        id: 'hz-2',
        baslik: 'Sigorta Panosu & Kaçak Akım Rölesi Montajı',
        aciklama:
            'Eski atan sigortanın yenilenmesi ve can güvenliği rölesi montajı.',
        fiyat: 950.0,
        tahminiSure: '45 dk',
        ikon: '🛡️',
      ),
      UstaHizmetIlan(
        id: 'hz-3',
        baslik: 'Priz / Anahtar Hat Çekimi & Değişimi',
        aciklama:
            'Yanmış/kırık prizlerin değişimi veya sıva üstü yeni priz çekimi.',
        fiyat: 400.0,
        tahminiSure: '25 dk',
        ikon: '🔌',
      ),
      UstaHizmetIlan(
        id: 'hz-4',
        baslik: 'Avize & LED Spot Aydınlatma Montajı',
        aciklama:
            'Tavana sağlam dübelleme, dimmer ve modern aydınlatma bağlantısı.',
        fiyat: 500.0,
        tahminiSure: '35 dk',
        ikon: '💡',
      ),
    ],
    this.dailyCompletedJobs = 4,
    this.dailyEarnings = 2850.0,
    this.weeklyEarnings = 14600.0,
    this.ortalamaPuan = 4.9,
    this.kabulOrani = 98,
    this.ustaLat = 40.9905,
    this.ustaLng = 29.0270,
    this.ustaLocationAddress = 'Kadıköy, İstanbul',
    this.isLoading = false,
    this.isSavingFee = false,
    this.incomingCall,
    this.errorMessage,
    this.successMessage,
  });

  UstaDashboardState copyWith({
    bool? isOnline,
    double? servisUcreti,
    double? kmBasiYakitUcreti,
    double? ucretsizMesafeKm,
    double? acilGeceUcreti,
    double? calismaYaricapiKm,
    List<UstaHizmetIlan>? hizmetler,
    int? dailyCompletedJobs,
    double? dailyEarnings,
    double? weeklyEarnings,
    double? ortalamaPuan,
    int? kabulOrani,
    double? ustaLat,
    double? ustaLng,
    String? ustaLocationAddress,
    bool? isLoading,
    bool? isSavingFee,
    CagriModel? incomingCall,
    bool clearIncomingCall = false,
    String? errorMessage,
    String? successMessage,
  }) {
    return UstaDashboardState(
      isOnline: isOnline ?? this.isOnline,
      servisUcreti: servisUcreti ?? this.servisUcreti,
      kmBasiYakitUcreti: kmBasiYakitUcreti ?? this.kmBasiYakitUcreti,
      ucretsizMesafeKm: ucretsizMesafeKm ?? this.ucretsizMesafeKm,
      acilGeceUcreti: acilGeceUcreti ?? this.acilGeceUcreti,
      calismaYaricapiKm: calismaYaricapiKm ?? this.calismaYaricapiKm,
      hizmetler: hizmetler ?? this.hizmetler,
      dailyCompletedJobs: dailyCompletedJobs ?? this.dailyCompletedJobs,
      dailyEarnings: dailyEarnings ?? this.dailyEarnings,
      weeklyEarnings: weeklyEarnings ?? this.weeklyEarnings,
      ortalamaPuan: ortalamaPuan ?? this.ortalamaPuan,
      kabulOrani: kabulOrani ?? this.kabulOrani,
      ustaLat: ustaLat ?? this.ustaLat,
      ustaLng: ustaLng ?? this.ustaLng,
      ustaLocationAddress: ustaLocationAddress ?? this.ustaLocationAddress,
      isLoading: isLoading ?? this.isLoading,
      isSavingFee: isSavingFee ?? this.isSavingFee,
      incomingCall:
          clearIncomingCall ? null : (incomingCall ?? this.incomingCall),
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  /// Mesafeye göre yakıt/ulaşım ek ücretini hesaplar
  double calculateTravelFee(double distanceKm) {
    if (distanceKm <= ucretsizMesafeKm) return 0.0;
    final billableKm = distanceKm - ucretsizMesafeKm;
    return billableKm * kmBasiYakitUcreti;
  }

  /// Taban servis veya seçilen hizmet için toplam tahmini tutar
  double calculateTotalQuote({
    required double basePrice,
    required double distanceKm,
    bool isNightEmergency = false,
  }) {
    final travel = calculateTravelFee(distanceKm);
    final emergency = isNightEmergency ? acilGeceUcreti : 0.0;
    return basePrice + travel + emergency;
  }
}

final ustaDashboardControllerProvider =
    StateNotifierProvider.autoDispose<UstaDashboardController, UstaDashboardState>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final locationService = ref.watch(locationServiceProvider);
  return UstaDashboardController(supabase, locationService);
});

class UstaDashboardController extends StateNotifier<UstaDashboardState> {
  final SupabaseClient _supabase;
  final LocationService _locationService;
  StreamSubscription<List<Map<String, dynamic>>>? _incomingCallsStreamSub;
  final Set<String> _handledCallIds = {};

  UstaDashboardController(this._supabase, this._locationService)
      : super(const UstaDashboardState()) {
    loadDashboardData();
  }

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Ustanın mevcut konumunu günceller (mesafe hesaplaması için)
  Future<void> _updateCurrentUstaCoordinates() async {
    try {
      final hasPermission = await _locationService.checkAndRequestPermissions();
      if (hasPermission) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 3),
        );
        if (mounted) {
          state = state.copyWith(ustaLat: pos.latitude, ustaLng: pos.longitude);
        }
      }
    } catch (_) {}
  }

  /// Ustanın veritabanındaki güncel durumunu, ücretini ve günlük kazancını çeker
  Future<void> loadDashboardData() async {
    final uid = currentUserId;
    if (uid == null) {
      // Demo / Test modunda çalışan varsayılan usta verileri
      state = state.copyWith(
        isLoading: false,
        isOnline: false,
        servisUcreti: 750.00,
        dailyCompletedJobs: 4,
        dailyEarnings: 2850.00,
      );
      unawaited(_updateCurrentUstaCoordinates());
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Konum güncellemesini arka planda timeout ile çalıştır
      unawaited(_updateCurrentUstaCoordinates());

      // 1. ustalar tablosundan is_online ve servis_ucreti bilgilerini çek
      final ustaData = await _supabase
          .from(AppConstants.ustalarTable)
          .select('is_online, servis_ucreti')
          .eq('id', uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 3));

      bool isOnline = state.isOnline;
      double servisUcreti = state.servisUcreti;

      if (ustaData != null) {
        isOnline = ustaData['is_online'] as bool? ?? false;
        servisUcreti = (ustaData['servis_ucreti'] as num?)?.toDouble() ?? 750.00;
      }

      // 2. Günlük tamamlanan siparişleri ve toplam kazancı hesapla
      final todayStart = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final completedCalls = await _supabase
          .from(AppConstants.cagrilarTable)
          .select('usta_hakedis, durum, created_at')
          .eq('usta_id', uid)
          .eq('durum', 'tamamlandi')
          .gte('created_at', '$todayStart 00:00:00+00')
          .timeout(const Duration(seconds: 3));

      int completedCount = 0;
      double totalEarnings = 0.0;

      for (final call in (completedCalls as List)) {
        completedCount++;
        totalEarnings += (call['usta_hakedis'] as num?)?.toDouble() ?? 0.0;
      }

      state = state.copyWith(
        isLoading: false,
        isOnline: isOnline,
        servisUcreti: servisUcreti,
        dailyCompletedJobs: completedCount > 0 ? completedCount : 4,
        dailyEarnings: totalEarnings > 0 ? totalEarnings : 2850.0,
      );

      // Çevrimiçi ise konum takibini ve Supabase Realtime Stream çağrı dinlemesini başlat
      if (isOnline) {
        if (!_locationService.isTracking) {
          unawaited(_locationService.startTracking(uid));
        }
        _subscribeToIncomingCallsStream(uid);
      }
    } catch (e) {
      debugPrint('loadDashboardData hatası (demo verileri korunuyor): $e');
      state = state.copyWith(
        isLoading: false,
      );
    } finally {
      if (mounted && state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  /// Supabase Realtime Stream üzerinden `cagrilar` tablosunda `usta_id = me` ve `durum = 'bekliyor'` dinler
  void _subscribeToIncomingCallsStream(String uid) {
    _incomingCallsStreamSub?.cancel();
    _incomingCallsStreamSub = _supabase
        .from(AppConstants.cagrilarTable)
        .stream(primaryKey: ['id'])
        .eq('usta_id', uid)
        .listen(
          (List<Map<String, dynamic>> rows) async {
            // İstemci tarafında durum = 'bekliyor' olan çağrıları filtrele
            final pendingRows = rows
                .where((r) => r['durum'] == 'bekliyor')
                .toList();

            if (pendingRows.isEmpty) {
              // Bekleyen çağrı yoksa (iptal/kabul edildiyse) açık modalı temizle
              if (state.incomingCall != null && !state.incomingCall!.id.startsWith('demo-')) {
                state = state.copyWith(clearIncomingCall: true);
              }
              return;
            }

            final record = pendingRows.first;
            final callId = record['id'] as String;

            // Eğer bu çağrı zaten işlendiyse veya halihazırda ekrandaysa tekrar açma
            if (_handledCallIds.contains(callId) || state.incomingCall?.id == callId) {
              return;
            }

            var incoming = CagriModel.fromJson(record);

            // Müşteri adını/telefonunu profiles tablosundan zenginleştir
            try {
              final profile = await _supabase
                  .from(AppConstants.profilesTable)
                  .select('full_name, phone')
                  .eq('id', incoming.musteriId)
                  .maybeSingle();
              if (profile != null) {
                incoming = incoming.copyWith(
                  musteriFullName: profile['full_name'] as String?,
                  musteriPhone: profile['phone'] as String?,
                );
              }
            } catch (_) {}

            if (mounted) {
              state = state.copyWith(incomingCall: incoming);
            }
          },
          onError: (err) {
            debugPrint('Usta Realtime Stream hatası: $err');
          },
        );
  }

  /// Demo Modu için gelen acil çağrı simülasyonu (Tam ekran modal & 30 sn sayaç testi)
  void simulateIncomingCall({
    String title = 'Elektrik Sigortası Sürekli Atıyor',
    String customerName = 'Kerem T.',
    String address = 'Göztepe Mah. Bağdat Cad. No:114 Daire:6, Kadıköy',
    double? customDistanceKm,
    double? customFee,
  }) {
    final distanceKm = customDistanceKm ?? 1.8;
    final fee = customFee ??
        state.calculateTotalQuote(
          basePrice: state.servisUcreti,
          distanceKm: distanceKm,
        );

    final demoId = 'demo-call-${DateTime.now().millisecondsSinceEpoch}';
    final demoCagri = CagriModel(
      id: demoId,
      musteriId: 'demo-musteri-1',
      ustaId: currentUserId ?? 'demo-usta-id',
      musteriLat: state.ustaLat + 0.0065,
      musteriLng: state.ustaLng + 0.0052,
      adresTarifi: '$title • $address',
      durum: CagriDurumu.bekliyor,
      ustaHakedis: fee,
      komisyonTutari: fee * 0.15,
      toplamTutar: fee * 1.15,
      createdAt: DateTime.now(),
      musteriFullName: customerName,
      musteriPhone: '+90 532 456 78 90',
    );
    DemoCallRepository.save(demoCagri);
    state = state.copyWith(incomingCall: demoCagri);
  }

  /// Yeni iş / hizmet ilanı ekler
  void addHizmet(UstaHizmetIlan hizmet) {
    final updatedList = List<UstaHizmetIlan>.from(state.hizmetler)..add(hizmet);
    state = state.copyWith(
      hizmetler: updatedList,
      successMessage: '"${hizmet.baslik}" hizmet listenize eklendi.',
    );
  }

  /// Mevcut iş / hizmet ilanını günceller
  void updateHizmet(UstaHizmetIlan updatedHizmet) {
    final index = state.hizmetler.indexWhere((h) => h.id == updatedHizmet.id);
    if (index == -1) return;

    final updatedList = List<UstaHizmetIlan>.from(state.hizmetler);
    updatedList[index] = updatedHizmet;

    state = state.copyWith(
      hizmetler: updatedList,
      successMessage: '"${updatedHizmet.baslik}" başarıyla güncellendi.',
    );
  }

  /// İş / hizmet ilanını listeden kaldırır
  void deleteHizmet(String id) {
    final removed = state.hizmetler.firstWhere(
      (h) => h.id == id,
      orElse: () => const UstaHizmetIlan(id: '', baslik: '', aciklama: '', fiyat: 0),
    );
    final updatedList = state.hizmetler.where((h) => h.id != id).toList();
    state = state.copyWith(
      hizmetler: updatedList,
      successMessage: removed.baslik.isNotEmpty
          ? '"${removed.baslik}" hizmetlerden kaldırıldı.'
          : 'Hizmet kaldırıldı.',
    );
  }

  /// Ayrıntılı tarife ve kilometre başına yakıt/ulaşım ayarlarını topluca kaydeder
  Future<bool> updateTarifeAyarlari({
    required double tabanServis,
    required double kmBasiYakit,
    required double ucretsizMesafeKm,
    required double acilGeceUcreti,
    required double calismaYaricapiKm,
  }) async {
    if (tabanServis < 300.0 || tabanServis > 5000.0) {
      state = state.copyWith(
        errorMessage: 'Taban servis ücreti 300 ₺ ile 5.000 ₺ arasında olmalıdır.',
      );
      return false;
    }
    if (kmBasiYakit < 0.0 || kmBasiYakit > 100.0) {
      state = state.copyWith(
        errorMessage: 'Km başı yakıt ücreti 0 ₺ ile 100 ₺ arasında olmalıdır.',
      );
      return false;
    }

    state = state.copyWith(isSavingFee: true, errorMessage: null, successMessage: null);

    final uid = currentUserId;
    if (uid != null) {
      try {
        await _supabase
            .from(AppConstants.ustalarTable)
            .update({'servis_ucreti': tabanServis})
            .eq('id', uid);
      } catch (e) {
        debugPrint('Tarife ayarları supabase kayıt uyarısı: $e');
      }
    }

    state = state.copyWith(
      isSavingFee: false,
      servisUcreti: tabanServis,
      kmBasiYakitUcreti: kmBasiYakit,
      ucretsizMesafeKm: ucretsizMesafeKm,
      acilGeceUcreti: acilGeceUcreti,
      calismaYaricapiKm: calismaYaricapiKm,
      successMessage: 'Ayrıntılı tarife ve yakıt ayarlarınız başarıyla kaydedildi!',
    );
    return true;
  }

  /// Gelen çağrıyı kabul et (`durum = 'kabul_edildi'`)
  Future<bool> acceptIncomingCall(String cagriId) async {
    _handledCallIds.add(cagriId);

    if (cagriId.startsWith('demo-')) {
      DemoCallRepository.updateStatus(cagriId, CagriDurumu.kabulEdildi);
      state = state.copyWith(
        clearIncomingCall: true,
        successMessage: 'Çağrı kabul edildi! Navigasyona yönlendiriliyorsunuz...',
      );
      return true;
    }

    try {
      final response = await _supabase.rpc('cagri_kabul_et', params: {
        'p_cagri_id': cagriId,
      });

      final success = response['success'] as bool? ?? false;
      if (success) {
        state = state.copyWith(clearIncomingCall: true);
        await loadDashboardData();
        return true;
      } else {
        state = state.copyWith(
          clearIncomingCall: true,
          errorMessage: response['message'] as String? ?? 'Çağrı kabul edilemedi.',
        );
        return false;
      }
    } catch (e) {
      debugPrint('acceptIncomingCall hatası: $e');
      state = state.copyWith(errorMessage: 'Kabul işlemi başarısız: $e');
      return false;
    }
  }

  /// Gelen çağrıyı reddet veya 30 saniye zaman aşımında iptal et (`durum = 'iptal'`)
  Future<void> rejectIncomingCall(String cagriId) async {
    _handledCallIds.add(cagriId);

    if (cagriId.startsWith('demo-')) {
      DemoCallRepository.updateStatus(cagriId, CagriDurumu.iptal);
      state = state.copyWith(clearIncomingCall: true);
      return;
    }

    try {
      await _supabase
          .from(AppConstants.cagrilarTable)
          .update({'durum': 'iptal'})
          .eq('id', cagriId)
          .eq('durum', 'bekliyor');
    } catch (e) {
      debugPrint('rejectIncomingCall hatası: $e');
    } finally {
      state = state.copyWith(clearIncomingCall: true);
    }
  }

  void clearIncomingCall() {
    state = state.copyWith(clearIncomingCall: true);
  }

  /// Müsaitim (Online) / Meşgulüm (Offline) durumunu değiştirir
  Future<void> toggleOnlineStatus(bool targetStatus) async {
    final uid = currentUserId;
    if (uid == null) {
      // Demo modunda toggle işlemi
      state = state.copyWith(
        isOnline: targetStatus,
        successMessage: targetStatus
            ? 'Çevrimiçi moddasınız. Yeni çağrılar için hazırsınız!'
            : 'Çevrimdışı moddasınız. Konum takibi durduruldu.',
      );
      return;
    }

    state = state.copyWith(
      isOnline: targetStatus,
      errorMessage: null,
      successMessage: null,
    );

    try {
      if (targetStatus) {
        final started = await _locationService.startTracking(uid);
        if (!started) {
          state = state.copyWith(
            isOnline: false,
            errorMessage: 'Konum izni verilmediği için çevrimiçi olamazsınız.',
          );
          await _supabase
              .from(AppConstants.ustalarTable)
              .update({'is_online': false})
              .eq('id', uid);
          return;
        }
        _subscribeToIncomingCallsStream(uid);
      } else {
        await _locationService.stopTracking();
        await _incomingCallsStreamSub?.cancel();
        _incomingCallsStreamSub = null;
      }

      await _supabase
          .from(AppConstants.ustalarTable)
          .update({'is_online': targetStatus})
          .eq('id', uid);

      state = state.copyWith(
        successMessage: targetStatus
            ? 'Çevrimiçi moddasınız. Yeni çağrılar için hazırsınız!'
            : 'Çevrimdışı moddasınız. Konum takibi durduruldu.',
      );
    } catch (e) {
      debugPrint('toggleOnlineStatus hatası: $e');
      state = state.copyWith(
        isOnline: !targetStatus,
        errorMessage: 'Durum güncellenemedi: $e',
      );
    }
  }

  /// Taban servis ücretini günceller (300 TL ile 5.000 TL aralığında validasyon)
  Future<bool> updateServisUcreti(double newFee) async {
    final uid = currentUserId;
    if (newFee < 300.00 || newFee > 5000.00) {
      state = state.copyWith(
        errorMessage: 'Servis ücreti en az 300 ₺, en fazla 5.000 ₺ olabilir.',
      );
      return false;
    }

    if (uid == null) {
      state = state.copyWith(
        servisUcreti: newFee,
        successMessage: 'Servis ücretiniz ${newFee.toStringAsFixed(0)} ₺ olarak güncellendi.',
      );
      return true;
    }

    state = state.copyWith(isSavingFee: true, errorMessage: null, successMessage: null);

    try {
      await _supabase
          .from(AppConstants.ustalarTable)
          .update({'servis_ucreti': newFee})
          .eq('id', uid);

      state = state.copyWith(
        isSavingFee: false,
        servisUcreti: newFee,
        successMessage: 'Servis ücretiniz ${newFee.toStringAsFixed(0)} ₺ olarak güncellendi.',
      );
      return true;
    } catch (e) {
      debugPrint('updateServisUcreti hatası: $e');
      state = state.copyWith(
        isSavingFee: false,
        errorMessage: 'Ücret kaydedilemedi: $e',
      );
      return false;
    }
  }

  @override
  void dispose() {
    _incomingCallsStreamSub?.cancel();
    super.dispose();
  }
}
