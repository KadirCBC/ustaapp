import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/orders/controllers/active_order_controller.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';

class UstaActiveJobScreen extends ConsumerWidget {
  final String cagriId;

  const UstaActiveJobScreen({super.key, required this.cagriId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeOrderControllerProvider(cagriId));
    final controller = ref.read(activeOrderControllerProvider(cagriId).notifier);

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

    return Scaffold(
      backgroundColor: AppTheme.ustaDarkBackground,
      appBar: AppBar(
        title: const Text('Aktif İş Yönetimi'),
        backgroundColor: AppTheme.ustaDarkBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/usta/orders'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Durum ve Hakediş Başlık Kartı
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
                      color: AppTheme.ustaPrimary.withOpacity(0.15),
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

            const SizedBox(height: 20),

            // 2. Müşteri İletişim Kartı
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
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.ustaTextMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.ustaDarkBackground,
                        child: const Icon(Icons.person, color: AppTheme.ustaTextLight),
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
                          // Arama
                        },
                      ),
                    ],
                  ),
                  if (cagri.adresTarifi != null && cagri.adresTarifi!.isNotEmpty) ...[
                    const Divider(height: 24, color: AppTheme.ustaSurfaceBorder),
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

            const SizedBox(height: 28),

            // 3. Durum İlerleme Aksiyon Butonları
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
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.green),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.verified_rounded, size: 48, color: Colors.greenAccent),
                    SizedBox(height: 10),
                    Text(
                      'İş Başarıyla Tamamlandı!',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Hakediş tutarınız bakiyenize eklendi.',
                      style: TextStyle(fontSize: 13, color: AppTheme.ustaTextLight),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => context.go('/usta/orders'),
                child: const Text('Panele Geri Dön'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
