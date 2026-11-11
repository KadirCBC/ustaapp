import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/core/services/payment_service.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';

class ActiveOrderState {
  final CagriModel? cagri;
  final bool isLoading;
  final bool isActionInProgress;
  final int pendingRemainingSeconds;
  final bool isTimedOut;
  final double? ustaLat;
  final double? ustaLng;
  final bool ustaArrived;
  final DateTime? arrivedAt;
  final bool completionRequested;
  final String? reportedIssue;
  final String? receiptId;
  final SplitPaymentResult? paymentResult;
  final String? errorMessage;
  final String? successMessage;

  const ActiveOrderState({
    this.cagri,
    this.isLoading = false,
    this.isActionInProgress = false,
    this.pendingRemainingSeconds = 35,
    this.isTimedOut = false,
    this.ustaLat,
    this.ustaLng,
    this.ustaArrived = false,
    this.arrivedAt,
    this.completionRequested = false,
    this.reportedIssue,
    this.receiptId,
    this.paymentResult,
    this.errorMessage,
    this.successMessage,
  });

  ActiveOrderState copyWith({
    CagriModel? cagri,
    bool? isLoading,
    bool? isActionInProgress,
    int? pendingRemainingSeconds,
    bool? isTimedOut,
    double? ustaLat,
    double? ustaLng,
    bool? ustaArrived,
    DateTime? arrivedAt,
    bool? completionRequested,
    String? reportedIssue,
    bool clearReportedIssue = false,
    String? receiptId,
    SplitPaymentResult? paymentResult,
    String? errorMessage,
    String? successMessage,
  }) {
    return ActiveOrderState(
      cagri: cagri ?? this.cagri,
      isLoading: isLoading ?? this.isLoading,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
      pendingRemainingSeconds:
          pendingRemainingSeconds ?? this.pendingRemainingSeconds,
      isTimedOut: isTimedOut ?? this.isTimedOut,
      ustaLat: ustaLat ?? this.ustaLat,
      ustaLng: ustaLng ?? this.ustaLng,
      ustaArrived: ustaArrived ?? this.ustaArrived,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      completionRequested: completionRequested ?? this.completionRequested,
      reportedIssue:
          clearReportedIssue ? null : (reportedIssue ?? this.reportedIssue),
      receiptId: receiptId ?? this.receiptId,
      paymentResult: paymentResult ?? this.paymentResult,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

final activeOrderControllerProvider = StateNotifierProvider.autoDispose
    .family<ActiveOrderController, ActiveOrderState, String>((ref, cagriId) {
  final supabase = ref.watch(supabaseClientProvider);
  final paymentService = ref.watch(paymentServiceProvider);
  return ActiveOrderController(supabase, paymentService, cagriId);
});

class ActiveOrderController extends StateNotifier<ActiveOrderState> {
  final SupabaseClient _supabase;
  final PaymentService _paymentService;
  final String _cagriId;

  StreamSubscription<List<Map<String, dynamic>>>? _cagriStreamSub;
  StreamSubscription<List<Map<String, dynamic>>>? _ustaLocationStreamSub;
  RealtimeChannel? _workflowChannel;
  Timer? _pendingTimer;
  Timer? _demoAutoAcceptTimer;

  ActiveOrderController(this._supabase, this._paymentService, this._cagriId)
      : super(const ActiveOrderState(isLoading: true)) {
    _initAndListen();
  }

  bool get _isDemo => _cagriId.startsWith('demo-');

  Future<void> _initAndListen() async {
    if (_isDemo) {
      _initDemoMode();
      return;
    }

    await fetchCagriDetails();
    _subscribeToCagriRealtimeStream();
    _subscribeToWorkflowBroadcast();
  }

  void _initDemoMode() {
    final demoCall = DemoCallRepository.get(_cagriId);
    if (demoCall == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Demo çağrı bulunamadı.',
      );
      return;
    }

    final wf = DemoCallRepository.getWorkflow(_cagriId);
    state = state.copyWith(
      isLoading: false,
      cagri: demoCall,
      ustaLat: demoCall.musteriLat + 0.0045,
      ustaLng: demoCall.musteriLng + 0.0035,
      ustaArrived: wf.ustaArrived,
      arrivedAt: wf.arrivedAt,
      completionRequested: wf.completionRequested,
      reportedIssue: wf.reportedIssue,
      receiptId: wf.receiptId,
    );

    if (demoCall.isPending) {
      _startPendingCountdown();
      _demoAutoAcceptTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        final current = state.cagri;
        if (current != null && current.isPending) {
          _pendingTimer?.cancel();
          DemoCallRepository.updateStatus(_cagriId, CagriDurumu.kabulEdildi);
          state = state.copyWith(
            cagri: current.copyWith(durum: CagriDurumu.kabulEdildi),
            successMessage: 'Usta çağrınızı kabul etti!',
          );
        }
      });
    }
  }

