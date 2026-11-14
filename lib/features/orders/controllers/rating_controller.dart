import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/core/services/app_data_service.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';

class RatingState {
  final int selectedRating;
  final bool isSubmitting;
  final bool isSubmitted;
  final double? updatedUstaAverage;
  final String? errorMessage;

  const RatingState({
    this.selectedRating = 5,
    this.isSubmitting = false,
    this.isSubmitted = false,
    this.updatedUstaAverage,
    this.errorMessage,
  });

  RatingState copyWith({
    int? selectedRating,
    bool? isSubmitting,
    bool? isSubmitted,
    double? updatedUstaAverage,
    String? errorMessage,
  }) {
    return RatingState(
      selectedRating: selectedRating ?? this.selectedRating,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      updatedUstaAverage: updatedUstaAverage ?? this.updatedUstaAverage,
      errorMessage: errorMessage,
    );
  }
}

final ratingControllerProvider = StateNotifierProvider.autoDispose
    .family<RatingController, RatingState, String>((ref, cagriId) {
  final supabase = ref.watch(supabaseClientProvider);
  final appDataService = ref.watch(appDataServiceProvider);
  return RatingController(supabase, appDataService, cagriId);
});

class RatingController extends StateNotifier<RatingState> {
  final SupabaseClient _supabase;
  final AppDataService _appDataService;
  final String _cagriId;

  RatingController(this._supabase, this._appDataService, this._cagriId) : super(const RatingState());

  void setRating(int rating) {
    if (rating < 1 || rating > 5 || state.isSubmitted) return;
    state = state.copyWith(selectedRating: rating, errorMessage: null);
  }

  /// 1-5 arası değerlendirmeyi kaydeder ve `ustalar.puan` ortalamasını günceller/doğrular.
  Future<bool> submitRating({
    required CagriModel cagri,
    String? comment,
  }) async {
    final puan = state.selectedRating;
    final trimmedComment = comment?.trim();
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    if (_cagriId.startsWith('demo-')) {
      await Future.delayed(const Duration(milliseconds: 350));
      final simulatedAvg = double.parse((((4.85 * 14) + puan) / 15).toStringAsFixed(2));
      final wf = DemoCallRepository.getWorkflow(_cagriId).copyWith(
        ustaAverageRating: simulatedAvg,
      );
      DemoCallRepository.saveWorkflow(_cagriId, wf);
      _appDataService.addOrUpdateFinancialTransaction({
        'cagri_id': cagri.id,
        'puan': puan.toDouble(),
        'musteri_yorum': trimmedComment ?? '',
      });
      state = state.copyWith(
        isSubmitting: false,
        isSubmitted: true,
        updatedUstaAverage: simulatedAvg,
      );
      return true;
    }

    try {
      final user = _supabase.auth.currentUser;
      final ustaId = cagri.ustaId;
      if (user == null || ustaId == null) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'Kullanıcı veya usta bilgisi doğrulanamadı.',
        );
        return false;
      }

      // 1. `degerlendirmeler` tablosuna ekle (DB Trigger `update_usta_ortalama_puan` çalışır)
      await _supabase.from(AppConstants.degerlendirmelerTable).upsert(
        {
          'cagri_id': cagri.id,
          'musteri_id': user.id,
          'usta_id': ustaId,
          'puan': puan,
          'yorum': (trimmedComment != null && trimmedComment.isNotEmpty)
              ? trimmedComment
              : null,
        },
        onConflict: 'cagri_id',
      );

      // 2. `ustalar.puan` güncel ortalamasını oku veya trigger eksikse istemci tarafından güncelle
      double? updatedAverage;
      final ustaRow = await _supabase
          .from(AppConstants.ustalarTable)
          .select('puan')
          .eq('id', ustaId)
          .maybeSingle();

      if (ustaRow != null && ustaRow['puan'] != null) {
        updatedAverage = (ustaRow['puan'] as num).toDouble();
      } else {
        final ratings = await _supabase
            .from(AppConstants.degerlendirmelerTable)
            .select('puan')
            .eq('usta_id', ustaId);
        if (ratings.isNotEmpty) {
          final sum = ratings.fold<int>(
            0,
            (prev, row) => prev + ((row['puan'] as num?)?.toInt() ?? 5),
          );
          updatedAverage = double.parse((sum / ratings.length).toStringAsFixed(2));
          try {
            await _supabase
                .from(AppConstants.ustalarTable)
                .update({'puan': updatedAverage}).eq('id', ustaId);
          } catch (rlsErr) {
            debugPrint('[RatingController] RLS puan güncelleme atlandı (trigger aktif): $rlsErr');
          }
        }
      }

      state = state.copyWith(
        isSubmitting: false,
        isSubmitted: true,
        updatedUstaAverage: updatedAverage ?? puan.toDouble(),
      );
      return true;
    } catch (e) {
      debugPrint('[RatingController] submitRating hatası: $e');
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Değerlendirme kaydedilemedi: $e',
      );
      return false;
    }
  }
}
