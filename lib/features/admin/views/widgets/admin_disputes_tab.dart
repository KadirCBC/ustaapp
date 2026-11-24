import 'package:flutter/material.dart';
import 'package:ustaapp/core/models/dispute_model.dart';
import 'package:ustaapp/core/services/app_data_service.dart';

class AdminDisputesTab extends StatefulWidget {
  const AdminDisputesTab({super.key});

  @override
  State<AdminDisputesTab> createState() => _AdminDisputesTabState();
}

class _AdminDisputesTabState extends State<AdminDisputesTab> {
  bool _isLoading = true;
  List<DisputeModel> _disputes = [];
  String _selectedFilter = 'all'; // all, bekliyor, cozuldu
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDisputes();
  }

  Future<void> _loadDisputes() async {
    setState(() => _isLoading = true);
    try {
      final list = await AppDataService.instance.getDisputes();
      if (mounted) {
        setState(() {
          _disputes = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showResolveDialog(DisputeModel dispute, String action) async {
    final noteCtrl = TextEditingController();
    String actionTitle = '';
    Color actionColor = const Color(0xFF10B981);

    if (action == 'musteriye_iade') {
      actionTitle = 'Müşteriye İade Et';
      actionColor = const Color(0xFF0284C7);
    } else if (action == 'ustaya_odendi') {
      actionTitle = 'Ustaya Aktar (Onayla)';
      actionColor = const Color(0xFF10B981);
    } else {
      actionTitle = 'Talebi Reddet';
      actionColor = const Color(0xFFEF4444);
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: actionColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.gavel_rounded, color: actionColor, size: 22),
            ),
            const SizedBox(width: 12),
            Text(actionTitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Çağrı: ${dispute.cagriId} • Tutar: ₺ ${dispute.amount.toStringAsFixed(0)}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Şikayet Nedeni:\n${dispute.reason}',
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              const Text('HAKEM HEYETİ KARAR NOTU (ZORUNLU)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  hintText: 'Karar gerekçesini ve taraflara iletilecek açıklamayı yazın...',
                  hintStyle: const TextStyle(color: Color(0xFF475569)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: actionColor),
            onPressed: () {
              if (noteCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lütfen hakem heyeti karar notunu giriniz.')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Kararı Uygula', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AppDataService.instance.resolveDispute(dispute.id, action, noteCtrl.text.trim());
      await _loadDisputes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${dispute.cagriId} uyuşmazlığı karara bağlandı.'),
            backgroundColor: actionColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _disputes.where((d) {
      if (_selectedFilter == 'bekliyor' && d.status != 'bekliyor') return false;
      if (_selectedFilter == 'cozuldu' && d.status == 'bekliyor') return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return d.cagriId.toLowerCase().contains(q) ||
          d.customerName.toLowerCase().contains(q) ||
          d.ustaName.toLowerCase().contains(q) ||
          d.reason.toLowerCase().contains(q);
    }).toList();

    final pendingCount = _disputes.where((d) => d.status == 'bekliyor').length;
    final refundedCount = _disputes.where((d) => d.status == 'musteriye_iade').length;
    final approvedCount = _disputes.where((d) => d.status == 'ustaya_odendi').length;
    final blockedAmount = _disputes.where((d) => d.status == 'bekliyor').fold<double>(0, (sum, d) => sum + d.amount);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEA580C)))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst Başlık
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Uyuşmazlık & Şikayet Masası',
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Müşteri ile usta arasındaki anlaşmazlıkları inceleyin, provizyonu çözün veya iade edin',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: _loadDisputes,
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                        tooltip: 'Yenile',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // KPI Kartları
                  Row(
                    children: [
                      _buildKpiCard('Bekleyen İncelemeler', '$pendingCount Dosya', Icons.hourglass_top_rounded, const Color(0xFFEF4444)),
                      const SizedBox(width: 16),
                      _buildKpiCard('Askıdaki Tutar', '₺ ${blockedAmount.toStringAsFixed(0)}', Icons.lock_clock_outlined, const Color(0xFFF59E0B)),
                      const SizedBox(width: 16),
                      _buildKpiCard('Müşteriye İadeler', '$refundedCount Dosya', Icons.keyboard_return_rounded, const Color(0xFF0284C7)),
                      const SizedBox(width: 16),
                      _buildKpiCard('Ustaya Onaylananlar', '$approvedCount Dosya', Icons.verified_user_outlined, const Color(0xFF10B981)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Filtre ve Arama
                  Row(
                    children: [
                      Expanded(
                        child: Container(
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
                              hintText: 'Çağrı ID, Müşteri, Usta veya Şikayet ara...',
                              hintStyle: TextStyle(color: Color(0xFF64748B)),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildFilterChip('Tümü (${_disputes.length})', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Bekleyenler ($pendingCount)', 'bekliyor', isAlert: pendingCount > 0),
                      const SizedBox(width: 8),
                      _buildFilterChip('Karara Bağlananlar', 'cozuldu'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Liste
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.gavel_rounded, size: 56, color: Color(0xFF475569)),
                                SizedBox(height: 12),
                                Text('Kayıtlı uyuşmazlık dosyası bulunamadı', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return _buildDisputeCard(item);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String label, String value, {bool isAlert = false}) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isAlert ? const Color(0xFFEF4444) : const Color(0xFFEA580C))
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isAlert ? const Color(0xFFEF4444).withOpacity(0.5) : const Color(0xFF334155)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isAlert ? const Color(0xFFEF4444) : const Color(0xFF94A3B8)),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
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

  Widget _buildDisputeCard(DisputeModel item) {
    Color badgeColor = const Color(0xFFF59E0B);
    String statusText = 'İnceleme Bekliyor';

    if (item.status == 'musteriye_iade') {
      badgeColor = const Color(0xFF0284C7);
      statusText = 'Müşteriye İade Edildi';
    } else if (item.status == 'ustaya_odendi') {
      badgeColor = const Color(0xFF10B981);
      statusText = 'Ustaya Ödendi (Çözüldü)';
    } else if (item.status == 'reddedildi') {
      badgeColor = const Color(0xFFEF4444);
      statusText = 'Şikayet Reddedildi';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.status == 'bekliyor' ? const Color(0xFFEF4444).withOpacity(0.4) : const Color(0xFF334155),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.cagriId,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: badgeColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              Text(
                '₺ ${item.amount.toStringAsFixed(0)} Provizyon',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Taraflar
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MÜŞTERİ', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(item.customerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(item.customerPhone, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('USTA', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(item.ustaName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(item.ustaPhone, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Şikayet Metni
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ŞİKAYET DETAYI:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(item.reason, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4)),
                if (item.resolutionNote != null && item.resolutionNote!.isNotEmpty) ...[
                  const Divider(color: Color(0xFF334155), height: 16),
                  Text('HAKEM HEYETİ KARARI: ${item.resolutionNote}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Karar Aksiyon Butonları
          if (item.status == 'bekliyor')
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showResolveDialog(item, 'reddedildi'),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Şikayeti Reddet'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showResolveDialog(item, 'musteriye_iade'),
                  icon: const Icon(Icons.keyboard_return_rounded, size: 16, color: Colors.white),
                  label: const Text('Müşteriye İade Et', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showResolveDialog(item, 'ustaya_odendi'),
                  icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  label: const Text('Ustaya Aktar (Onayla)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
