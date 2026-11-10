import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';

class ActiveOrderState {
  final CagriModel? cagri;
  final bool isLoading;
  final bool isActionInProgress;
  final String? errorMessage;
  final String? successMessage;

  const ActiveOrderState({
    this.cagri,
    this.isLoading = false,
    this.isActionInProgress = false,
    this.errorMessage,
    this.successMessage,
  });

  ActiveOrderState copyWith({
    CagriModel? cagri,
    bool? isLoading,
    bool? isActionInProgress,
    String? errorMessage,
    String? successMessage,
  }) {
    return ActiveOrderState(
      cagri: cagri ?? this.cagri,
      isLoading: isLoading ?? this.isLoading,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

final activeOrderControllerProvider = StateNotifierProvider.autoDispose
    .family<ActiveOrderController, ActiveOrderState, String>((ref, cagriId) {
  final supabase = ref.watch(supabaseClientProvider);
  return ActiveOrderController(supabase, cagriId);
});

class ActiveOrderController extends StateNotifier<ActiveOrderState> {
  final SupabaseClient _supabase;
  final String _cagriId;
  RealtimeChannel? _realtimeChannel;

  ActiveOrderController(this._supabase, this._cagriId)
      : super(const ActiveOrderState(isLoading: true)) {
    _initAndListen();
  }

  Future<void> _initAndListen() async {
    await fetchCagriDetails();
    _subscribeToRealtimeChanges();
  }

  /// Çağrının detaylarını ve usta/müşteri profil bilgilerini çeker
  Future<void> fetchCagriDetails() async {
    try {
      final data = await _supabase
          .from(AppConstants.cagrilarTable)
          .select('''
            *,
            musteri:profiles!cagrilar_musteri_id_fkey(full_name, phone),
            usta:profiles!cagrilar_usta_id_fkey(full_name, phone)
          ''')
          .eq('id', _cagriId)
          .maybeSingle();

      if (data == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Çağrı bulunamadı.',
        );
        return;
      }

      final Map<String, dynamic> flattened = Map<String, dynamic>.from(data);
      if (data['musteri'] is Map) {
        flattened['musteri_full_name'] = data['musteri']['full_name'];
        flattened['musteri_phone'] = data['musteri']['phone'];
      }
      if (data['usta'] is Map) {
        flattened['usta_full_name'] = data['usta']['full_name'];
        flattened['usta_phone'] = data['usta']['phone'];
      }

      final cagri = CagriModel.fromJson(flattened);
      state = state.copyWith(isLoading: false, cagri: cagri);
    } catch (e) {
      debugPrint('fetchCagriDetails hatası: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Çağrı detayları alınamadı: $e',
      );
    }
  }

  /// Supabase Realtime ile çağrının durum değişikliklerini canlı dinler
  void _subscribeToRealtimeChanges() {
    _realtimeChannel = _supabase
        .channel('cagri_tracking_$_cagriId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: AppConstants.cagrilarTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _cagriId,
          ),
          callback: (payload) async {
            debugPrint('Realtime çağrı güncellemesi alındı: ${payload.newRecord}');
            await fetchCagriDetails();
          },
        )
        .subscribe();
  }

  /// Usta için: Çağrıyı atomik olarak kabul et (`cagri_kabul_et` RPC)
  Future<bool> acceptCall() async {
    state = state.copyWith(isActionInProgress: true, errorMessage: null);

    try {
      final response = await _supabase.rpc('cagri_kabul_et', params: {
        'p_cagri_id': _cagriId,
      });

      final success = response['success'] as bool? ?? false;
      final message = response['message'] as String? ?? '';

      if (success) {
        await fetchCagriDetails();
        state = state.copyWith(
          isActionInProgress: false,
          successMessage: 'Çağrı başarıyla kabul edildi!',
        );
        return true;
      } else {
        state = state.copyWith(
          isActionInProgress: false,
          errorMessage: message,
        );
        return false;
      }
    } catch (e) {
      debugPrint('acceptCall hatası: $e');
      state = state.copyWith(
        isActionInProgress: false,
        errorMessage: 'Çağrı kabul edilemedi: $e',
      );
      return false;
    }
  }

  /// Çağrı durumunu güncelle (örn: 'yolda', 'tamamlandi')
  Future<bool> updateStatus(CagriDurumu newStatus) async {
    state = state.copyWith(isActionInProgress: true, errorMessage: null);

    try {
      await _supabase
          .from(AppConstants.cagrilarTable)
          .update({'durum': newStatus.toDbValue()})
          .eq('id', _cagriId);

      await fetchCagriDetails();
      state = state.copyWith(
        isActionInProgress: false,
        successMessage: 'Durum güncellendi: ${newStatus.displayName}',
      );
      return true;
    } catch (e) {
      debugPrint('updateStatus hatası: $e');
      state = state.copyWith(
        isActionInProgress: false,
        errorMessage: 'Durum güncellenemedi: $e',
      );
      return false;
    }
  }

  /// Müşteri veya Usta için: Çağrıyı iptal et
  Future<bool> cancelCall() async {
    return await updateStatus(CagriDurumu.iptal);
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      _supabase.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }
}
