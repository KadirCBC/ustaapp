import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';

class RatingReviewDialog extends ConsumerStatefulWidget {
  final CagriModel cagri;

  const RatingReviewDialog({super.key, required this.cagri});

  @override
  ConsumerState<RatingReviewDialog> createState() => _RatingReviewDialogState();
}

class _RatingReviewDialogState extends ConsumerState<RatingReviewDialog> {
  int _selectedRating = 5;
  late final TextEditingController _commentController;
  bool _isSubmitting = false;

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

  Future<void> _submitReview() async {
    final supabase = ref.read(supabaseServiceProvider).client;
    final user = supabase.auth.currentUser;
    if (user == null || widget.cagri.ustaId == null) return;

    setState(() => _isSubmitting = true);

    try {
      await supabase.from('degerlendirmeler').insert({
        'cagri_id': widget.cagri.id,
        'musteri_id': user.id,
        'usta_id': widget.cagri.ustaId!,
        'puan': _selectedRating,
        'yorum': _commentController.text.trim().isNotEmpty
            ? _commentController.text.trim()
            : null,
      });

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Değerlendirmeniz için teşekkür ederiz!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Değerlendirme kaydedilemedi: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cagri = widget.cagri;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars_rounded, size: 54, color: Colors.amber),
            const SizedBox(height: 12),
            const Text(
              'Hizmeti Değerlendirin',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.customerTextDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${cagri.ustaFullName ?? 'Usta'} tarafından sunulan hizmetten memnun kaldınız mı?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.customerTextMuted),
            ),
            const SizedBox(height: 20),

            // 5 Yıldız Seçici
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                return IconButton(
                  iconSize: 36,
                  icon: Icon(
                    starIndex <= _selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() => _selectedRating = starIndex);
                  },
                );
              }),
            ),

            const SizedBox(height: 16),

            // Yorum Kutusu
            TextField(
              controller: _commentController,
              maxLines: 3,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Hizmet hakkında düşünceleriniz (opsiyonel)...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),

            const SizedBox(height: 22),

            // Gönder Butonu
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Değerlendirmeyi Gönder'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Şimdilik Atla', style: TextStyle(color: AppTheme.customerTextMuted)),
            ),
          ],
        ),
      ),
    );
  }
}
