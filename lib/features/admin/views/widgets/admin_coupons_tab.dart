import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ustaapp/core/models/coupon_model.dart';
import 'package:ustaapp/core/services/app_data_service.dart';

class AdminCouponsTab extends StatefulWidget {
  const AdminCouponsTab({super.key});

  @override
  State<AdminCouponsTab> createState() => _AdminCouponsTabState();
}

class _AdminCouponsTabState extends State<AdminCouponsTab> {
  bool _isLoading = true;
  List<CouponModel> _coupons = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    setState(() => _isLoading = true);
    try {
      final list = await AppDataService.instance.getCoupons();
      if (mounted) {
        setState(() {
          _coupons = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleCoupon(CouponModel coupon) async {
    final updated = coupon.copyWith(isActive: !coupon.isActive);
    final idx = _coupons.indexWhere((c) => c.id == coupon.id);
    if (idx != -1) {
      setState(() {
        _coupons[idx] = updated;
      });
      await AppDataService.instance.saveCoupons(_coupons);
    }
  }

  Future<void> _deleteCoupon(CouponModel coupon) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Kuponu Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          '\'${coupon.code}\' kodlu kuponu kalıcı olarak silmek istediğinize emin misiniz?',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _coupons.removeWhere((c) => c.id == coupon.id);
      });
      await AppDataService.instance.saveCoupons(_coupons);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${coupon.code} kuponu silindi'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showAddCouponDialog([CouponModel? existing]) {
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final amountCtrl = TextEditingController(text: existing != null ? existing.discountAmount.toStringAsFixed(0) : '50');
    final minOrderCtrl = TextEditingController(text: existing != null ? existing.minOrderAmount.toStringAsFixed(0) : '200');
    final maxUsesCtrl = TextEditingController(text: existing != null ? existing.maxUses.toString() : '500');
    String discountType = existing?.discountType ?? 'fixed';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.confirmation_number_rounded, color: Color(0xFFEA580C), size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                existing == null ? 'Yeni İndirim Kuponu' : 'Kuponu Düzenle',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('KUPON KODU', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      hintText: 'Örn: YENIYIL2026',
                      hintStyle: const TextStyle(color: Color(0xFF475569)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.tag_rounded, color: Color(0xFFEA580C)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('BAŞLIK / KAMPANYA TANIMI', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      hintText: 'Örn: Tüm Tesisat İşlerinde 100 ₺ İndirim',
                      hintStyle: const TextStyle(color: Color(0xFF475569)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('İNDİRİM TİPİ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setDialogState(() => discountType = 'fixed'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: discountType == 'fixed' ? const Color(0xFFEA580C).withOpacity(0.2) : const Color(0xFF0F172A),
                              border: Border.all(
                                color: discountType == 'fixed' ? const Color(0xFFEA580C) : const Color(0xFF334155),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.money_rounded, size: 18, color: discountType == 'fixed' ? const Color(0xFFEA580C) : const Color(0xFF94A3B8)),
                                const SizedBox(width: 8),
                                Text('Sabit Tutar (₺)', style: TextStyle(color: discountType == 'fixed' ? Colors.white : const Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => setDialogState(() => discountType = 'percentage'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: discountType == 'percentage' ? const Color(0xFFEA580C).withOpacity(0.2) : const Color(0xFF0F172A),
                              border: Border.all(
                                color: discountType == 'percentage' ? const Color(0xFFEA580C) : const Color(0xFF334155),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.percent_rounded, size: 18, color: discountType == 'percentage' ? const Color(0xFFEA580C) : const Color(0xFF94A3B8)),
                                const SizedBox(width: 8),
                                Text('Yüzde (%)', style: TextStyle(color: discountType == 'percentage' ? Colors.white : const Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(discountType == 'fixed' ? 'İNDİRİM TUTARI (₺)' : 'İNDİRİM YÜZDESİ (%)', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: amountCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('MİN. SİPARİŞ (₺)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: minOrderCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF0F172A),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  const Text('TOPLAM KULLANIM LİMİTİ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: maxUsesCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      hintText: 'Örn: 500',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final code = codeCtrl.text.trim().toUpperCase();
                final title = titleCtrl.text.trim();
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                final minOrder = double.tryParse(minOrderCtrl.text.trim()) ?? 0.0;
                final maxUses = int.tryParse(maxUsesCtrl.text.trim()) ?? 100;

                if (code.isEmpty || title.isEmpty || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lütfen kupon kodu, tanım ve indirim tutarını eksiksiz girin.')),
                  );
                  return;
                }

                if (existing == null) {
                  final newCoupon = CouponModel(
                    id: 'coupon_${DateTime.now().millisecondsSinceEpoch}',
                    code: code,
                    title: title,
                    discountType: discountType,
                    discountAmount: amount,
                    minOrderAmount: minOrder,
                    maxUses: maxUses,
                    usedCount: 0,
                    isActive: true,
                    validUntil: DateTime.now().add(const Duration(days: 90)),
                  );
                  setState(() => _coupons.insert(0, newCoupon));
                } else {
                  final updated = existing.copyWith(
                    code: code,
                    title: title,
                    discountType: discountType,
                    discountAmount: amount,
                    minOrderAmount: minOrder,
                    maxUses: maxUses,
                  );
                  final idx = _coupons.indexWhere((c) => c.id == existing.id);
                  if (idx != -1) setState(() => _coupons[idx] = updated);
                }

                await AppDataService.instance.saveCoupons(_coupons);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(existing == null ? 'Kuponu Oluştur' : 'Kaydet', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _coupons.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.code.toLowerCase().contains(q) || c.title.toLowerCase().contains(q);
    }).toList();

    final activeCount = _coupons.where((c) => c.isActive).length;
    final totalUsed = _coupons.fold<int>(0, (sum, c) => sum + c.usedCount);
    final totalDiscountEst = _coupons.fold<double>(
      0,
      (sum, c) => sum + (c.usedCount * (c.discountType == 'fixed' ? c.discountAmount : 45.0)),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEA580C)))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst Başlık & Buton
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Kupon & Promosyon Yönetimi',
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Kullanıcı indirim kodları, kullanım limitleri ve aktif kampanyalar',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showAddCouponDialog(),
                        icon: const Icon(Icons.add_rounded, color: Colors.white),
                        label: const Text('Yeni Kupon Tanımla', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // KPI Kartları
                  Row(
                    children: [
                      _buildKpiCard('Aktif Kuponlar', '$activeCount Adet', Icons.check_circle_outline_rounded, const Color(0xFF10B981)),
                      const SizedBox(width: 16),
                      _buildKpiCard('Toplam Kullanım', '$totalUsed Kez', Icons.trending_up_rounded, const Color(0xFF0284C7)),
                      const SizedBox(width: 16),
                      _buildKpiCard('İndirim Hacmi (Tahmini)', '₺ ${totalDiscountEst.toStringAsFixed(0)}', Icons.savings_outlined, const Color(0xFFF59E0B)),
                      const SizedBox(width: 16),
                      _buildKpiCard('Kayıtlı Kupon', '${_coupons.length} Kupon', Icons.confirmation_number_outlined, const Color(0xFF8B5CF6)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Arama ve Filtre
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                        hintText: 'Kupon kodu veya başlık ara...',
                        hintStyle: TextStyle(color: Color(0xFF64748B)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Liste
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.confirmation_number_outlined, size: 56, color: Color(0xFF475569)),
                                SizedBox(height: 12),
                                Text('Kayıtlı kupon bulunamadı', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return _buildCouponCard(item);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponCard(CouponModel coupon) {
    final progress = coupon.maxUses > 0 ? (coupon.usedCount / coupon.maxUses).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: coupon.isActive ? const Color(0xFF334155) : const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          // Kupon Kodu Rozeti
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: coupon.isActive ? const Color(0xFFEA580C).withOpacity(0.15) : const Color(0xFF334155),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: coupon.isActive ? const Color(0xFFEA580C) : const Color(0xFF475569),
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  coupon.code,
                  style: TextStyle(
                    color: coupon.isActive ? const Color(0xFFEA580C) : const Color(0xFF94A3B8),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: coupon.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${coupon.code} panoya kopyalandı!'), duration: const Duration(seconds: 1)),
                    );
                  },
                  child: Icon(Icons.copy_rounded, size: 16, color: coupon.isActive ? const Color(0xFFEA580C) : const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Başlık ve Açıklama
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coupon.title,
                  style: TextStyle(
                    color: coupon.isActive ? Colors.white : const Color(0xFF94A3B8),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        coupon.discountType == 'fixed'
                            ? '${coupon.discountAmount.toStringAsFixed(0)} ₺ İndirim'
                            : '%${coupon.discountAmount.toStringAsFixed(0)} İndirim',
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Min: ₺ ${coupon.minOrderAmount.toStringAsFixed(0)}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Kullanım İlerlemesi
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kullanım Durumu', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    Text('${coupon.usedCount} / ${coupon.maxUses}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFF0F172A),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress > 0.8 ? const Color(0xFFEF4444) : const Color(0xFFEA580C),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Durum Switch
          Row(
            children: [
              Switch(
                value: coupon.isActive,
                activeColor: const Color(0xFF10B981),
                inactiveTrackColor: const Color(0xFF334155),
                onChanged: (_) => _toggleCoupon(coupon),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF94A3B8), size: 20),
                onPressed: () => _showAddCouponDialog(coupon),
                tooltip: 'Düzenle',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                onPressed: () => _deleteCoupon(coupon),
                tooltip: 'Sil',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
