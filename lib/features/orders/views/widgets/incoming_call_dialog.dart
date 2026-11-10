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
  static const int _totalDuration = 30; // 30 saniye
  int _countdown = _totalDuration;
  Timer? _timer;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _triggerAlert();
    _startCountdown();
  }

  /// Ses ve titreşimli acil çağrı uyarısı
  void _triggerAlert() {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      // Her 5 saniyede bir titreşimi tekrarla
      if (_countdown % 5 == 0) {
        HapticFeedback.mediumImpact();
      }

      if (_countdown <= 1) {
        timer.cancel();
        if (mounted) {
          // 30 saniye doldu -> Otomatik reddet / iptal et
          await ref.read(ustaDashboardControllerProvider.notifier).rejectIncomingCall(widget.cagri.id);
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }
      } else {
        if (mounted) {
          setState(() => _countdown--);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cagri = widget.cagri;
    final controller = ref.read(ustaDashboardControllerProvider.notifier);
    final progress = _countdown / _totalDuration;

    return Dialog(
      backgroundColor: AppTheme.ustaDarkBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: AppTheme.ustaPrimary, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ACİL ÇAĞRI BAŞLIĞI
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_active_rounded, color: Colors.redAccent, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'YENİ ACİL ÇAĞRI GELDİ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 30 SANİYELİK DAİRESEL GERİ SAYIM SAYACI (Circular Countdown Timer)
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 7,
                    backgroundColor: const Color(0xFF3F3F46),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _countdown <= 10 ? Colors.redAccent : AppTheme.ustaPrimary,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_countdown',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: _countdown <= 10 ? Colors.redAccent : AppTheme.ustaTextLight,
                      ),
                    ),
                    const Text(
                      'saniye',
                      style: TextStyle(fontSize: 10, color: AppTheme.ustaTextMuted),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 22),

            // KAZANILACAK NET HAKEDİŞ
            const Text(
              'Kazanacağınız Net Tutar',
              style: TextStyle(fontSize: 13, color: AppTheme.ustaTextMuted),
            ),
            const SizedBox(height: 4),
            Text(
              '${cagri.ustaHakedis?.toStringAsFixed(0) ?? '0'} ₺',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.greenAccent,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 20),

            // MÜŞTERİ BİLGİSİ VE AÇIK ADRES
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.ustaSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.ustaSurfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: AppTheme.ustaSecondary),
                      const SizedBox(width: 8),
                      Text(
                        cagri.musteriFullName ?? 'Müşteri',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.ustaTextLight,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: AppTheme.ustaSurfaceBorder),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_rounded, size: 18, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Açık Adres / Arıza Tarifi:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.ustaTextMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (cagri.adresTarifi != null && cagri.adresTarifi!.isNotEmpty)
                                  ? cagri.adresTarifi!
                                  : 'Konum harita üzerinden iletildi.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.ustaTextLight,
                                height: 1.35,
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

            const SizedBox(height: 24),

            // AKSİYON BUTONLARI (Kabul Et & Reddet)
            Row(
              children: [
                // Reddet Butonu
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            setState(() => _isProcessing = true);
                            _timer?.cancel();
                            await controller.rejectIncomingCall(cagri.id);
                            if (mounted) {
                              Navigator.of(context, rootNavigator: true).pop();
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Reddet', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),

                // Kabul Et Butonu
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            setState(() => _isProcessing = true);
                            _timer?.cancel();
                            final success = await controller.acceptIncomingCall(cagri.id);
                            if (mounted) {
                              Navigator.of(context, rootNavigator: true).pop();
                              if (success) {
                                context.push('/usta/active-job/${cagri.id}');
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Kabul Et',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
