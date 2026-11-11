import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/orders/controllers/usta_dashboard_controller.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';

class IncomingCallDialog extends ConsumerStatefulWidget {
  final CagriModel cagri;

  const IncomingCallDialog({super.key, required this.cagri});

  @override
  ConsumerState<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends ConsumerState<IncomingCallDialog> {
  static const int _totalSeconds = 30;
  int _remainingMs = _totalSeconds * 1000;
  Timer? _countdownTimer;
  Timer? _alertLoopTimer;
  bool _isProcessing = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _triggerSoundAndVibration();
    _startAlertLoop();
    _startSmoothCountdown();
  }

  /// Sesli ve titreşimli acil çağrı uyarısı
  void _triggerSoundAndVibration() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  /// Modal açıkken her 2.5 saniyede bir ses ve titreşimi yineler
  void _startAlertLoop() {
    _alertLoopTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted && !_isProcessing && !_isClosing) {
        _triggerSoundAndVibration();
      }
    });
  }

  /// 30 saniyelik akıcı dairesel geri sayım sayacı
  void _startSmoothCountdown() {
    const tick = Duration(milliseconds: 100);
    _countdownTimer = Timer.periodic(tick, (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingMs <= 100) {
        timer.cancel();
        _alertLoopTimer?.cancel();
        if (!_isProcessing && !_isClosing) {
          _isClosing = true;
          await ref
              .read(ustaDashboardControllerProvider.notifier)
              .rejectIncomingCall(widget.cagri.id);
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }
      } else {
        setState(() => _remainingMs -= 100);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _alertLoopTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cagri = widget.cagri;
    final dashboardState = ref.watch(ustaDashboardControllerProvider);
    final controller = ref.read(ustaDashboardControllerProvider.notifier);

    // Eğer müşteri çağrıyı iptal ettiyse tam ekran modalı otomatik kapat
    ref.listen<UstaDashboardState>(ustaDashboardControllerProvider, (prev, next) {
      if (prev?.incomingCall != null && next.incomingCall == null && !_isClosing && !_isProcessing) {
        _isClosing = true;
        _countdownTimer?.cancel();
        _alertLoopTimer?.cancel();
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    });

    final int remainingSeconds = (_remainingMs / 1000).ceil();
    final double progress = _remainingMs / (_totalSeconds * 1000);
    final bool isUrgent = remainingSeconds <= 10;
    final String distanceText = cagri.formattedDistanceFrom(
      dashboardState.ustaLat,
      dashboardState.ustaLng,
    );

    return Dialog.fullscreen(
      backgroundColor: AppTheme.ustaDarkBackground,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.ustaDarkBackground,
                isUrgent
                    ? const Color(0xFF450A0A).withValues(alpha: 0.4)
                    : const Color(0xFF27272A),
                AppTheme.ustaDarkBackground,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. ÜST ACİL ÇAĞRI ROZETİ
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_active_rounded, color: Colors.redAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'YENİ ACİL İŞ ÇAĞRISI',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // 2. 30 SANİYELİK DAİRESEL GERİ SAYIM SAYACI (Circular Countdown Timer)
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 152,
                      height: 152,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isUrgent ? Colors.redAccent : AppTheme.ustaPrimary)
                                .withValues(alpha: 0.25),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        strokeCap: StrokeCap.round,
                        backgroundColor: const Color(0xFF3F3F46),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isUrgent ? Colors.redAccent : AppTheme.ustaPrimary,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$remainingSeconds',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: isUrgent ? Colors.redAccent : Colors.white,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'SANİYE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppTheme.ustaTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // 3. KAZANILACAK NET HAKEDİŞ TUTARI
              Column(
                children: [
                  const Text(
                    'KAZANACAĞINIZ NET HAKEDİŞ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppTheme.ustaTextMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${cagri.ustaHakedis?.toStringAsFixed(0) ?? '0'} ₺',
                    style: const TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      color: Colors.greenAccent,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // 4. MÜŞTERİ MESAFESİ & AÇIK ADRES KARTI
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.ustaSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.ustaSurfaceBorder, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_rounded, size: 20, color: AppTheme.ustaSecondary),
                            const SizedBox(width: 8),
                            Text(
                              cagri.musteriFullName ?? 'Müşteri',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.ustaTextLight,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.ustaPrimary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.near_me_rounded, size: 14, color: AppTheme.ustaSecondary),
                              const SizedBox(width: 5),
                              Text(
                                distanceText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.ustaSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: AppTheme.ustaSurfaceBorder),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 22, color: Colors.redAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'MÜŞTERİ AÇIK ADRESİ & ARIZA NOTU',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: AppTheme.ustaTextMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (cagri.adresTarifi != null && cagri.adresTarifi!.isNotEmpty)
                                    ? cagri.adresTarifi!
                                    : 'Müşteri konumu harita üzerinden iletildi.',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.ustaTextLight,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // 5. AKSİYON BUTONLARI (Kabul Et & Reddet)
              Row(
                children: [
                  // Reddet Butonu -> durum = 'iptal', ekran normale döner
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing
                          ? null
                          : () async {
                              final rootNavigator = Navigator.of(context, rootNavigator: true);
                              setState(() {
                                _isProcessing = true;
                                _isClosing = true;
                              });
                              _countdownTimer?.cancel();
                              _alertLoopTimer?.cancel();
                              await controller.rejectIncomingCall(cagri.id);
                              if (mounted) {
                                rootNavigator.pop();
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent, width: 1.5),
                        minimumSize: const Size.fromHeight(58),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text(
                        'Reddet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Kabul Et Butonu -> durum = 'kabul_edildi', doğrudan navigasyon ekranı açılır
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () async {
                              final rootNavigator = Navigator.of(context, rootNavigator: true);
                              final router = GoRouter.of(context);
                              setState(() {
                                _isProcessing = true;
                                _isClosing = true;
                              });
                              _countdownTimer?.cancel();
                              _alertLoopTimer?.cancel();
                              final success = await controller.acceptIncomingCall(cagri.id);
                              if (mounted) {
                                rootNavigator.pop();
                                if (success) {
                                  router.go('/usta/active-job/${cagri.id}');
                                }
                              }
                            },
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 22),
                      label: Text(
                        _isProcessing ? 'Onaylanıyor...' : 'Kabul Et ve Yola Çık',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(58),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
