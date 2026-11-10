import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/orders/controllers/active_order_controller.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';
import 'package:ustaapp/features/orders/views/widgets/rating_review_dialog.dart';

class CustomerActiveCallScreen extends ConsumerWidget {
  final String cagriId;

  const CustomerActiveCallScreen({super.key, required this.cagriId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeOrderControllerProvider(cagriId));
    final controller = ref.read(activeOrderControllerProvider(cagriId).notifier);

    // Bildirim dinleyicisi
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

      // Usta kabul ettiğinde bildirim
      if (next.cagri?.isAccepted == true && previous?.cagri?.isAccepted != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usta çağrınızı kabul etti ve hazırlıklara başladı!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // İşlem tamamlandığında değerlendirme diyaloğunu aç
      if (next.cagri?.isCompleted == true && previous?.cagri?.isCompleted != true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => RatingReviewDialog(cagri: next.cagri!),
        );
      }

      // Çağrı reddedildiğinde veya zaman aşımında haritaya geri dön
      if (next.cagri?.isCancelled == true && previous?.cagri?.isCancelled != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Çağrı kabul edilmedi veya zaman aşımına uğradı. Haritaya dönülüyor...'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 3),
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (context.mounted) {
            context.go('/customer/map');
          }
        });
      }
    });

    if (state.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Çağrı durumu yükleniyor...'),
            ],
          ),
        ),
      );
    }

    final cagri = state.cagri;
    if (cagri == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Çağrı Takibi')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              const Text('Çağrı bulunamadı veya silinmiş.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/customer/map'),
                child: const Text('Haritaya Dön'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.customerBackground,
      appBar: AppBar(
        title: const Text('Canlı Çağrı Takibi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/customer/map'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. CANLI DURUM STEPPER KARTI
            _buildStatusProgressCard(cagri),

            const SizedBox(height: 20),

            // 2. RADAR VEYA USTA BİLGİ KARTI
            if (cagri.isPending)
              _buildPendingRadarCard(cagri, controller, state)
            else
              _buildUstaInfoCard(cagri),

            const SizedBox(height: 20),

            // 3. ÇAĞRI VE ÜCRET ÖZETİ
            _buildPricingSummaryCard(cagri),

            const SizedBox(height: 28),

            // 4. AKSİYON BUTONLARI
            if (cagri.isPending || cagri.isAccepted || cagri.isOnTheWay)
              OutlinedButton.icon(
                onPressed: state.isActionInProgress
                    ? null
                    : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Çağrıyı İptal Et'),
                            content: const Text('Bu çağrıyı iptal etmek istediğinize emin misiniz?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Vazgeç'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('İptal Et'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await controller.cancelCall();
                        }
                      },
                icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                label: const Text('Çağrıyı İptal Et', style: TextStyle(color: Colors.redAccent)),
              )
            else if (cagri.isCompleted)
              ElevatedButton.icon(
                onPressed: () => context.go('/customer/map'),
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('İşlem Tamamlandı • Ana Sayfaya Dön'),
              ),
          ],
        ),
      ),
    );
  }

  /// Çağrı İlerleme Stepper Kartı
  Widget _buildStatusProgressCard(CagriModel cagri) {
    int currentStep = 0;
    if (cagri.isAccepted) currentStep = 1;
    if (cagri.isOnTheWay) currentStep = 2;
    if (cagri.isCompleted) currentStep = 3;
    if (cagri.isCancelled) currentStep = -1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                cagri.durum.displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.customerPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cagri.isCompleted
                      ? Colors.green.withOpacity(0.12)
                      : (cagri.isCancelled
                          ? Colors.red.withOpacity(0.12)
                          : AppTheme.customerSecondary.withOpacity(0.12)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  cagri.durum.toDbValue().toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cagri.isCompleted
                        ? Colors.green
                        : (cagri.isCancelled ? Colors.redAccent : AppTheme.customerSecondary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Adım Göstergeleri
          Row(
            children: [
              _buildStepNode(label: 'Onay', index: 0, currentStep: currentStep),
              _buildStepDivider(isActive: currentStep >= 1),
              _buildStepNode(label: 'Kabul', index: 1, currentStep: currentStep),
              _buildStepDivider(isActive: currentStep >= 2),
              _buildStepNode(label: 'Yolda', index: 2, currentStep: currentStep),
              _buildStepDivider(isActive: currentStep >= 3),
              _buildStepNode(label: 'Bitti', index: 3, currentStep: currentStep),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode({required String label, required int index, required int currentStep}) {
    final isDone = currentStep > index;
    final isCurrent = currentStep == index;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone || isCurrent ? AppTheme.customerPrimary : const Color(0xFFE2E8F0),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isCurrent ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent ? AppTheme.customerPrimary : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider({required bool isActive}) {
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? AppTheme.customerPrimary : const Color(0xFFE2E8F0),
      ),
    );
  }

  /// Bekleme Radarı
  Widget _buildPendingRadarCard(
    CagriModel cagri,
    ActiveOrderController controller,
    ActiveOrderState state,
  ) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.customerSecondary.withOpacity(0.1),
            ),
            child: const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.customerSecondary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Usta Yanıtı Bekleniyor...',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Talebiniz çevredeki en yakın ustaya iletildi. Birkaç dakika içinde yanıtlanacaktır.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.customerTextMuted),
          ),
        ],
      ),
    );
  }

  /// Atanan Usta Bilgi Kartı
  Widget _buildUstaInfoCard(CagriModel cagri) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.customerPrimary.withOpacity(0.1),
            child: const Icon(Icons.person, size: 32, color: AppTheme.customerPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cagri.ustaFullName ?? 'Atanan Usta',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  cagri.ustaPhone ?? 'İletişim numarası',
                  style: const TextStyle(fontSize: 13, color: AppTheme.customerTextMuted),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.phone, color: Colors.green),
              onPressed: () {
                // Telefon araması
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Ücret ve Adres Özeti
  Widget _buildPricingSummaryCard(CagriModel cagri) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Çağrı Özeti',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (cagri.adresTarifi != null && cagri.adresTarifi!.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.customerTextMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cagri.adresTarifi!,
                    style: const TextStyle(fontSize: 13, color: AppTheme.customerTextDark),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Usta Hakedişi:', style: TextStyle(color: AppTheme.customerTextMuted)),
              Text('${cagri.ustaHakedis?.toStringAsFixed(0) ?? '0'} ₺'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Hizmet Bedeli:', style: TextStyle(color: AppTheme.customerTextMuted)),
              Text('${cagri.komisyonTutari?.toStringAsFixed(0) ?? '0'} ₺'),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Toplam Ödenecek:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                '${cagri.toplamTutar?.toStringAsFixed(0) ?? '0'} ₺',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.customerPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
