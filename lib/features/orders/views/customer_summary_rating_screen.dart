import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/orders/controllers/active_order_controller.dart';
import 'package:ustaapp/features/orders/controllers/rating_controller.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';

/// İş tamamlandıktan sonraki Değerlendirme ve Ödeme Özeti (Dijital Dekont) Ekranı
class CustomerSummaryRatingScreen extends ConsumerStatefulWidget {
  final String cagriId;

  const CustomerSummaryRatingScreen({super.key, required this.cagriId});

  @override
  ConsumerState<CustomerSummaryRatingScreen> createState() =>
      _CustomerSummaryRatingScreenState();
}

class _CustomerSummaryRatingScreenState
    extends ConsumerState<CustomerSummaryRatingScreen> {
  late final TextEditingController _commentController;

  static const List<String> _ratingLabels = [
    'Çok Kötü',
    'Geliştirilebilir',
    'Orta',
    'İyi',
    'Mükemmel Hizmet!',
  ];

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _resolveReceiptNumber(ActiveOrderState orderState, CagriModel cagri) {
    if (orderState.receiptId != null && orderState.receiptId!.isNotEmpty) {
      return orderState.receiptId!;
    }
    if (orderState.paymentResult?.paymentId != null &&
        orderState.paymentResult!.paymentId!.isNotEmpty) {
      return orderState.paymentResult!.paymentId!;
    }
    if (cagri.paymentIntentId != null && cagri.paymentIntentId!.isNotEmpty) {
      return cagri.paymentIntentId!;
    }
    final cleanId = cagri.id.replaceAll('-', '').toUpperCase();
    final shortId = cleanId.length >= 8 ? cleanId.substring(0, 8) : cleanId;
    return 'DKT-$shortId';
  }

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day.$month.${dt.year} • $hour:$min';
  }

  Future<void> _submitRating(CagriModel cagri) async {
    final controller =
        ref.read(ratingControllerProvider(widget.cagriId).notifier);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await controller.submitRating(
      cagri: cagri,
      comment: _commentController.text,
    );

    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Değerlendirmeniz kaydedildi ve ustanın puanı güncellendi!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } else {
      final err = ref.read(ratingControllerProvider(widget.cagriId)).errorMessage;
      messenger.showSnackBar(
        SnackBar(
          content: Text(err ?? 'Değerlendirme kaydedilemedi.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(activeOrderControllerProvider(widget.cagriId));
    final ratingState = ref.watch(ratingControllerProvider(widget.cagriId));
    final ratingController =
        ref.read(ratingControllerProvider(widget.cagriId).notifier);

    final cagri = orderState.cagri;
    if (orderState.isLoading || cagri == null) {
      return const Scaffold(
        backgroundColor: AppTheme.customerBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final baseFee = cagri.ustaHakedis ?? orderState.paymentResult?.ustaHakedis ?? 0;
    final commissionFee =
        cagri.komisyonTutari ?? orderState.paymentResult?.platformKomisyon ?? 0;
    final totalPaid = cagri.toplamTutar ?? (baseFee + commissionFee);
    final receiptNo = _resolveReceiptNumber(orderState, cagri);

    return Scaffold(
      backgroundColor: AppTheme.customerBackground,
      appBar: AppBar(
        title: const Text('Hizmet Özeti & Değerlendirme'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/customer/map'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. ÖDEME TAMAMLANDI BAŞLIK BANNERI
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF15803D), Color(0xFF16A34A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hizmet Tamamlandı & Tahsil Edildi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${cagri.ustaFullName ?? 'Usta'} • ${_formatDateTime(DateTime.now())}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. NET ÖDEME ÖZETİ & DİJİTAL DEKONT KARTI
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ödeme Özeti & Dijital Dekont',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.customerTextDark,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'İyzico Güvencesi',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.customerPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Dijital Dekont Numarası Kutusu
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          size: 18,
                          color: AppTheme.customerTextMuted,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Dekont No:',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.customerTextMuted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            receiptNo,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: AppTheme.customerTextDark,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: receiptNo));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Dijital dekont numarası kopyalandı.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 17,
                              color: AppTheme.customerPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  _SummaryRow(
                    label: 'Usta Taban Ücreti',
                    amount: '${baseFee.toStringAsFixed(2)} ₺',
                  ),
                  const SizedBox(height: 10),
                  _SummaryRow(
                    label: 'Platform Güvence Bedeli',
                    amount: '${commissionFee.toStringAsFixed(2)} ₺',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Toplam Çekilen Tutar',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.customerTextDark,
                        ),
                      ),
                      Text(
                        '${totalPaid.toStringAsFixed(2)} ₺',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.customerPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 3. İNTERAKTİF YILDIZ PUANLAMA & YORUM KARTI
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Ustayla Deneyiminizi Puanlayın',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.customerTextDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Verdiğiniz puan ${cagri.ustaFullName ?? 'ustanın'} genel puan ortalamasına doğrudan yansır.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.customerTextMuted,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1-5 İnteraktif Yıldız Seçici
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      final isSelected = starValue <= ratingState.selectedRating;
                      return GestureDetector(
                        onTap: ratingState.isSubmitted
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                ratingController.setRating(starValue);
                              },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: AnimatedScale(
                            scale: isSelected ? 1.08 : 0.96,
                            duration: const Duration(milliseconds: 150),
                            child: Icon(
                              isSelected
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 42,
                              color: isSelected
                                  ? Colors.amber.shade600
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),

                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${ratingState.selectedRating}/5 • ${_ratingLabels[ratingState.selectedRating - 1]}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Yorum Kutusu
                  TextField(
                    controller: _commentController,
                    enabled: !ratingState.isSubmitted,
                    maxLines: 3,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppTheme.customerTextDark,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Hizmet kalitesi, dakiklik ve işçilik hakkında yorumunuz (opsiyonel)...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  if (!ratingState.isSubmitted) ...[
                    ElevatedButton.icon(
                      onPressed: ratingState.isSubmitting
                          ? null
                          : () => _submitRating(cagri),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: ratingState.isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.star_rounded),
                      label: Text(
                        ratingState.isSubmitting
                            ? 'Kaydediliyor...'
                            : 'Değerlendirmeyi Gönder',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.go('/customer/map'),
                      child: const Text(
                        'Şimdilik Atla ve Haritaya Dön',
                        style: TextStyle(color: AppTheme.customerTextMuted),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              ratingState.updatedUstaAverage != null
                                  ? 'Teşekkürler! Ustanın yeni ortalama puanı: ${ratingState.updatedUstaAverage!.toStringAsFixed(2)} ★'
                                  : 'Değerlendirmeniz için teşekkürler!',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/customer/map'),
                      icon: const Icon(Icons.map_rounded),
                      label: const Text('Haritaya Dön'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String amount;

  const _SummaryRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            color: AppTheme.customerTextMuted,
          ),
        ),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.customerTextDark,
          ),
        ),
      ],
    );
  }
}
