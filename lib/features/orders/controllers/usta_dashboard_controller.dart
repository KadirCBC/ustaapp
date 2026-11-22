import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/core/services/app_data_service.dart';
import 'package:ustaapp/core/services/location_lookup_service.dart';
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
  final bool hasCustomTarife; // Ustanın bizzat belirleyip kaydettiği özel tarife var mı
  final List<UstaHizmetIlan> hizmetler; // Ustanın eklediği işler / hizmet tarifesi (Kalıcı ve gerçek)
  final List<CagriModel> pendingCalls; // Bekleyen acil çağrılar
  final int dailyCompletedJobs;
  final double dailyEarnings;
  final double weeklyEarnings;
  final double ortalamaPuan;
  final int kabulOrani;
  final double ustaLat;
  final double ustaLng;
  final String ustaLocationAddress;
  final String? activeUstaName;
  final String? activeUstaPhone;
  final String? activeUstaId;
  final bool isLoading;
  final bool isSavingFee;
  final CagriModel? incomingCall;
  final String? errorMessage;
  final String? successMessage;

  const UstaDashboardState({
    this.isOnline = true,
    this.servisUcreti = 0.0,
    this.kmBasiYakitUcreti = 0.0,
    this.ucretsizMesafeKm = 0.0,
    this.acilGeceUcreti = 0.0,
    this.calismaYaricapiKm = 20.00,
    this.hasCustomTarife = false,
    this.hizmetler = const [],
    this.pendingCalls = const [],
    this.dailyCompletedJobs = 0,
    this.dailyEarnings = 0.0,
    this.weeklyEarnings = 0.0,
    this.ortalamaPuan = 5.0,
    this.kabulOrani = 100,
    this.ustaLat = 38.4647,
    this.ustaLng = 30.2719,
    this.ustaLocationAddress = 'Sandıklı, Afyonkarahisar',
    this.activeUstaName,
    this.activeUstaPhone,
    this.activeUstaId,
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
    bool? hasCustomTarife,
    List<UstaHizmetIlan>? hizmetler,
    List<CagriModel>? pendingCalls,
    int? dailyCompletedJobs,
    double? dailyEarnings,
    double? weeklyEarnings,
    double? ortalamaPuan,
    int? kabulOrani,
    double? ustaLat,
    double? ustaLng,
    String? ustaLocationAddress,
    String? activeUstaName,
    String? activeUstaPhone,
    String? activeUstaId,
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
      hasCustomTarife: hasCustomTarife ?? this.hasCustomTarife,
      hizmetler: hizmetler ?? this.hizmetler,
      pendingCalls: pendingCalls ?? this.pendingCalls,
      dailyCompletedJobs: dailyCompletedJobs ?? this.dailyCompletedJobs,
      dailyEarnings: dailyEarnings ?? this.dailyEarnings,
      weeklyEarnings: weeklyEarnings ?? this.weeklyEarnings,
      ortalamaPuan: ortalamaPuan ?? this.ortalamaPuan,
      kabulOrani: kabulOrani ?? this.kabulOrani,
      ustaLat: ustaLat ?? this.ustaLat,
      ustaLng: ustaLng ?? this.ustaLng,
      ustaLocationAddress: ustaLocationAddress ?? this.ustaLocationAddress,
      activeUstaName: activeUstaName ?? this.activeUstaName,
      activeUstaPhone: activeUstaPhone ?? this.activeUstaPhone,
      activeUstaId: activeUstaId ?? this.activeUstaId,
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
  final appDataService = ref.watch(appDataServiceProvider);
  return UstaDashboardController(supabase, locationService, appDataService);
});

class UstaDashboardController extends StateNotifier<UstaDashboardState> {
  final SupabaseClient _supabase;
  final LocationService _locationService;
  final AppDataService _appDataService;
  StreamSubscription<List<Map<String, dynamic>>>? _incomingCallsStreamSub;
  StreamSubscription<void>? _appDataSubscription;
  final Set<String> _handledCallIds = {};

