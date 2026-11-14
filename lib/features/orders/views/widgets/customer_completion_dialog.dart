import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/orders/controllers/active_order_controller.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';

/// Usta işi tamamladığında müşterinin ekranını kilitleyen onay diyaloğu:
/// 'Usta işi tamamladı mı?' -> [Evet, Tamamlandı] / [Sorun Var, Bildir]
class CustomerCompletionDialog extends ConsumerStatefulWidget {
  final CagriModel cagri;

  const CustomerCompletionDialog({super.key, required this.cagri});

  @override
  ConsumerState<CustomerCompletionDialog> createState() =>
      _CustomerCompletionDialogState();
}

class _CustomerCompletionDialogState
    extends ConsumerState<CustomerCompletionDialog> {
  bool _showIssueForm = false;
  late final TextEditingController _issueController;

  static const List<String> _quickIssues = [
    'İş henüz tam olarak bitmedi',
    'Arıza tekrar ediyor / çözülemedi',
    'Talep edilen ek malzeme tutarı hatalı',
  ];

  @override
  void initState() {
    super.initState();
    _issueController = TextEditingController();
  }

  @override
  void dispose() {
    _issueController.dispose();
    super.dispose();
  }

  Future<void> _onConfirmCompleted() async {
    final cagriId = widget.cagri.id;
    final controller =
        ref.read(activeOrderControllerProvider(cagriId).notifier);
    final messenger = ScaffoldMessenger.of(context);

    // 1. Diyaloğu hemen kapatarak navigasyon çakışmasını engelle
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }

    // 2. Tahsilat ve tamamlamayı güvenle yürüt
    final result = await controller.confirmCompletionAndCapturePayment();

    if (!result.success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Ödeme tahsilatı tamamlanamadı.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _onSubmitIssue() async {
    final text = _issueController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen karşılaştığınız sorunu kısaca yazın.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final controller =
        ref.read(activeOrderControllerProvider(widget.cagri.id).notifier);

    // 1. Önce diyaloğu kapat
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(false);
    }

    final ok = await controller.reportCompletionIssue(text);

    if (ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Sorun bildirildi. İnceleme tamamlanana kadar ödeme askıda tutulacaktır.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeOrderControllerProvider(widget.cagri.id));
    final cagri = widget.cagri;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üst Durum İkonu
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: _showIssueForm
                        ? Colors.orange.withValues(alpha: 0.14)
                        : const Color(0xFFDBEAFE),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _showIssueForm
                        ? Icons.report_problem_rounded
                        : Icons.task_alt_rounded,
                    size: 36,
                    color: _showIssueForm
                        ? Colors.orange.shade700
                        : AppTheme.customerPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                _showIssueForm
                    ? 'Sorun Bildirimi'
                    : 'Usta işi tamamladı mı?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.customerTextDark,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                _showIssueForm
                    ? 'Bildiriminiz iletildiğinde kartınızdaki provizyon çekilmez, destek ekibimiz inceleyene kadar güvencede kalır.'
                    : '${cagri.ustaFullName ?? 'Ustanız'} hizmeti tamamladığını bildirdi. Onayladığınızda ${cagri.toplamTutar?.toStringAsFixed(2) ?? '0.00'} ₺ tutarındaki provizyon tahsilata dönüşecektir.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: AppTheme.customerTextMuted,
                ),
              ),

              const SizedBox(height: 20),

              if (!_showIssueForm) ...[
                // Ödeme Güvence Özeti Kutusu
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.shield_rounded,
                            size: 18,
                            color: AppTheme.customerPrimary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Tahsil Edilecek Tutar',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.customerTextDark,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${cagri.toplamTutar?.toStringAsFixed(2) ?? '0.00'} ₺',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.customerPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // [Evet, Tamamlandı] -> complete-and-split-payment tetikler
                ElevatedButton.icon(
                  onPressed:
                      state.isActionInProgress ? null : _onConfirmCompleted,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: state.isActionInProgress
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.verified_rounded),
                  label: Text(
                    state.isActionInProgress
                        ? 'Ödeme Onaylanıyor...'
                        : 'Evet, Tamamlandı',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // [Sorun Var, Bildir]
                OutlinedButton.icon(
                  onPressed: state.isActionInProgress
                      ? null
                      : () => setState(() => _showIssueForm = true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1.4),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.report_gmailerrorred_rounded),
                  label: const Text(
                    'Sorun Var, Bildir',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ] else ...[
                // Hızlı Sorun Seçenekleri
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickIssues.map((label) {
                    return ActionChip(
                      label: Text(label, style: const TextStyle(fontSize: 12)),
                      backgroundColor: const Color(0xFFF1F5F9),
                      onPressed: () {
                        setState(() {
                          _issueController.text = label;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _issueController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Karşılaştığınız sorunu detaylandırın...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                ElevatedButton.icon(
                  onPressed: state.isActionInProgress ? null : _onSubmitIssue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Sorunu Bildir ve Ödemeyi Beklet'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: state.isActionInProgress
                      ? null
                      : () => setState(() => _showIssueForm = false),
                  child: const Text('Geri Dön'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
