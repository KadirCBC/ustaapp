import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/map/views/widgets/map_widget.dart';
import 'package:ustaapp/features/orders/controllers/active_order_controller.dart';
import 'package:ustaapp/features/orders/views/widgets/customer_completion_dialog.dart';

class CustomerOnTheWayScreen extends ConsumerStatefulWidget {
  final String cagriId;

  const CustomerOnTheWayScreen({super.key, required this.cagriId});

  @override
  ConsumerState<CustomerOnTheWayScreen> createState() => _CustomerOnTheWayScreenState();
}

class _CustomerOnTheWayScreenState extends ConsumerState<CustomerOnTheWayScreen> {

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeOrderControllerProvider(widget.cagriId));
    final controller = ref.read(activeOrderControllerProvider(widget.cagriId).notifier);

    ref.listen<ActiveOrderState>(activeOrderControllerProvider(widget.cagriId), (previous, next) {
      // Usta 'Adrese Ulaştım' dediğinde bildirim düşür
      if (next.ustaArrived && previous?.ustaArrived != true) {
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.alert);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ustanız adrese ulaştı!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }

      // Usta 'İşi Tamamladım ve Müşteriden Onay İste' dediğinde kilitli onay diyaloğunu aç
      if (next.completionRequested &&
          previous?.completionRequested != true &&
          next.cagri != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => CustomerCompletionDialog(cagri: next.cagri!),
        );
      }

      // Çağrı tamamlandığında Özet & Değerlendirme sayfasına yönlendir
      if (next.cagri?.isCompleted == true && previous?.cagri?.isCompleted != true) {
        context.go('/customer/summary/${widget.cagriId}');
      }

      if (next.cagri?.isCancelled == true && previous?.cagri?.isCancelled != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Çağrı iptal edildi. Haritaya dönülüyor...'),
            backgroundColor: Colors.redAccent,
          ),
        );
        context.go('/customer/map');
      }
    });

    final cagri = state.cagri;
    if (state.isLoading || cagri == null) {
      return const Scaffold(
        backgroundColor: AppTheme.customerBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final customerLat = cagri.musteriLat;
    final customerLng = cagri.musteriLng;
    final ustaLat = state.ustaLat ?? (cagri.musteriLat + 0.0042);
    final ustaLng = state.ustaLng ?? (cagri.musteriLng + 0.0032);
    final distanceStr = cagri.formattedDistanceFrom(ustaLat, ustaLng);

    return Scaffold(
      backgroundColor: AppTheme.customerBackground,
      appBar: AppBar(
        title: const Text('Usta Yolda'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/customer/map'),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_car_rounded, size: 15, color: Color(0xFF15803D)),
                const SizedBox(width: 5),
                Text(
                  cagri.isOnTheWay ? 'Yola Çıktı' : 'Hazırlanıyor',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. CANLI HARİTA VE ROTA ÇİZGİSİ
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                UstaRouteMapWidget(
                  ustaLat: ustaLat,
                  ustaLng: ustaLng,
                  customerLat: customerLat,
                  customerLng: customerLng,
                  routeColor: AppTheme.customerPrimary,
                  ustaMarkerColor: AppTheme.ustaPrimary,
                  customerMarkerColor: AppTheme.customerPrimary,
                  zoom: 14.2,
                ),

                // Tahmini Varış Banner'ı
                Positioned(
                  top: 14,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.near_me_rounded, color: AppTheme.customerPrimary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.ustaArrived
                                    ? 'Ustanız adrese ulaştı!'
                                    : (cagri.isOnTheWay
                                        ? 'Ustanız konumunuza doğru ilerliyor'
                                        : 'Usta çağrıyı kabul etti, yola çıkıyor'),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: state.ustaArrived
                                      ? const Color(0xFF15803D)
                                      : AppTheme.customerTextDark,
                                ),
                              ),
                              Text(
                                state.ustaArrived
                                    ? 'Hizmet başladıktan sonra onay istenecektir'
                                    : 'Kalan Mesafe: $distanceStr • Tahmini 7 - 12 dk',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.customerTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. ALT DETAY & USTA BİLGİ PANELİ
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppTheme.customerPrimary.withValues(alpha: 0.1),
                      child: const Icon(Icons.person_rounded, size: 28, color: AppTheme.customerPrimary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cagri.ustaFullName ?? 'Atanan Usta',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.customerTextDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cagri.ustaPhone ?? '+90 5XX XXX XX XX',
                            style: const TextStyle(fontSize: 13, color: AppTheme.customerTextMuted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${cagri.toplamTutar?.toStringAsFixed(0) ?? '0'} ₺',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.customerPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: state.isActionInProgress
                            ? null
                            : () => controller.cancelCall(reason: 'Müşteri iptal etti'),
                        icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                        label: const Text('İptal Et', style: TextStyle(color: Colors.redAccent)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: state.isActionInProgress
                            ? null
                            : () {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (ctx) => CustomerCompletionDialog(cagri: cagri),
                                );
                              },
                        icon: const Icon(Icons.verified_rounded),
                        label: const Text('İş Tamamlandı Onayla'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
