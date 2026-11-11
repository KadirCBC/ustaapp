import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/core/services/location_service.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';

class UstaDashboardState {
  final bool isOnline;
  final double servisUcreti;
  final int dailyCompletedJobs;
  final double dailyEarnings;
  final bool isLoading;
  final bool isSavingFee;
  final CagriModel? incomingCall;
  final String? errorMessage;
  final String? successMessage;

  const UstaDashboardState({
    this.isOnline = false,
    this.servisUcreti = 500.00,
    this.dailyCompletedJobs = 0,
    this.dailyEarnings = 0.0,
    this.isLoading = false,
    this.isSavingFee = false,
    this.incomingCall,
    this.errorMessage,
    this.successMessage,
  });

  UstaDashboardState copyWith({
    bool? isOnline,
    double? servisUcreti,
    int? dailyCompletedJobs,
    double? dailyEarnings,
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
      dailyCompletedJobs: dailyCompletedJobs ?? this.dailyCompletedJobs,
      dailyEarnings: dailyEarnings ?? this.dailyEarnings,
      isLoading: isLoading ?? this.isLoading,
      isSavingFee: isSavingFee ?? this.isSavingFee,
      incomingCall: clearIncomingCall ? null : (incomingCall ?? this.incomingCall),
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
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
  RealtimeChannel? _incomingCallsChannel;

  UstaDashboardController(this._supabase, this._locationService)
      : super(const UstaDashboardState()) {
    loadDashboardData();
  }

  String? get currentUserId => _supabase.auth.currentUser?.id;

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
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // 1. ustalar tablosundan is_online ve servis_ucreti bilgilerini çek
      final ustaData = await _supabase
          .from(AppConstants.ustalarTable)
          .select('is_online, servis_ucreti')
          .eq('id', uid)
          .maybeSingle();

      bool isOnline = false;
      double servisUcreti = 500.00;

      if (ustaData != null) {
        isOnline = ustaData['is_online'] as bool? ?? false;
        servisUcreti = (ustaData['servis_ucreti'] as num?)?.toDouble() ?? 500.00;
      }

      // 2. Günlük tamamlanan siparişleri ve toplam kazancı hesapla
      final todayStart = DateTime.now().toUtc().toIso8601String().substring(0, 10); // YYYY-MM-DD
      final completedCalls = await _supabase
          .from(AppConstants.cagrilarTable)
          .select('usta_hakedis, durum, created_at')
          .eq('usta_id', uid)
          .eq('durum', 'tamamlandi')
          .gte('created_at', '$todayStart 00:00:00+00');

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
        dailyCompletedJobs: completedCount,
        dailyEarnings: totalEarnings,
      );

      // Çevrimiçi ise konum takibini ve canlı çağrı dinlemesini başlat
      if (isOnline) {
        if (!_locationService.isTracking) {
          await _locationService.startTracking(uid);
        }
        _subscribeToIncomingCalls(uid);
      }
    } catch (e) {
      debugPrint('loadDashboardData hatası: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Veriler yüklenirken hata oluştu: $e',
      );
    }
  }

  /// Gelen acil çağrıları Supabase Realtime ile canlı dinler
  void _subscribeToIncomingCalls(String uid) {
    _incomingCallsChannel?.unsubscribe();
    _incomingCallsChannel = _supabase
        .channel('usta_incoming_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: AppConstants.cagrilarTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'usta_id',
            value: uid,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record['durum'] == 'bekliyor') {
              final incoming = CagriModel.fromJson(record);
              state = state.copyWith(incomingCall: incoming);
            }
          },
        )
        .subscribe();
  }

  /// Gelen çağrıyı kabul et (`cagri_kabul_et` RPC)
  Future<bool> acceptIncomingCall(String cagriId) async {
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

  /// Gelen çağrıyı reddet veya zaman aşımında iptal et
  Future<void> rejectIncomingCall(String cagriId) async {
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
        _subscribeToIncomingCalls(uid);
      } else {
        await _locationService.stopTracking();
        _incomingCallsChannel?.unsubscribe();
        _incomingCallsChannel = null;
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
      // Demo modunda ücret kaydı
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
    _incomingCallsChannel?.unsubscribe();
    super.dispose();
  }
}
