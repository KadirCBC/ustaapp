import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/orders/views/widgets/completion_proof_preview.dart';

/// Ustanın işi bitirdiğinde zorunlu olarak fotoğraf çekmesini sağlayan güvence diyaloğu.
/// Hem ustanın emeğini korur hem de müşterinin onay öncesi işi görmesini garanti eder.
class JobCompletionProofDialog extends StatefulWidget {
  final String cagriBaslik;
  final String musteriAd;

  const JobCompletionProofDialog({
    super.key,
    required this.cagriBaslik,
    required this.musteriAd,
  });

  static Future<Map<String, String>?> show(
    BuildContext context, {
    required String cagriBaslik,
    required String musteriAd,
  }) {
    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => JobCompletionProofDialog(
        cagriBaslik: cagriBaslik,
        musteriAd: musteriAd,
      ),
    );
  }

  @override
  State<JobCompletionProofDialog> createState() =>
      _JobCompletionProofDialogState();
}

class _JobCompletionProofDialogState extends State<JobCompletionProofDialog> {
  String? _selectedPhotoData;
  late final TextEditingController _noteController;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // Test / Hızlı kullanım için yüksek kaliteli örnek tamamlanmış tesisat / pano fotoğrafı (Web/Emulator için)
  static const String _defaultSamplePhoto =
      'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?q=80&w=800&auto=format&fit=crop';

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _isLoading = true);
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 82,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        setState(() {
          _selectedPhotoData = 'data:image/jpeg;base64,$base64String';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraf seçilirken bir hata oluştu: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _useSamplePhoto() {
    setState(() {
      _selectedPhotoData = _defaultSamplePhoto;
      if (_noteController.text.isEmpty) {
        _noteController.text = 'Elektrik sigorta panosu ve arızalı klemensler yenilendi, hat voltajı test edildi.';
      }
    });
  }

  void _onConfirm() {
    if (_selectedPhotoData == null || _selectedPhotoData!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen yapılan işe dair en az 1 adet fotoğraf çekin veya yükleyin.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.of(context).pop({
      'photoUrl': _selectedPhotoData!,
      'note': _noteController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasPhoto = _selectedPhotoData != null && _selectedPhotoData!.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF334155), width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Üst Tutma Çubuğu
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF475569),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Başlık ve Güvenlik Rozeti
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.5)),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Color(0xFF22C55E),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'İş Teslim Kanıtı ve Fotoğraf',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Müşteri & Usta Çift Taraflı Güvence Sistemi',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Açıklama / Yasal Güvence Kutusu
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Zorunlu Fotoğraf Kuralı: Bu fotoğraf tamamladığınız işi resmi olarak belgeler ve hakedişinizi korur. Müşteri fotoğrafı görerek onaylar ve iş bittikten sonra haksız iade talebinde bulunamaz.',
                      style: TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Fotoğraf Alanı
            if (hasPhoto) ...[
              Stack(
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF22C55E), width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CompletionProofPreview(
                        photoData: _selectedPhotoData!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.greenAccent),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'Fotoğraf Doğrulandı',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.75),
                      radius: 18,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () => setState(() => _selectedPhotoData = null),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded, size: 16, color: Color(0xFF38BDF8)),
                    label: const Text('Yeniden Çek', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13)),
                  ),
                  const SizedBox(width: 14),
                  TextButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded, size: 16, color: Color(0xFF94A3B8)),
                    label: const Text('Galeriden Değiştir', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  ),
                ],
              ),
            ] else ...[
              Container(
                height: 175,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF475569),
                    style: BorderStyle.solid,
                    width: 1.5,
                  ),
                ),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF22C55E)),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF334155),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_a_photo_rounded,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Yapılan İşin Net Fotoğrafını Ekleyin',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tamamlanan tesisat, arıza noktası veya montaj görünmelidir',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _pickImage(ImageSource.camera),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.ustaPrimary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                icon: const Icon(Icons.camera_alt_rounded, size: 16),
                                label: const Text('Kamerayı Aç', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _pickImage(ImageSource.gallery),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFF475569)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                icon: const Icon(Icons.photo_library_rounded, size: 16),
                                label: const Text('Galeriden Seç', style: TextStyle(fontSize: 12.5)),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              // Simülatör / Demo için hızlı örnek fotoğraf düğmesi
              Center(
                child: TextButton.icon(
                  onPressed: _useSamplePhoto,
                  icon: const Icon(Icons.flash_on_rounded, size: 15, color: Colors.orangeAccent),
                  label: const Text(
                    'Örnek İş Teslim Fotoğrafı Kullan (Test/Demo)',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // İş Açıklaması / Not Alanı
            TextField(
              controller: _noteController,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Yapılan İşlemler / Usta Notu (Opsiyonel)',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                hintText: 'Örn: Arızalı sigorta ve klemens yenilendi, testler yapıldı.',
                hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12.5),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF22C55E)),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Onay ve Gönder Butonu (Fotoğraf seçilmeden pasif!)
            ElevatedButton.icon(
              onPressed: hasPhoto ? _onConfirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                disabledBackgroundColor: const Color(0xFF334155),
                foregroundColor: Colors.white,
                disabledForegroundColor: const Color(0xFF64748B),
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: hasPhoto ? 4 : 0,
              ),
              icon: Icon(
                hasPhoto ? Icons.verified_rounded : Icons.lock_outline_rounded,
                size: 20,
              ),
              label: Text(
                hasPhoto
                    ? 'Fotoğrafı Onayla ve Müşteriden Onay İste'
                    : 'Önce Yapılan İşin Fotoğrafını Çekin',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