  /// Çağrının ilk detaylarını ve profil bilgilerini çeker
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

      if (cagri.isPending) {
        _startPendingCountdown();
      } else {
        _pendingTimer?.cancel();
      }

      if (cagri.ustaId != null && (cagri.isAccepted || cagri.isOnTheWay)) {
        _subscribeToUstaLocationStream(cagri.ustaId!);
      }
    } catch (e) {
      debugPrint('fetchCagriDetails hatası: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Çağrı detayları alınamadı: $e',
      );
    }
  }

  /// Supabase Realtime Stream üzerinden `cagrilar` tablosunu anlık dinler
  void _subscribeToCagriRealtimeStream() {
    _cagriStreamSub?.cancel();
    _cagriStreamSub = _supabase
        .from(AppConstants.cagrilarTable)
        .stream(primaryKey: ['id'])
        .eq('id', _cagriId)
        .listen(
          (List<Map<String, dynamic>> rows) {
            if (rows.isEmpty) return;
            final updatedRow = rows.first;
            final newStatus = CagriDurumu.fromDbValue(updatedRow['durum'] as String?);
            final current = state.cagri;

            if (current != null) {
              final updatedCagri = current.copyWith(
                durum: newStatus,
                paymentIntentId: updatedRow['payment_intent_id'] as String?,
              );
              state = state.copyWith(cagri: updatedCagri);

              if (!updatedCagri.isPending) {
                _pendingTimer?.cancel();
              }

              if (updatedCagri.ustaId != null &&
                  (updatedCagri.isAccepted || updatedCagri.isOnTheWay)) {
                _subscribeToUstaLocationStream(updatedCagri.ustaId!);
              }
            } else {
              fetchCagriDetails();
            }
          },
          onError: (err) {
            debugPrint('Cagri Realtime Stream hatası: $err');
          },
        );
  }

  /// Varış bildirimi, müşteri onay isteği ve itiraz olayları için Realtime Broadcast kanalı
  void _subscribeToWorkflowBroadcast() {
    if (_workflowChannel != null || _isDemo) return;

    _workflowChannel = _supabase
        .channel('cagri_workflow:$_cagriId')
        .onBroadcast(
          event: 'usta_arrived',
          callback: (payload) {
            if (!mounted) return;
            state = state.copyWith(
              ustaArrived: true,
              arrivedAt: DateTime.tryParse(payload['arrived_at'] as String? ?? '') ??
                  DateTime.now(),
              successMessage: 'Ustanız adrese ulaştı!',
            );
          },
        )
        .onBroadcast(
          event: 'completion_requested',
          callback: (_) {
            if (!mounted) return;
            state = state.copyWith(
              ustaArrived: true,
              completionRequested: true,
              clearReportedIssue: true,
            );
          },
        )
        .onBroadcast(
          event: 'issue_reported',
          callback: (payload) {
            if (!mounted) return;
            final reason = payload['reason'] as String? ?? 'Müşteri sorun bildirdi.';
            state = state.copyWith(
              completionRequested: false,
              reportedIssue: reason,
              errorMessage: 'Müşteri sorun bildirdi: $reason',
            );
          },
        )
        .onBroadcast(
          event: 'payment_confirmed',
          callback: (payload) {
            if (!mounted) return;
            final receiptId = payload['receipt_id'] as String?;
            state = state.copyWith(
              completionRequested: false,
              receiptId: receiptId,
              cagri: state.cagri?.copyWith(durum: CagriDurumu.tamamlandi),
              successMessage: 'Müşteri işi onayladı, ödemeniz hakedişinize aktarıldı!',
            );
          },
        )
        .subscribe();
  }

  Future<void> _broadcastWorkflowEvent(
    String event,
    Map<String, dynamic> payload,
  ) async {
    if (_isDemo || _workflowChannel == null) return;
    try {
      await _workflowChannel!.sendBroadcastMessage(
        event: event,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[ActiveOrderController] Broadcast ($event) hatası: $e');
    }
  }

  /// Ustanın canlı GPS koordinatlarını `ustalar` tablosundan dinler (Usta Yolda ekranı için)
  void _subscribeToUstaLocationStream(String ustaId) {
    if (_ustaLocationStreamSub != null || _isDemo) return;

    _ustaLocationStreamSub = _supabase
        .from(AppConstants.ustalarTable)
        .stream(primaryKey: ['id'])
        .eq('id', ustaId)
        .listen((rows) {
          if (rows.isEmpty) return;
          final rawKonum = rows.first['konum'];
          if (rawKonum is Map && rawKonum['coordinates'] is List) {
            final coords = rawKonum['coordinates'] as List;
            if (coords.length >= 2) {
              state = state.copyWith(
                ustaLng: (coords[0] as num).toDouble(),
                ustaLat: (coords[1] as num).toDouble(),
              );
            }
          }
        });
  }

  /// Müşteri tarafı 35 saniyelik bekleme zaman aşımı sayacı
  void _startPendingCountdown() {
    if (_pendingTimer != null && _pendingTimer!.isActive) return;

    _pendingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (state.cagri?.isPending != true) {
        timer.cancel();
        return;
      }

      if (state.pendingRemainingSeconds <= 1) {
        timer.cancel();
        await _handlePendingTimeout();
      } else {
        state = state.copyWith(
          pendingRemainingSeconds: state.pendingRemainingSeconds - 1,
        );
      }
    });
  }

  Future<void> _handlePendingTimeout() async {
    state = state.copyWith(
      isTimedOut: true,
      errorMessage: 'Usta yanıt vermediği için çağrı zaman aşımına uğradı.',
    );
    await cancelCall(reason: '30 saniye içinde yanıt alınamadığı için zaman aşımı');
  }

  /// USTA AŞAMA 1: 'Adrese Ulaştım' -> Müşteriye varış bildirimi gönderir
  Future<bool> markUstaArrived() async {
    final now = DateTime.now();
    state = state.copyWith(isActionInProgress: true, errorMessage: null);

    try {
      if (state.cagri?.isAccepted == true) {
        await _persistStatusChange(CagriDurumu.yolda);
      }

      if (_isDemo) {
        final wf = DemoCallRepository.getWorkflow(_cagriId).copyWith(
          ustaArrived: true,
          arrivedAt: now,
        );
        DemoCallRepository.saveWorkflow(_cagriId, wf);
      } else {
        await _broadcastWorkflowEvent('usta_arrived', {
          'cagri_id': _cagriId,
          'arrived_at': now.toIso8601String(),
        });
      }

      state = state.copyWith(
        isActionInProgress: false,
        ustaArrived: true,
        arrivedAt: now,
        cagri: state.cagri?.isAccepted == true
            ? state.cagri?.copyWith(durum: CagriDurumu.yolda)
            : state.cagri,
        successMessage: 'Adrese ulaştığınız müşteriye bildirildi!',
      );
      return true;
    } catch (e) {
      debugPrint('markUstaArrived hatası: $e');
      state = state.copyWith(
        isActionInProgress: false,
        errorMessage: 'Varış bildirimi gönderilemedi: $e',
      );
      return false;
    }
  }

  /// USTA AŞAMA 2: 'İşi Tamamladım ve Müşteriden Onay İste'
  Future<bool> requestCompletionConfirmation() async {
    state = state.copyWith(
      isActionInProgress: true,
      clearReportedIssue: true,
      errorMessage: null,
    );

    try {
      if (_isDemo) {
        final wf = DemoCallRepository.getWorkflow(_cagriId).copyWith(
          ustaArrived: true,
          completionRequested: true,
          clearIssue: true,
        );
        DemoCallRepository.saveWorkflow(_cagriId, wf);
      } else {
        await _broadcastWorkflowEvent('completion_requested', {
          'cagri_id': _cagriId,
          'requested_at': DateTime.now().toIso8601String(),
        });
      }

      state = state.copyWith(
        isActionInProgress: false,
        ustaArrived: true,
        completionRequested: true,
        clearReportedIssue: true,
        successMessage: 'Müşteriye iş tamamlama onay penceresi gönderildi.',
      );
      return true;
    } catch (e) {
      debugPrint('requestCompletionConfirmation hatası: $e');
      state = state.copyWith(
        isActionInProgress: false,
        errorMessage: 'Onay isteği gönderilemedi: $e',
      );
      return false;
    }
  }

  /// MÜŞTERİ: 'Evet, Tamamlandı' -> `complete-and-split-payment` Edge Function tetiklenir
  Future<SplitPaymentResult> confirmCompletionAndCapturePayment() async {
    state = state.copyWith(isActionInProgress: true, errorMessage: null);

    try {
      final result = await _paymentService.completeAndSplitPayment(
        cagriId: _cagriId,
      );

      if (!result.success) {
        state = state.copyWith(
          isActionInProgress: false,
          errorMessage: result.error ?? 'Ödeme tahsilatı tamamlanamadı.',
        );
        return result;
      }

      final fallbackCode = _cagriId.replaceAll('-', '').toUpperCase();
      final shortCode =
          fallbackCode.length >= 8 ? fallbackCode.substring(0, 8) : fallbackCode;
      final receiptId = result.paymentId ??
          state.cagri?.paymentIntentId ??
          'DKT-$shortCode';

      await _persistStatusChange(CagriDurumu.tamamlandi);

      if (_isDemo) {
        final wf = DemoCallRepository.getWorkflow(_cagriId).copyWith(
          completionRequested: false,
          receiptId: receiptId,
          clearIssue: true,
        );
        DemoCallRepository.saveWorkflow(_cagriId, wf);
      } else {
        await _broadcastWorkflowEvent('payment_confirmed', {
          'cagri_id': _cagriId,
          'receipt_id': receiptId,
        });
      }

      state = state.copyWith(
        isActionInProgress: false,
        completionRequested: false,
        receiptId: receiptId,
        paymentResult: result,
        cagri: state.cagri?.copyWith(durum: CagriDurumu.tamamlandi),
        successMessage: 'İş onaylandı ve ödeme güvenli şekilde tamamlandı.',
      );
      return result;
    } catch (e) {
      debugPrint('confirmCompletionAndCapturePayment hatası: $e');
      state = state.copyWith(
        isActionInProgress: false,
        errorMessage: 'Ödeme onayı sırasında hata oluştu: $e',
      );
      return SplitPaymentResult(success: false, error: e.toString());
    }
  }

  /// MÜŞTERİ: 'Sorun Var, Bildir' -> Ödeme blokede kalır, ustaya ve desteğe iletilir
  Future<bool> reportCompletionIssue(String reason) async {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) return false;

    state = state.copyWith(isActionInProgress: true, errorMessage: null);

    try {
      if (_isDemo) {
        final wf = DemoCallRepository.getWorkflow(_cagriId).copyWith(
          completionRequested: false,
          reportedIssue: trimmed,
        );
        DemoCallRepository.saveWorkflow(_cagriId, wf);
      } else {
        await _broadcastWorkflowEvent('issue_reported', {
          'cagri_id': _cagriId,
          'reason': trimmed,
          'reported_at': DateTime.now().toIso8601String(),
        });
      }

      state = state.copyWith(
        isActionInProgress: false,
        completionRequested: false,
        reportedIssue: trimmed,
        successMessage:
            'Sorun bildiriminiz alındı. İnceleme tamamlanana kadar ödeme askıda tutulacaktır.',
      );
      return true;
    } catch (e) {
      debugPrint('reportCompletionIssue hatası: $e');
      state = state.copyWith(
        isActionInProgress: false,
        errorMessage: 'Sorun bildirimi gönderilemedi: $e',
      );
      return false;
    }
  }

  Future<void> _persistStatusChange(CagriDurumu status) async {
    if (_isDemo) {
      DemoCallRepository.updateStatus(_cagriId, status);
      return;
    }
    await _supabase
        .from(AppConstants.cagrilarTable)
        .update({'durum': status.toDbValue()})
        .eq('id', _cagriId);
  }

  /// Usta için: Çağrıyı atomik olarak kabul et (`cagri_kabul_et` RPC)
  Future<bool> acceptCall() async {
    if (_isDemo) {
      DemoCallRepository.updateStatus(_cagriId, CagriDurumu.kabulEdildi);
      state = state.copyWith(
        cagri: state.cagri?.copyWith(durum: CagriDurumu.kabulEdildi),
        successMessage: 'Çağrı kabul edildi!',
      );
      return true;
    }

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

  /// Çağrı durumunu güncelle (örn: 'yolda', 'tamamlandi', 'iptal')
  Future<bool> updateStatus(CagriDurumu newStatus, {String? reason}) async {
    _pendingTimer?.cancel();
    _demoAutoAcceptTimer?.cancel();

    if (_isDemo) {
      DemoCallRepository.updateStatus(_cagriId, newStatus);
      state = state.copyWith(
        isActionInProgress: false,
        cagri: state.cagri?.copyWith(durum: newStatus),
        successMessage: 'Durum güncellendi: ${newStatus.displayName}',
      );
      return true;
    }

    state = state.copyWith(isActionInProgress: true, errorMessage: null);

    try {
      await _persistStatusChange(newStatus);

      if (newStatus == CagriDurumu.tamamlandi) {
        await _paymentService.completeAndSplitPayment(cagriId: _cagriId);
      } else if (newStatus == CagriDurumu.iptal) {
        await _paymentService.cancelAndReverseAuth(
          cagriId: _cagriId,
          reason: reason,
        );
      }

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
  Future<bool> cancelCall({String? reason}) async {
    return await updateStatus(CagriDurumu.iptal, reason: reason);
  }

  @override
  void dispose() {
    _cagriStreamSub?.cancel();
    _ustaLocationStreamSub?.cancel();
    if (_workflowChannel != null) {
      _supabase.removeChannel(_workflowChannel!);
      _workflowChannel = null;
    }
    _pendingTimer?.cancel();
    _demoAutoAcceptTimer?.cancel();
    super.dispose();
  }
}
