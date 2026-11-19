import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/services/notification_service.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/map/views/widgets/map_widget.dart';
import 'package:ustaapp/features/orders/controllers/active_order_controller.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';
import 'package:ustaapp/features/orders/views/widgets/customer_completion_dialog.dart';

class CustomerOnTheWayScreen extends ConsumerStatefulWidget {
  final String cagriId;

  const CustomerOnTheWayScreen({super.key, required this.cagriId});

  @override
  ConsumerState<CustomerOnTheWayScreen> createState() => _CustomerOnTheWayScreenState();
}

class _CustomerOnTheWayScreenState extends ConsumerState<CustomerOnTheWayScreen> {
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialCompletionState();
    });
  }

  void _checkInitialCompletionState() {
    if (!mounted || _dialogOpen) return;
    final state = ref.read(activeOrderControllerProvider(widget.cagriId));
    if (state.completionRequested && state.cagri != null) {
      _dialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => CustomerCompletionDialog(cagri: state.cagri!),
      ).then((_) => _dialogOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeOrderControllerProvider(widget.cagriId));
    final controller = ref.read(activeOrderControllerProvider(widget.cagriId).notifier);

    ref.listen<ActiveOrderState>(activeOrderControllerProvider(widget.cagriId), (previous, next) {
      // Usta 'Yola Çıktım' dediğinde bildirim düşür
      if (next.cagri?.isOnTheWay == true && previous?.cagri?.isOnTheWay != true) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ustanız yola çıktı! Canlı sürüş takibi başladı.'),
            backgroundColor: Color(0xFF0284C7),
          ),
        );
      }

      // Usta 'Adrese Ulaştım' dediğinde bildirim düşür (Kilitli ekranda sesli & görsel alarm)
      if ((next.ustaArrived || next.cagri?.isAtAddress == true) &&
          previous?.ustaArrived != true &&
          previous?.cagri?.isAtAddress != true) {
        NotificationService.instance.showUstaArrived(
          ustaName: next.cagri?.ustaFullName ?? 'Ustanız',
          cagriId: widget.cagriId,
          address: next.cagri?.adresTarifi,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 Ustanız adrese ulaştı! Kapıyı açınız, usta kapıda beklemesin.'),
            backgroundColor: Color(0xFF16A34A),
            duration: Duration(seconds: 5),
          ),
        );
      }

      // Usta 'İşi Tamamladım ve Müşteriden Onay İste' dediğinde kilitli onay diyaloğunu aç
      if (next.completionRequested &&
          (previous?.completionRequested != true || !_dialogOpen) &&
          next.cagri != null &&
          !_dialogOpen) {
        _dialogOpen = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => CustomerCompletionDialog(cagri: next.cagri!),
        ).then((_) => _dialogOpen = false);
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
          () {
            final isAtAddress = state.ustaArrived || cagri.isAtAddress;
            final isOnTheWay = cagri.isOnTheWay;

            String text;
            IconData icon;
            Color bg;
            Color fg;

            if (isAtAddress) {
              text = 'Usta Adreste';
              icon = Icons.location_on_rounded;
              bg = const Color(0xFFDCFCE7);
              fg = const Color(0xFF15803D);
            } else if (isOnTheWay) {
              text = 'Yolda (Canlı Takip)';
              icon = Icons.directions_car_rounded;
              bg = const Color(0xFFE0F2FE);
              fg = const Color(0xFF0284C7);
            } else {
              text = 'Hazırlanıyor';
              icon = Icons.handyman_rounded;
              bg = const Color(0xFFFEF3C7);
              fg = const Color(0xFFB45309);
            }

            return Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: fg.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: fg),
                  const SizedBox(width: 5),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: fg,
                    ),
                  ),
                ],
              ),
            );
          }(),
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
                  child: () {
                    final isAtAddress = state.ustaArrived || cagri.isAtAddress;
                    final isOnTheWay = cagri.isOnTheWay;

                    Color iconBg;
                    Color iconFg;
                    IconData icon;
                    String title;
                    String subtitle;

                    if (isAtAddress) {
                      iconBg = const Color(0xFFDCFCE7);
                      iconFg = const Color(0xFF15803D);
                      icon = Icons.location_on_rounded;
                      title = 'Ustanız Adrese Ulaştı!';
                      subtitle = 'Yerinde arıza tespiti ve işlem başladı • Hizmet bitiminde onay istenir';
                    } else if (isOnTheWay) {
                      iconBg = const Color(0xFFDBEAFE);
                      iconFg = const Color(0xFF0284C7);
                      icon = Icons.near_me_rounded;
                      title = 'Ustanız Yola Çıktı, Geliyor!';
                      subtitle = 'Canlı sürüş takibi aktif • Kalan: $distanceStr (~7 - 12 dk)';
                    } else {
                      iconBg = const Color(0xFFFEF3C7);
                      iconFg = const Color(0xFFB45309);
                      icon = Icons.handyman_rounded;
                      title = 'Usta Çağrıyı Kabul Etti, Hazırlanıyor';
                      subtitle = 'Takım ve malzemeler hazırlanıyor • Tahmini hazırlık: 3 - 5 dk';
                    }

                    return Container(
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
                              color: iconBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: iconFg),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: iconFg,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
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
                    );
                  }(),
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
                // 3 Aşamalı Durum İlerleme Çubuğu (Hazırlanıyor -> Yolda -> Adreste)
                _buildProgressTimeline(cagri, state),
                if (!state.ustaArrived && !cagri.isAtAddress) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      if (state.isSimulatingDrive) {
                        controller.stopDrivingSimulation();
                      } else {
                        controller.startDrivingSimulation();
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: state.isSimulatingDrive
                            ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: state.isSimulatingDrive
                              ? const Color(0xFF0284C7)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            state.isSimulatingDrive
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            size: 18,
                            color: state.isSimulatingDrive
                                ? const Color(0xFF0284C7)
                                : AppTheme.customerPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            state.isSimulatingDrive
                                ? 'Canlı Takip Simülasyonu Aktif (Durdur)'
                                : '🚗 Canlı Takip & İlerlemeyi Simüle Et',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: state.isSimulatingDrive
                                  ? const Color(0xFF0284C7)
                                  : AppTheme.customerPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
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

  Widget _buildProgressTimeline(CagriModel cagri, ActiveOrderState state) {
    final isAtAddress = state.ustaArrived || cagri.isAtAddress;
    final isOnTheWay = cagri.isOnTheWay;

    int activeStep = 1;
    if (isAtAddress) {
      activeStep = 3;
    } else if (isOnTheWay) {
      activeStep = 2;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _buildStepItem(
            stepNumber: 1,
            title: 'Hazırlanıyor',
            isDone: activeStep > 1,
            isActive: activeStep == 1,
            icon: Icons.inventory_2_rounded,
          ),
          Expanded(
            child: Container(
              height: 2.5,
              color: activeStep > 1 ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
            ),
          ),
          _buildStepItem(
            stepNumber: 2,
            title: 'Yolda',
            isDone: activeStep > 2,
            isActive: activeStep == 2,
            icon: Icons.directions_car_rounded,
          ),
          Expanded(
            child: Container(
              height: 2.5,
              color: activeStep > 2 ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
            ),
          ),
          _buildStepItem(
            stepNumber: 3,
            title: 'Adreste',
            isDone: false,
            isActive: activeStep == 3,
            icon: Icons.location_on_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required int stepNumber,
    required String title,
    required bool isDone,
    required bool isActive,
    required IconData icon,
  }) {
    Color bg;
    Color fg;
    if (isDone) {
      bg = const Color(0xFF10B981);
      fg = Colors.white;
    } else if (isActive) {
      bg = AppTheme.customerPrimary;
      fg = Colors.white;
    } else {
      bg = const Color(0xFFE2E8F0);
      fg = const Color(0xFF94A3B8);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: bg,
          child: isDone
              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
              : Icon(icon, size: 13, color: fg),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.w500,
            color: isActive
                ? AppTheme.customerPrimary
                : (isDone ? const Color(0xFF10B981) : const Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }
}