  UstaDashboardController(
    this._supabase,
    this._locationService,
    this._appDataService,
  ) : super(const UstaDashboardState()) {
    _appDataSubscription = _appDataService.onDataChanged.listen((_) {
      _checkIncomingCallsFromSyncService();
      loadDashboardData(forceRefresh: true, isBackground: true);
    });
    loadDashboardData(forceRefresh: true);
  }

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Ustanın mevcut konumunu günceller ve ters jeokodlama ile canlı adresini belirler
  Future<void> _updateCurrentUstaCoordinates() async {
    try {
      final hasPermission = await _locationService.checkAndRequestPermissions();
      if (hasPermission) {
        Position? pos;
        try {
          pos = await Geolocator.getLastKnownPosition();
        } catch (_) {}

        try {
          final fresh = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 8),
          );
          pos = fresh;
        } catch (_) {}

        if (pos != null && mounted) {
          final match = await LocationLookupService.reverseGeocode(pos.latitude, pos.longitude);
          final label = match.shortLabel.isNotEmpty ? match.shortLabel : match.label;
          if (mounted) {
            state = state.copyWith(
              ustaLat: pos.latitude,
              ustaLng: pos.longitude,
              ustaLocationAddress: label.isNotEmpty ? label : state.ustaLocationAddress,
            );
          }
        }
      }
    } catch (_) {}
  }

  /// Ustanın anlık GPS konumunu alarak profilini ve hizmet konumunu %100 günceller
  Future<bool> useCurrentGpsLocation() async {
    state = state.copyWith(isLoading: true);
    try {
      final hasPermission = await _locationService.checkAndRequestPermissions();
      if (!hasPermission) {
        state = state.copyWith(isLoading: false);
        return false;
      }

      Position? pos;
      try {
        pos = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      try {
        final fresh = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
        pos = fresh;
      } catch (_) {}

      if (pos == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }

      final match = await LocationLookupService.reverseGeocode(pos.latitude, pos.longitude);
      final label = match.shortLabel.isNotEmpty ? match.shortLabel : match.label;

      await setUstaLocation(
        address: label.isNotEmpty ? label : '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}',
        lat: pos.latitude,
        lng: pos.longitude,
      );
      state = state.copyWith(
        ustaLat: pos.latitude,
        ustaLng: pos.longitude,
        isLoading: false,
      );

      if (state.isOnline) {
        final uid = currentUserId ?? state.activeUstaId ?? 'usta-default';
        await _locationService.syncLocationDirect(uid, pos.latitude, pos.longitude);
      }
      return true;
    } catch (e) {
      debugPrint('Usta GPS konumu alma hatası: $e');
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  static DateTime? _parseTxDate(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    final iso = DateTime.tryParse(str);
    if (iso != null) return iso;
    try {
      final parts = str.split('•');
      final datePart = parts[0].trim();
      final dmy = datePart.split('.');
      if (dmy.length == 3) {
        final day = int.parse(dmy[0]);
        final month = int.parse(dmy[1]);
        final year = int.parse(dmy[2]);
        int hour = 0;
        int minute = 0;
        if (parts.length > 1) {
          final timePart = parts[1].trim().split(':');
          if (timePart.length >= 2) {
            hour = int.tryParse(timePart[0]) ?? 0;
            minute = int.tryParse(timePart[1]) ?? 0;
          }
        }
        return DateTime(year, month, day, hour, minute);
      }
    } catch (_) {}
    return null;
  }

  /// Ustanın veritabanındaki ve yerel oturumundaki güncel durumunu, kalıcı hizmetlerini ve gerçek kazancını çeker
  Future<void> loadDashboardData({bool forceRefresh = false, bool isBackground = false}) async {
    if (!isBackground) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

    try {
      unawaited(_updateCurrentUstaCoordinates());

      // 1. Aktif oturumu AppDataService'den al
      final session = await _appDataService.getActiveSession();
      final sessionPhone = session?['phone'] as String? ?? '';
      final sessionFullName = session?['full_name'] as String? ?? '';
      final normPhone = AppDataService.normalizePhone(sessionPhone);
      final uid = currentUserId;

      // 2. Ustalar listesinden / AppDataService'den ustayı bul
      final ustalar = await _appDataService.getUstalar();
      NearbyUstaModel? matchedUsta;

      if (normPhone.isNotEmpty) {
        matchedUsta = ustalar.cast<NearbyUstaModel?>().firstWhere(
          (u) => u != null && AppDataService.normalizePhone(u.phone) == normPhone,
          orElse: () => null,
        );
      }
      if (matchedUsta == null && uid != null) {
        matchedUsta = ustalar.cast<NearbyUstaModel?>().firstWhere(
          (u) => u != null && u.ustaId == uid,
          orElse: () => null,
        );
      }

      // Silinen usta kontrolü
      if (normPhone.isNotEmpty && await _appDataService.isUstaDeleted(normPhone)) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Hesabınız yönetici tarafından silinmiştir.',
        );
        return;
      }

      // 3. Kalıcı ve gerçek hizmet ilanlarını yükle
      List<UstaHizmetIlan> realHizmetler = [];
      if (normPhone.isNotEmpty) {
        realHizmetler = await _appDataService.getUstaHizmetleri(normPhone);
      } else if (matchedUsta != null) {
        realHizmetler = List<UstaHizmetIlan>.from(matchedUsta.ilanlar);
      }

      // 4. Gerçek İstatistikleri Hesapla (Hem cagrilar hem financial_transactions)
      final cagrilar = await _appDataService.getCagrilar(forceRefresh: forceRefresh);
      final transactions = await _appDataService.getFinancialTransactions(forceRefresh: forceRefresh);

      final ustaCalls = cagrilar.where((c) {
        final cPhone = AppDataService.normalizePhone(c.ustaPhone ?? '');
        final cUstaId = c.ustaId;
        return (normPhone.isNotEmpty && cPhone == normPhone) ||
            (matchedUsta != null &&
                (cUstaId == matchedUsta.ustaId || cUstaId == matchedUsta.phone));
      }).toList();

      final now = DateTime.now();
      int acceptedCalls = 0;
      int rejectedCalls = 0;

      for (final call in ustaCalls) {
        if (call.durum == CagriDurumu.tamamlandi ||
            call.durum == CagriDurumu.kabulEdildi ||
            call.durum == CagriDurumu.yolda ||
            call.durum == CagriDurumu.adreste) {
          acceptedCalls++;
        } else if (call.durum == CagriDurumu.iptal) {
          rejectedCalls++;
        }
      }

      // Tamamlanan işleri ve hakedişleri cagri_id bazında tekilleştirerek hesapla
      final Map<String, double> completedEarningsMap = {};
      final Map<String, DateTime> completedDateMap = {};

      // 1. Cagrilar'dan tamamlananlar
      for (final call in ustaCalls) {
        if (call.durum == CagriDurumu.tamamlandi) {
          final hakedis = call.ustaHakedis ?? 0.0;
          completedEarningsMap[call.id] = hakedis;
          completedDateMap[call.id] = call.createdAt;
        }
      }

      // 2. FinancialTransactions'dan tamamlananlar (provizyon kapandı / hakediş aktarıldı)
      for (final tx in transactions) {
        final txPhone = AppDataService.normalizePhone((tx['usta_tel'] ?? '').toString());
        final isMyTx = (normPhone.isNotEmpty && txPhone == normPhone) ||
            (matchedUsta != null && (tx['usta_id'] == matchedUsta.ustaId || tx['usta_tel'] == matchedUsta.phone));
        if (isMyTx) {
          final isCompleted = tx['is_payout_transferred'] == true ||
              (tx['durum'] ?? '').toString().toLowerCase().contains('tamamlan');
          if (isCompleted) {
            final cagriId = (tx['cagri_id'] ?? tx['id'] ?? '').toString();
            final hakedis = (tx['usta_hakedis'] as num?)?.toDouble() ?? 0.0;
            if (hakedis > 0) {
              completedEarningsMap[cagriId] = hakedis;
              if (!completedDateMap.containsKey(cagriId)) {
                completedDateMap[cagriId] = _parseTxDate(tx['created_at']) ?? now;
              }
            }
          }
        }
      }

      int completedToday = 0;
      double dailyEarnings = 0.0;
      double weeklyEarnings = 0.0;

      for (final entry in completedEarningsMap.entries) {
        final cagriId = entry.key;
        final hakedis = entry.value;
        final date = completedDateMap[cagriId] ?? now;

        final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
        final diffDays = now.difference(date).inDays;
        final isThisWeek = diffDays >= 0 && diffDays <= 7;

        if (isToday) {
          completedToday++;
          dailyEarnings += hakedis;
        }
        if (isThisWeek) {
          weeklyEarnings += hakedis;
        }
      }

      final totalProcessed = acceptedCalls + rejectedCalls;
      final int realKabulOrani = totalProcessed > 0
          ? ((acceptedCalls / totalProcessed) * 100).round()
          : 100;
      final double realPuan = (matchedUsta != null && matchedUsta.tamamlananIsSayisi > 0)
          ? matchedUsta.puan
          : 5.0;

      // Bekleyen çağrılar listesi
      final pendingCalls = cagrilar
          .where((c) => c.durum == CagriDurumu.bekliyor)
          .toList();

      // 3. Kalıcı tarife ayarlarını getir
      final savedTarife = await _appDataService.getUstaTarife(normPhone.isNotEmpty ? normPhone : (uid ?? 'default'));
      final bool hasSaved = savedTarife != null;
      final double resolvedServisUcreti = hasSaved
          ? (savedTarife['taban_servis'] ?? 0.0)
          : ((matchedUsta != null && matchedUsta.hasCustomTarife && matchedUsta.servisUcreti > 0)
              ? matchedUsta.servisUcreti
              : 0.0);
      final double resolvedKmBasiYakit = hasSaved
          ? (savedTarife['km_basi_yakit'] ?? 0.0)
          : ((matchedUsta != null && matchedUsta.hasCustomTarife)
              ? matchedUsta.kmBasiYakitUcreti
              : 0.0);
      final double resolvedUcretsizKm = hasSaved
          ? (savedTarife['ucretsiz_mesafe_km'] ?? 0.0)
          : ((matchedUsta != null && matchedUsta.hasCustomTarife)
              ? matchedUsta.ucretsizMesafeKm
              : 0.0);
      final double resolvedAcilGece = hasSaved
          ? (savedTarife['acil_gece_ucreti'] ?? 0.0)
          : ((matchedUsta != null && matchedUsta.hasCustomTarife)
              ? matchedUsta.acilGeceUcreti
              : 0.0);
      final double resolvedCalismaYaricap = hasSaved
          ? (savedTarife['calisma_yaricapi_km'] ?? 20.0)
          : ((matchedUsta != null && matchedUsta.hasCustomTarife && matchedUsta.calismaYaricapiKm > 0)
              ? matchedUsta.calismaYaricapiKm
              : 20.0);

      final double finalServisUcreti = resolvedServisUcreti;

      // Kalıcı çevrimiçi/çevrimdışı (müsait/meşgul) tercihi kontrolü
      bool isOnline = state.isOnline;
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedPref = (normPhone.isNotEmpty)
            ? (prefs.getBool('usta_is_online_$normPhone') ?? prefs.getBool('usta_is_online'))
            : prefs.getBool('usta_is_online');
        if (savedPref != null) {
          isOnline = savedPref;
        } else if (matchedUsta != null) {
          isOnline = matchedUsta.isOnline;
        } else if (session != null && (session['is_online'] != null || session['isOnline'] != null)) {
          isOnline = (session['is_online'] ?? session['isOnline']) as bool? ?? isOnline;
        }
      } catch (_) {}

      // Supabase veritabanı kontrolü (giriş yapılmışsa)
      if (uid != null) {
        try {
          final ustaData = await _supabase
              .from(AppConstants.ustalarTable)
              .select('is_online, servis_ucreti')
              .eq('id', uid)
              .maybeSingle()
              .timeout(const Duration(seconds: 2));
          if (ustaData != null && ustaData['is_online'] != null) {
            isOnline = ustaData['is_online'] as bool;
          }
        } catch (_) {}
      }

      final resolvedAddress = (matchedUsta?.uzmanlikBasligi != null && matchedUsta!.uzmanlikBasligi.isNotEmpty)
          ? matchedUsta.uzmanlikBasligi
          : (session?['address'] ?? session?['city_district'] ?? state.ustaLocationAddress);
      final resolvedLat = (matchedUsta != null && matchedUsta.latitude != 0.0)
          ? matchedUsta.latitude
          : state.ustaLat;
      final resolvedLng = (matchedUsta != null && matchedUsta.longitude != 0.0)
          ? matchedUsta.longitude
          : state.ustaLng;

      // Ustanın hizmetlerinin konumunu da canlı yayın konumuyla eşitle
      final syncedHizmetler = realHizmetler.map((h) {
        if (h.konum == null || h.konum!.isEmpty || h.konum != resolvedAddress) {
          return h.copyWith(konum: resolvedAddress, lat: resolvedLat, lng: resolvedLng);
        }
        return h;
      }).toList();

      state = state.copyWith(
        isLoading: false,
        hasCustomTarife: hasSaved || (matchedUsta != null && matchedUsta.hasCustomTarife),
        isOnline: isOnline,
        servisUcreti: finalServisUcreti,
        kmBasiYakitUcreti: resolvedKmBasiYakit,
        ucretsizMesafeKm: resolvedUcretsizKm,
        acilGeceUcreti: resolvedAcilGece,
        calismaYaricapiKm: resolvedCalismaYaricap,
        hizmetler: syncedHizmetler,
        pendingCalls: pendingCalls,
        dailyCompletedJobs: completedToday,
        dailyEarnings: dailyEarnings,
        weeklyEarnings: weeklyEarnings,
        ortalamaPuan: realPuan,
        kabulOrani: realKabulOrani,
        activeUstaId: matchedUsta?.ustaId ?? (normPhone.isNotEmpty ? 'usta-$normPhone' : 'usta-default'),
        activeUstaName: matchedUsta?.fullName ?? (sessionFullName.isNotEmpty ? sessionFullName : 'Usta'),
        activeUstaPhone: normPhone,
        ustaLocationAddress: resolvedAddress,
        ustaLat: resolvedLat,
        ustaLng: resolvedLng,
      );

      // Supabase Realtime Stream dinlemesini başlat
      if (uid != null && isOnline) {
        if (!_locationService.isTracking) {
          unawaited(_locationService.startTracking(uid));
        }
        _subscribeToIncomingCallsStream(uid);
      }
      unawaited(_checkIncomingCallsFromSyncService());
    } catch (e) {
      debugPrint('loadDashboardData hatası: $e');
      state = state.copyWith(isLoading: false);
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
            final pendingRows = rows
                .where((r) => r['durum'] == 'bekliyor')
                .toList();

            if (pendingRows.isEmpty) {
              if (state.incomingCall != null && !state.incomingCall!.id.startsWith('demo-')) {
                state = state.copyWith(clearIncomingCall: true);
              }
              return;
            }

            final record = pendingRows.first;
            final callId = record['id'] as String;

            if (_handledCallIds.contains(callId) || state.incomingCall?.id == callId) {
              return;
            }

            var incoming = CagriModel.fromJson(record);

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

  /// Gelen acil çağrı simülasyonu (Tam ekran modal & canlı sayaç testi)
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
      ustaId: state.activeUstaId ?? currentUserId ?? 'demo-usta-id',
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
    _appDataService.saveOrUpdateCagri(demoCagri);
    DemoCallRepository.save(demoCagri);
    state = state.copyWith(
      incomingCall: demoCagri,
      pendingCalls: [demoCagri, ...state.pendingCalls.where((c) => c.id != demoId)],
    );
  }

  /// Ustanın çalışma bölgesini / ilçesini ve koordinatlarını günceller
  Future<bool> setUstaLocation({
    required String address,
    double? lat,
    double? lng,
  }) async {
    final cleanAddr = address.trim();
    if (cleanAddr.isEmpty) return false;

    double resolvedLat = lat ?? state.ustaLat;
    double resolvedLng = lng ?? state.ustaLng;
    String resolvedAddress = cleanAddr;

    if (lat == null || lng == null) {
      final match = await LocationLookupService.resolveBestMatch(cleanAddr);
      if (match != null) {
        resolvedLat = match.lat;
        resolvedLng = match.lng;
        resolvedAddress = match.label;
      }
    }

    final updatedHizmetler = state.hizmetler.map((h) {
      return h.copyWith(
        konum: resolvedAddress,
        lat: resolvedLat,
        lng: resolvedLng,
      );
    }).toList();

    state = state.copyWith(
      ustaLocationAddress: resolvedAddress,
      ustaLat: resolvedLat,
      ustaLng: resolvedLng,
      hizmetler: updatedHizmetler,
      successMessage: 'Çalışma bölgeniz "$resolvedAddress" olarak güncellendi.',
    );

    final normPhone = AppDataService.normalizePhone(state.activeUstaPhone ?? '');
    final ustaId = state.activeUstaId ?? (normPhone.isNotEmpty ? 'usta-$normPhone' : 'usta-default');

    if (normPhone.isNotEmpty) {
      await _appDataService.saveUstaHizmetleri(normPhone, updatedHizmetler);
    }

    await _appDataService.updateUstaLocation(
      ustaId: ustaId,
      phone: normPhone,
      address: resolvedAddress,
      lat: resolvedLat,
      lng: resolvedLng,
    );

    return true;
  }

  /// Yeni iş / hizmet ilanı ekler ve kalıcı olarak kaydeder
  Future<void> addHizmet(UstaHizmetIlan hizmet) async {
    final updatedList = List<UstaHizmetIlan>.from(state.hizmetler)..add(hizmet);
    state = state.copyWith(
      hizmetler: updatedList,
      successMessage: '"${hizmet.baslik}" hizmet listenize eklendi.',
    );

    final normPhone = AppDataService.normalizePhone(state.activeUstaPhone ?? '');
    final ustaName = state.activeUstaName ?? 'Usta';
    final ustaId = state.activeUstaId ?? (normPhone.isNotEmpty ? 'usta-$normPhone' : 'usta-default');

    // 1. Kalıcı olarak Preferences ve Ustalar modeline kaydet
    if (normPhone.isNotEmpty) {
      await _appDataService.saveUstaHizmetleri(normPhone, updatedList);
    }

    // 2. Harita ve Jobs sistemine senkronize et
    final targetLocation = (hizmet.konum != null && hizmet.konum!.isNotEmpty)
        ? hizmet.konum!
        : state.ustaLocationAddress;
    final targetLat = hizmet.lat ?? state.ustaLat;
    final targetLng = hizmet.lng ?? state.ustaLng;

    await _appDataService.syncUstaHizmetListing(
      hizmet: hizmet,
      ustaName: ustaName,
      ustaPhone: normPhone,
      ustaId: ustaId,
      ustaCategory: (hizmet.kategori != null && hizmet.kategori!.isNotEmpty) ? hizmet.kategori! : hizmet.baslik,
      location: targetLocation,
      lat: targetLat,
      lng: targetLng,
    );
  }

  /// Mevcut iş / hizmet ilanını günceller ve kalıcı olarak kaydeder
  Future<void> updateHizmet(UstaHizmetIlan updatedHizmet) async {
    final index = state.hizmetler.indexWhere((h) => h.id == updatedHizmet.id);
    if (index == -1) return;

    final updatedList = List<UstaHizmetIlan>.from(state.hizmetler);
    updatedList[index] = updatedHizmet;

    state = state.copyWith(
      hizmetler: updatedList,
      successMessage: '"${updatedHizmet.baslik}" başarıyla güncellendi.',
    );

    final normPhone = AppDataService.normalizePhone(state.activeUstaPhone ?? '');
    final ustaName = state.activeUstaName ?? 'Usta';
    final ustaId = state.activeUstaId ?? (normPhone.isNotEmpty ? 'usta-$normPhone' : 'usta-default');

    // 1. Kalıcı kaydet
    if (normPhone.isNotEmpty) {
      await _appDataService.saveUstaHizmetleri(normPhone, updatedList);
    }

    // 2. Harita ve Jobs sistemine senkronize et
    final targetLocation = (updatedHizmet.konum != null && updatedHizmet.konum!.isNotEmpty)
        ? updatedHizmet.konum!
        : state.ustaLocationAddress;
    final targetLat = updatedHizmet.lat ?? state.ustaLat;
    final targetLng = updatedHizmet.lng ?? state.ustaLng;

    await _appDataService.syncUstaHizmetListing(
      hizmet: updatedHizmet,
      ustaName: ustaName,
      ustaPhone: normPhone,
      ustaId: ustaId,
      ustaCategory: (updatedHizmet.kategori != null && updatedHizmet.kategori!.isNotEmpty) ? updatedHizmet.kategori! : updatedHizmet.baslik,
      location: targetLocation,
      lat: targetLat,
      lng: targetLng,
    );
  }

  /// İş / hizmet ilanını listeden kaldırır ve kalıcı depodan siler
  Future<void> deleteHizmet(String id) async {
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

    final normPhone = AppDataService.normalizePhone(state.activeUstaPhone ?? '');

    // 1. Kalıcı olarak güncelle (Preferences + Ustalar Listesi)
    if (normPhone.isNotEmpty) {
      await _appDataService.saveUstaHizmetleri(normPhone, updatedList);
    }

    // 2. Harita ve aktif işlerden kaldır
    await _appDataService.removeUstaHizmetListing(id, ustaPhone: normPhone);
  }

  /// Ayrıntılı tarife ve kilometre başına yakıt/ulaşım ayarlarını topluca kalıcı kaydeder
  Future<bool> updateTarifeAyarlari({
    required double tabanServis,
    required double kmBasiYakit,
    required double ucretsizMesafeKm,
    required double acilGeceUcreti,
    required double calismaYaricapiKm,
  }) async {
    if (tabanServis < 100.0 || tabanServis > 20000.0) {
      state = state.copyWith(
        errorMessage: 'Taban servis ücreti 100 ₺ ile 20.000 ₺ arasında olmalıdır.',
      );
      return false;
    }
    if (kmBasiYakit < 0.0 || kmBasiYakit > 200.0) {
      state = state.copyWith(
        errorMessage: 'Km başı yakıt ücreti 0 ₺ ile 200 ₺ arasında olmalıdır.',
      );
      return false;
    }

    state = state.copyWith(isSavingFee: true, errorMessage: null, successMessage: null);

    final normPhone = AppDataService.normalizePhone(state.activeUstaPhone ?? '');
    final uid = currentUserId;
    final phoneOrId = normPhone.isNotEmpty ? normPhone : (uid ?? 'default');

    // 1. SharedPreferences ve Ustalar listesine %100 kalıcı kaydet
    await _appDataService.saveUstaTarife(
      phoneOrUstaId: phoneOrId,
      tabanServis: tabanServis,
      kmBasiYakit: kmBasiYakit,
      ucretsizMesafeKm: ucretsizMesafeKm,
      acilGeceUcreti: acilGeceUcreti,
      calismaYaricapiKm: calismaYaricapiKm,
    );

    // 2. Supabase hesabı varsa veritabanını da güncelle
    if (uid != null) {
      try {
        await _supabase
            .from(AppConstants.ustalarTable)
            .update({
              'servis_ucreti': tabanServis,
              'km_basi_yakit': kmBasiYakit,
              'ucretsiz_mesafe_km': ucretsizMesafeKm,
              'acil_gece_ucreti': acilGeceUcreti,
              'calisma_yaricapi_km': calismaYaricapiKm,
            })
            .eq('id', uid);
      } catch (e) {
        debugPrint('Tarife ayarları supabase kayıt uyarısı: $e');
      }
    }

    state = state.copyWith(
      isSavingFee: false,
      hasCustomTarife: true,
      servisUcreti: tabanServis,
      kmBasiYakitUcreti: kmBasiYakit,
      ucretsizMesafeKm: ucretsizMesafeKm,
      acilGeceUcreti: acilGeceUcreti,
      calismaYaricapiKm: calismaYaricapiKm,
      successMessage: 'Ayrıntılı tarife ve yakıt ayarlarınız başarıyla kaydedildi!',
    );
    return true;
  }

  /// Sync Server üzerinden gelen bekleyen çağrıları kontrol eder
  Future<void> _checkIncomingCallsFromSyncService() async {
    if (!mounted || !state.isOnline) return;

    try {
      final cagrilar = await _appDataService.getCagrilar();
      final pendingCalls =
          cagrilar.where((c) => c.durum == CagriDurumu.bekliyor).toList();

      if (pendingCalls.isEmpty) {
        if (state.incomingCall != null &&
            !state.incomingCall!.id.startsWith('demo-manual-')) {
          state = state.copyWith(clearIncomingCall: true);
        }
        return;
      }

      // Daha önce reddedilmemiş / kabul edilmemiş en son çağrıyı al
      final active = pendingCalls.firstWhere(
        (c) => !_handledCallIds.contains(c.id),
        orElse: () => pendingCalls.first,
      );

      if (_handledCallIds.contains(active.id)) return;
      if (state.incomingCall?.id == active.id) return;

      debugPrint(
        '>>> [UstaDashboardController] Gelen çağrı bulundu: ${active.id}, Tutar: ${active.toplamTutar}',
      );
      state = state.copyWith(incomingCall: active);
    } catch (e) {
      debugPrint(
        '[UstaDashboardController] _checkIncomingCallsFromSyncService error: $e',
      );
    }
  }

  /// Gelen çağrıyı kabul et (`durum = 'kabul_edildi'`)
  Future<bool> acceptIncomingCall(String cagriId) async {
    _handledCallIds.add(cagriId);

    await _appDataService.updateCagriStatus(cagriId, CagriDurumu.kabulEdildi);
    DemoCallRepository.updateStatus(cagriId, CagriDurumu.kabulEdildi);

    state = state.copyWith(
      clearIncomingCall: true,
      successMessage: 'Çağrı kabul edildi! Navigasyona yönlendiriliyorsunuz...',
    );

    if (cagriId.startsWith('demo-')) {
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
          errorMessage:
              response['message'] as String? ?? 'Çağrı kabul edilemedi.',
        );
        return false;
      }
    } catch (e) {
      debugPrint('acceptIncomingCall hatası: $e');
      return true;
    }
  }

  /// Gelen çağrıyı reddet veya 30 saniye zaman aşımında iptal et (`durum = 'iptal'`)
  Future<void> rejectIncomingCall(String cagriId) async {
    _handledCallIds.add(cagriId);

    await _appDataService.updateCagriStatus(cagriId, CagriDurumu.iptal);
    DemoCallRepository.updateStatus(cagriId, CagriDurumu.iptal);
    state = state.copyWith(clearIncomingCall: true);

    if (cagriId.startsWith('demo-')) {
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

  /// Müsaitim (Online) / Meşgulüm (Offline) durumunu değiştirir.
  /// Usta durumu değiştirdiğinde tekrar kendisi değiştirene kadar kalıcı olarak o durumda kalır.
  /// Çevrimdışı yapıldığında ustanın pinleri müşterinin haritasından ANINDA yok olur;
  /// Çevrimiçi yapıldığında ustanın pinleri müşterinin haritasında ANINDA belirir.
  Future<void> toggleOnlineStatus(bool targetStatus) async {
    final phone = state.activeUstaPhone ?? '';
    final ustaId = state.activeUstaId ?? (phone.isNotEmpty ? 'usta-$phone' : '');

    // 1. State'i derhal güncelle (UI anında renk değiştirir)
    state = state.copyWith(
      isOnline: targetStatus,
      errorMessage: null,
      successMessage: targetStatus
          ? 'Müsait moddasınız. Müşteriler haritada sizi görebilir!'
          : 'Meşgul moddasınız. Haritadan gizlendiniz, yeni çağrı alınmayacak.',
      clearIncomingCall: !targetStatus,
    );

    // 2. Kalıcı olarak SharedPreferences'a kaydet (Uygulama kapansa bile tekrar açana kadar meşgul, kapatana kadar müsait kalır)
    try {
      final prefs = await SharedPreferences.getInstance();
      if (phone.isNotEmpty) {
        await prefs.setBool('usta_is_online_$phone', targetStatus);
      }
      await prefs.setBool('usta_is_online', targetStatus);
    } catch (e) {
      debugPrint('toggleOnlineStatus SharedPreferences kaydetme hatası: $e');
    }

    // 3. AppDataService üzerinden sync server ve yerel belleği canlı güncelle (Harita pini WebSocket ile anında yok olur/belirir)
    try {
      await _appDataService.updateUstaOnlineStatus(
        ustaId: ustaId,
        phone: phone,
        isOnline: targetStatus,
      );
    } catch (e) {
      debugPrint('toggleOnlineStatus AppDataService güncelleme hatası: $e');
    }

    // 4. Konum servisi ve akışları güncelle
    final uid = currentUserId;
    if (uid != null) {
      try {
        if (targetStatus) {
          unawaited(_locationService.startTracking(uid));
          _subscribeToIncomingCallsStream(uid);
        } else {
          await _locationService.stopTracking();
          await _incomingCallsStreamSub?.cancel();
          _incomingCallsStreamSub = null;
        }

        unawaited(_supabase
            .from(AppConstants.ustalarTable)
            .update({'is_online': targetStatus})
            .eq('id', uid)
            .timeout(const Duration(seconds: 2))
            .catchError((_) {}));
      } catch (_) {}
    } else {
      // Demo modunda çağrı dinleme kontrolü
      if (targetStatus) {
        unawaited(_checkIncomingCallsFromSyncService());
      }
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
    _appDataSubscription?.cancel();
    _incomingCallsStreamSub?.cancel();
    super.dispose();
  }
}
