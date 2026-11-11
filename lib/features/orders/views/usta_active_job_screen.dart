import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/orders/controllers/active_order_controller.dart';
import 'package:ustaapp/features/orders/controllers/usta_dashboard_controller.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';

class UstaActiveJobScreen extends ConsumerWidget {
  final String cagriId;

  const UstaActiveJobScreen({super.key, required this.cagriId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeOrderControllerProvider(cagriId));
    final controller = ref.read(activeOrderControllerProvider(cagriId).notifier);
    final dashboardState = ref.watch(ustaDashboardControllerProvider);

    ref.listen<ActiveOrderState>(activeOrderControllerProvider(cagriId), (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: Colors.redAccent),
        );
      }
      if (next.successMessage != null && next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!), backgroundColor: Colors.green),
        );
      }
    });

    if (state.isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.ustaDarkBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.ustaPrimary),
        ),
      );
    }

    final cagri = state.cagri;
    if (cagri == null) {
      return Scaffold(
        backgroundColor: AppTheme.ustaDarkBackground,
        appBar: AppBar(title: const Text('Aktif İş')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('İş detayı bulunamadı.', style: TextStyle(color: AppTheme.ustaTextLight)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/usta/orders'),
                child: const Text('Panele Dön'),
              ),
            ],
          ),
        ),
      );
    }

    final customerLatLng = LatLng(cagri.musteriLat, cagri.musteriLng);
    final ustaLatLng = LatLng(dashboardState.ustaLat, dashboardState.ustaLng);
    final distanceText = cagri.formattedDistanceFrom(ustaLatLng.latitude, ustaLatLng.longitude);

    return Scaffold(
      backgroundColor: AppTheme.ustaDarkBackground,
      appBar: AppBar(
        title: const Text('Müşteriye Navigasyon'),
        backgroundColor: AppTheme.ustaDarkBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/usta/orders'),
        ),
      ),
      body: Column(
        children: [
          // 1. MÜŞTERİNİN EVİNE GİDEN CANLI HARİTA & NAVİGASYON EKRANI
          SizedBox(
            height: 260,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(
                      (customerLatLng.latitude + ustaLatLng.latitude) / 2,
                      (customerLatLng.longitude + ustaLatLng.longitude) / 2,
                    ),
                    initialZoom: 13.8,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.ustaapp',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [ustaLatLng, customerLatLng],
                          strokeWidth: 5.0,
                          color: AppTheme.ustaPrimary,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // Usta Konumu
                        Marker(
                          point: ustaLatLng,
                          width: 44,
                          height: 44,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.ustaPrimary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                        // Müşteri Evi Konumu
                        Marker(
                          point: customerLatLng,
                          width: 48,
                          height: 48,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(Icons.home_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 12,
                  left: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.ustaDarkBackground.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.ustaPrimary),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.turn_right_rounded, color: AppTheme.ustaSecondary, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Müşteri Konumuna Rota • $distanceText',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. İŞ DETAYLARI VE DURUM AKSİYONLARI
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Durum ve Hakediş Başlık Kartı
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.ustaSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.ustaSurfaceBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Net Hakedişiniz',
                              style: TextStyle(fontSize: 12, color: AppTheme.ustaTextMuted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${cagri.ustaHakedis?.toStringAsFixed(0) ?? '0'} ₺',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.greenAccent,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.ustaPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            cagri.durum.displayName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.ustaSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Müşteri İletişim & Adres Kartı
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.ustaSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.ustaSurfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Müşteri Bilgileri',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.ustaTextMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.ustaDarkBackground,
                              child: Icon(Icons.person, color: AppTheme.ustaTextLight),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cagri.musteriFullName ?? 'Müşteri',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.ustaTextLight,
                                    ),
                                  ),
                                  Text(
                                    cagri.musteriPhone ?? '',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.ustaTextMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.greenAccent),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Müşteri aranıyor...')),
                                );
                              },
                            ),
                          ],
                        ),
                        if (cagri.adresTarifi != null && cagri.adresTarifi!.isNotEmpty) ...[
                          const Divider(height: 22, color: AppTheme.ustaSurfaceBorder),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_rounded, size: 18, color: AppTheme.ustaSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  cagri.adresTarifi!,
                                  style: const TextStyle(fontSize: 13.5, color: AppTheme.ustaTextLight),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Durum İlerleme Aksiyon Butonları
                  if (cagri.isAccepted) ...[
                    ElevatedButton.icon(
                      onPressed: state.isActionInProgress
                          ? null
                          : () => controller.updateStatus(CagriDurumu.yolda),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.ustaPrimary,
                        minimumSize: const Size.fromHeight(54),
                      ),
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text(
                        'Yola Çıktım',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ] else if (cagri.isOnTheWay) ...[
                    ElevatedButton.icon(
                      onPressed: state.isActionInProgress
                          ? null
                          : () => controller.updateStatus(CagriDurumu.tamamlandi),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size.fromHeight(54),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text(
                        'İşi Tamamla (Ödemeyi Al)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ] else if (cagri.isCompleted) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.verified_rounded, size: 48, color: Colors.greenAccent),
                          SizedBox(height: 10),
                          Text(
                            'İş Başarıyla Tamamlandı!',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Hakediş tutarınız bakiyenize eklendi.',
                            style: TextStyle(fontSize: 13, color: AppTheme.ustaTextLight),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => context.go('/usta/orders'),
                      child: const Text('Panele Geri Dön'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
