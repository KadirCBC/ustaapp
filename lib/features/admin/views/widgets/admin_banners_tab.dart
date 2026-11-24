import 'package:flutter/material.dart';
import 'package:ustaapp/core/models/banner_model.dart';
import 'package:ustaapp/core/services/app_data_service.dart';
import 'package:ustaapp/core/theme/app_theme.dart';

class AdminBannersTab extends StatefulWidget {
  const AdminBannersTab({super.key});

  @override
  State<AdminBannersTab> createState() => _AdminBannersTabState();
}

class _AdminBannersTabState extends State<AdminBannersTab> {
  List<BannerModel> _banners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    setState(() => _isLoading = true);
    final list = await AppDataService.instance.getBanners();
    if (mounted) {
      setState(() {
        _banners = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBannerStatus(BannerModel banner) async {
    final updated = _banners.map((b) {
      if (b.id == banner.id) {
        return b.copyWith(isActive: !b.isActive);
      }
      return b;
    }).toList();

    setState(() => _banners = updated);
    await AppDataService.instance.saveBanners(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${banner.title} durumu güncellendi.'),
          backgroundColor: banner.isActive ? Colors.redAccent : const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _deleteBanner(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Bannerı Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Bu reklam/kampanya bannerını silmek istediğinize emin misiniz?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final updated = _banners.where((b) => b.id != id).toList();
      setState(() => _banners = updated);
      await AppDataService.instance.saveBanners(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner başarıyla silindi.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showAddEditBannerDialog([BannerModel? existing]) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final subtitleController = TextEditingController(text: existing?.subtitle ?? '');
    final imageController = TextEditingController(text: existing?.imageUrl ?? '');
    final deepLinkController = TextEditingController(text: existing?.deepLink ?? 'cat-kombi');
    final badgeController = TextEditingController(text: existing?.badge ?? 'KAMPANYA');
    String selectedGradient = existing?.bgGradient ?? 'orange';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            existing == null ? 'Yeni Reklam & Kampanya Bannerı Ekle' : 'Bannerı Düzenle',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Kampanya Başlığı',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'Örn: Kombi ve Klima Bakımında %20 İndirim!',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: subtitleController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Açıklama / Alt Metin',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'Örn: Yetkili ve MYK belgeli uzman ustalar ile kışa hazır olun.',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: imageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Görsel URL Adresi (Unsplash vb.)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'https://images.unsplash.com/...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: badgeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Etiket / Rozet',
                            labelStyle: const TextStyle(color: Colors.white70),
                            hintText: 'Örn: SEZON FIRSATI',
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: deepLinkController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Kategori / Yönlendirme ID',
                            labelStyle: const TextStyle(color: Colors.white70),
                            hintText: 'cat-kombi / cat-cilingir',
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Tema Gradyanı', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildGradientRadio('orange', 'Turuncu', const Color(0xFFEA580C), selectedGradient, (v) => setDlgState(() => selectedGradient = v)),
                      const SizedBox(width: 8),
                      _buildGradientRadio('blue', 'Mavi', const Color(0xFF0284C7), selectedGradient, (v) => setDlgState(() => selectedGradient = v)),
                      const SizedBox(width: 8),
                      _buildGradientRadio('emerald', 'Zümrüt', const Color(0xFF10B981), selectedGradient, (v) => setDlgState(() => selectedGradient = v)),
                      const SizedBox(width: 8),
                      _buildGradientRadio('purple', 'Mor', const Color(0xFF8B5CF6), selectedGradient, (v) => setDlgState(() => selectedGradient = v)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                final newBanner = BannerModel(
                  id: existing?.id ?? 'banner_${DateTime.now().millisecondsSinceEpoch}',
                  title: title,
                  subtitle: subtitleController.text.trim(),
                  imageUrl: imageController.text.trim().isNotEmpty
                      ? imageController.text.trim()
                      : 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&w=800&q=80',
                  badge: badgeController.text.trim().toUpperCase(),
                  deepLink: deepLinkController.text.trim(),
                  bgGradient: selectedGradient,
                  isActive: existing?.isActive ?? true,
                  clickCount: existing?.clickCount ?? 0,
                  impressionCount: existing?.impressionCount ?? 0,
                  createdAt: existing?.createdAt ?? DateTime.now(),
                );

                List<BannerModel> updated;
                if (existing != null) {
                  updated = _banners.map((b) => b.id == existing.id ? newBanner : b).toList();
                } else {
                  updated = [newBanner, ..._banners];
                }

                setState(() => _banners = updated);
                await AppDataService.instance.saveBanners(updated);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.ustaPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Kaydet ve Yayınla', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientRadio(String key, String label, Color color, String current, ValueChanged<String> onSelect) {
    final isSel = key == current;
    return InkWell(
      onTap: () => onSelect(key),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isSel ? 0.35 : 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSel ? color : Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isSel ? Colors.white : Colors.white70, fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _banners.where((b) => b.isActive).length;
    final totalClicks = _banners.fold<int>(0, (sum, b) => sum + b.clickCount);
    final totalImpressions = _banners.fold<int>(0, (sum, b) => sum + b.impressionCount);
    final ctr = totalImpressions > 0 ? ((totalClicks / totalImpressions) * 100).toStringAsFixed(1) : '0.0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Üst İstatistik Kartları
        Row(
          children: [
            _buildStatCard('Aktif Bannerlar', '$activeCount / ${_banners.length}', Icons.view_carousel_rounded, const Color(0xFFEA580C)),
            const SizedBox(width: 16),
            _buildStatCard('Toplam Görüntülenme', '$totalImpressions', Icons.visibility_rounded, const Color(0xFF0284C7)),
            const SizedBox(width: 16),
            _buildStatCard('Toplam Tıklanma', '$totalClicks', Icons.touch_app_rounded, const Color(0xFF10B981)),
            const SizedBox(width: 16),
            _buildStatCard('Tıklama Oranı (CTR)', '%$ctr', Icons.auto_graph_rounded, const Color(0xFF8B5CF6)),
          ],
        ),
        const SizedBox(height: 24),

        // Başlık ve Ekle Butonu
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reklam & Kampanya Bannerları',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Müşteri ana sayfasında ve arama akışında gösterilen dinamik sponsorlu bannerlar.',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddEditBannerDialog(),
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
              label: const Text('Yeni Banner Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.ustaPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator(color: AppTheme.ustaPrimary)))
        else if (_banners.isEmpty)
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20)),
            child: const Center(
              child: Text('Henüz eklenmiş kampanya bannerı bulunmuyor.', style: TextStyle(color: Colors.white60)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _banners.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (ctx, idx) {
              final b = _banners[idx];
              return _buildBannerCard(b);
            },
          ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerCard(BannerModel b) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: b.isActive ? const Color(0xFF334155) : Colors.white10),
      ),
      child: Row(
        children: [
          // Banner Önizleme Görseli
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
            child: Container(
              width: 220,
              height: 120,
              color: const Color(0xFF0F172A),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    b.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_rounded, color: Colors.white30, size: 40),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.ustaPrimary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        b.badge,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),

          // Bilgiler
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.title,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: b.isActive ? const Color(0xFF10B981).withValues(alpha: 0.15) : Colors.white12,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: b.isActive ? const Color(0xFF10B981) : Colors.white30),
                        ),
                        child: Text(
                          b.isActive ? 'Yayında' : 'Pasif',
                          style: TextStyle(
                            color: b.isActive ? const Color(0xFF10B981) : Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    b.subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.link_rounded, color: Colors.white38, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Hedef: ${b.deepLink ?? 'Yok'}',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      const SizedBox(width: 20),
                      const Icon(Icons.touch_app_rounded, color: Colors.white38, size: 16),
                      const SizedBox(width: 4),
                      Text('${b.clickCount} Tık', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      const SizedBox(width: 20),
                      const Icon(Icons.visibility_rounded, color: Colors.white38, size: 16),
                      const SizedBox(width: 4),
                      Text('${b.impressionCount} Görüntülenme', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Aksiyonlar
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Row(
              children: [
                IconButton(
                  tooltip: b.isActive ? 'Bannerı Durdur' : 'Bannerı Yayınla',
                  icon: Icon(
                    b.isActive ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                    color: b.isActive ? Colors.amber : const Color(0xFF10B981),
                    size: 28,
                  ),
                  onPressed: () => _toggleBannerStatus(b),
                ),
                IconButton(
                  tooltip: 'Düzenle',
                  icon: const Icon(Icons.edit_rounded, color: Color(0xFF0284C7)),
                  onPressed: () => _showAddEditBannerDialog(b),
                ),
                IconButton(
                  tooltip: 'Sil',
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () => _deleteBanner(b.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
