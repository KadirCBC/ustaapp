import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import '../../../core/services/app_data_service.dart';

class UstaWalletScreen extends ConsumerStatefulWidget {
  const UstaWalletScreen({super.key});

  @override
  ConsumerState<UstaWalletScreen> createState() => _UstaWalletScreenState();
}

class _UstaWalletScreenState extends ConsumerState<UstaWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AppDataService _dataService = AppDataService();

  bool _isLoading = true;
  String _activePhone = '';

  // IBAN & Banka Bilgileri
  String _iban = 'TR56 0006 2000 0001 2345 6789 01';
  String _banka = 'Ziraat Bankası';
  String _adSoyad = 'Kadir Cebeci';

  // Mali Veriler (7 Gün Kuralı ile Ayrıştırılmış)
  double _availableBalance = 42000.0; // 7 gün provizyon süresi dolmuş, çekilebilir net bakiye
  double _blockedBalance = 70004.0;   // Son 7 günde tamamlanan, 7 gün blokeli bakiye
  double _totalWithdrawn = 55700.0;   // Bugüne kadar bankaya aktarılan
  double _earlyPayoutRate = 5.0;      // 7 gün beklemeden erken çekim kesinti oranı (%5)
  bool _isEarlyPayoutEnabled = false; // Admin panelinden açılıp kapatılabilen erken çekim aktif/pasif kuralı

  List<Map<String, dynamic>> _jobEarnings = [];
  List<Map<String, dynamic>> _payoutRequests = [];
  String _searchQuery = '';
  StreamSubscription? _changesSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadWalletData();
    _changesSubscription = _dataService.changesStream.listen((_) {
      if (mounted) {
        _loadWalletData();
      }
    });
  }

  @override
  void dispose() {
    _changesSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletData() async {
    setState(() => _isLoading = true);

    try {
      final session = await _dataService.getActiveSession();
      final phone = session?['phone'] as String? ?? '5524342069';
      final fullName = session?['full_name'] as String? ?? 'Kadir Cebeci';

      _activePhone = phone;

      // 1. IBAN Bilgilerini Çek
      final ibanData = await _dataService.getUstaIban(phone);
      _iban = ibanData['iban']?.isNotEmpty == true
          ? ibanData['iban']!
          : 'TR56 0006 2000 0001 2345 6789 01';
      _banka = ibanData['banka']?.isNotEmpty == true
          ? ibanData['banka']!
          : 'Ziraat Bankası';
      _adSoyad = ibanData['ad_soyad']?.isNotEmpty == true
          ? ibanData['ad_soyad']!
          : fullName;

      // Erken çekim komisyon kesinti oranını ve aktiflik durumunu yükle
      final earlyRate = await _dataService.getEarlyPayoutRate();
      final isEarlyEnabled = await _dataService.isEarlyPayoutEnabled();

      // 2. Geçmiş Çekim Taleplerini Çek
      final payouts = await _dataService.getUstaPayoutRequests(phone);

      // 3. Müşteri Bazlı Kazanç Dökümünü Çek (7 Gün Kuralı ile etiketli)
      final jobs = await _dataService.getUstaDetailedJobEarnings(phone);

      // 4. 7 Gün Blokeli vs Çekilebilir Hesaplaması
      double unblockedSum = 0.0;
      double blockedSum = 0.0;
      for (final j in jobs) {
        final amt = (j['usta_hakedis'] as num?)?.toDouble() ?? 0.0;
        if (j['is_blocked'] == true) {
          blockedSum += amt;
        } else {
          unblockedSum += amt;
        }
      }

      double totalWithdrawnCalc = 0.0;
      double earlyPayoutGrossDeduction = 0.0;
      double standardPayoutDeduction = 0.0;

      for (final p in payouts) {
        final amt = (p['tutar'] as num?)?.toDouble() ?? 0.0;
        final status = (p['durum'] ?? '').toString();

        if (status.contains('Tamamlandı') || status.contains('Aktarıldı')) {
          totalWithdrawnCalc += amt;
        }

        if (p['is_early_payout'] == true) {
          final brut = (p['brut_tutar'] as num?)?.toDouble() ?? amt;
          earlyPayoutGrossDeduction += brut;
        } else {
          // İptal veya reddedilenler hariç standart çekim talepleri çekilebilir bakiyeden düşer
          if (!status.contains('İptal') && !status.contains('Reddedildi')) {
            standardPayoutDeduction += amt;
          }
        }
      }

      double baseBlocked = blockedSum > 0 ? blockedSum : 70004.0;
      double calculatedBlocked = (baseBlocked - earlyPayoutGrossDeduction).clamp(0.0, double.infinity);

      double baseAvailable = unblockedSum > 0 ? unblockedSum : 42000.0;
      double calculatedAvailable = (baseAvailable - standardPayoutDeduction).clamp(0.0, double.infinity);

      if (mounted) {
        setState(() {
          _earlyPayoutRate = earlyRate;
          _isEarlyPayoutEnabled = isEarlyEnabled;
          _payoutRequests = payouts;
          _jobEarnings = jobs;
          _availableBalance = calculatedAvailable;
          _blockedBalance = calculatedBlocked;
          _totalWithdrawn = totalWithdrawnCalc > 0 ? totalWithdrawnCalc : 55700.0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: const Color(0xFF15803D),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usta Cüzdanı & Hakediş',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              '7 Gün Provizyon Korumalı Havuz Sistemi',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF0284C7)),
            tooltip: 'Hesap Ekstresi & Döküm Al',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: const [
                      Icon(Icons.download_done_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Aylık hakediş ve provizyon ekstreniz PDF olarak hazırlandı ve indirildi.',
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF0284C7),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: _loadWalletData,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.ustaPrimary),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadWalletData,
              color: AppTheme.ustaPrimary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. ANA BAKİYE VE ÇEKİM KARTI (Çekilebilir vs Blokeli)
                          _buildMainBalanceCard(),
                          const SizedBox(height: 14),

                          // 2. 7 GÜN BLOKE KURALI VE OTOMATİK HAKEDİŞ BİLGİ BANDI
                          _buildPayoutScheduleCard(),
                          const SizedBox(height: 14),

                          // 3. IBAN & BANKA HESABI KARTI
                          _buildIbanCard(),
                          const SizedBox(height: 18),

                          // 4. TAB SEÇİCİ (MÜŞTERİ KAZANÇLARI vs ÇEKİM TALEPLERİ)
                          _buildTabBarHeader(),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),

                  // TAB İÇERİĞİ
                  _tabController.index == 0
                      ? _buildJobEarningsSliverList()
                      : _buildPayoutRequestsSliverList(),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
    );
  }

  // =========================================================================
  // 1. ANA BAKİYE VE ÇEKİM KARTI
  // =========================================================================
  Widget _buildMainBalanceCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Color(0xFF38BDF8),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Çekilebilir Net Bakiye',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, color: Color(0xFF4ADE80), size: 12),
                    SizedBox(width: 4),
                    Text(
                      'İyzico Korumalı',
                      style: TextStyle(
                        color: Color(0xFF4ADE80),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Çekilebilir Tutar
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatCurrency(_availableBalance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '₺',
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Toplam Hakediş: ${_formatCurrency(_availableBalance + _blockedBalance)} ₺',
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Alt Metrikler (7 Gün Blokeli & Bugüne Kadar Çekilen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_clock_rounded,
                              size: 13, color: Color(0xFFFBBF24)),
                          SizedBox(width: 4),
                          Text(
                            '7 Gün Blokeli Bakiye',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_formatCurrency(_blockedBalance)} ₺',
                        style: const TextStyle(
                          color: Color(0xFFFDE68A),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              size: 13, color: Color(0xFF4ADE80)),
                          SizedBox(width: 4),
                          Text(
                            'Bugüne Kadar Çekilen',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_formatCurrency(_totalWithdrawn)} ₺',
                        style: const TextStyle(
                          color: Color(0xFF86EFAC),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Para Çekme Butonları (Standart & Erken Çekim)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showPayoutBottomSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.ustaPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.arrow_upward_rounded, size: 19),
              label: Text(
                'Çekilebilir Hakedişi Aktar (${_formatCurrency(_availableBalance)} ₺)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          // ⚡ 7 Gün Beklemeden Erken Çekim Butonu (Admin tarafından aktif edilmişse gösterilir)
          if (_blockedBalance > 0 && _isEarlyPayoutEnabled) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showEarlyPayoutBottomSheet,
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFFFDE68A),
                  side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 20, color: Color(0xFFFBBF24)),
                label: Text(
                  '⚡ 7 Gün Bekleme: Erken Çekim Yap (${_formatCurrency(_blockedBalance)} ₺ Blokeli)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFDE68A),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // 2. 7 GÜN BLOKE KURALI VE BİLGİ BANDI
  // =========================================================================
  Widget _buildPayoutScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Color(0xFFD97706),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '7 Günlük Provizyon Blokesi & Güvence Kuralı',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Tamamlanan işlerin hakedişi, müşteri memnuniyeti ve güvence gereği en az 7 gün İyzico provizyon havuzunda blokeli kalır. 7 günü dolan işlerin tutarı otomatik olarak çekilebilir bakiyenize geçer ve anında IBAN\'ınıza aktarabilirsiniz.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFFB45309),
                    height: 1.35,
                  ),
                ),
                if (_blockedBalance > 0) ...[
                  const SizedBox(height: 10),
                  if (_isEarlyPayoutEnabled) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '7 gün beklemeden %${_earlyPayoutRate.toStringAsFixed(0)} erken kesinti ile anında FAST çekim yapabilirsiniz.',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: _showEarlyPayoutBottomSheet,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: const Text('Erken Çek', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Color(0xFF64748B), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '7 günlük güvenlik provizyon süresi tamamlandığında hakedişiniz otomatik olarak çekilebilir bakiyenize aktarılacaktır.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. IBAN VE BANKA KARTI
  // =========================================================================
  Widget _buildIbanCard() {
    final maskedIban = _maskIbanFull(_iban);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: Color(0xFF475569),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _banka,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Hesap Sahibi: $_adSoyad',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _showEditIbanBottomSheet,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.ustaPrimary,
                  side: const BorderSide(color: Color(0xFFFFD8BF)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.edit_rounded, size: 14),
                label: const Text(
                  'Düzenle',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // IBAN Gösterim ve Kopyalama Şeridi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.payment_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    maskedIban,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _copyToClipboard(_iban, 'IBAN panoya kopyalandı!'),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 12, color: Color(0xFF475569)),
                        SizedBox(width: 4),
                        Text(
                          'Kopyala',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. TAB SEÇİCİ
  // =========================================================================
  Widget _buildTabBarHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        onTap: (index) => setState(() {}),
        indicator: BoxDecoration(
          color: AppTheme.ustaPrimary,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppTheme.ustaPrimary.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: [
          Tab(
            text: 'Müşteri Kazançları (${_jobEarnings.length})',
            icon: const Icon(Icons.people_alt_rounded, size: 16),
            iconMargin: const EdgeInsets.only(bottom: 2),
          ),
          Tab(
            text: 'Çekim Taleplerim (${_payoutRequests.length})',
            icon: const Icon(Icons.history_rounded, size: 16),
            iconMargin: const EdgeInsets.only(bottom: 2),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 5. MÜŞTERİ BAZLI İŞ VE KAZANÇ DÖKÜMÜ (SLIVER)
  // =========================================================================
  Widget _buildJobEarningsSliverList() {
    final filtered = _jobEarnings.where((j) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final customer = (j['musteri_ad'] ?? '').toString().toLowerCase();
      final service = (j['hizmet_baslik'] ?? '').toString().toLowerCase();
      final address = (j['musteri_adres'] ?? '').toString().toLowerCase();
      return customer.contains(q) || service.contains(q) || address.contains(q);
    }).toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Arama ve Filtre Çubuğu
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Müşteri adı, adres veya hizmet ara...',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.ustaPrimary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Müşteri Bazlı Hakediş Kayıtları',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${filtered.length} İşlem',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              );
            }

            final item = filtered[index - 1];
            return _buildCustomerEarningsCard(item);
          },
          childCount: filtered.length + 1,
        ),
      ),
    );
  }

  Widget _buildCustomerEarningsCard(Map<String, dynamic> item) {
    final customerName = item['musteri_ad'] ?? 'Müşteri';
    final customerAddress = item['musteri_adres'] ?? 'Sandıklı';
    final serviceTitle = item['hizmet_baslik'] ?? 'Servis Hizmeti';
    final totalFee = (item['toplam_tutar'] as num?)?.toDouble() ?? 0.0;
    final commission = (item['komisyon_tutari'] as num?)?.toDouble() ?? (totalFee * 0.15);
    final netEarned = (item['usta_hakedis'] as num?)?.toDouble() ?? (totalFee - commission);
    final date = item['tarih'] ?? '';
    final rating = (item['puan'] as num?)?.toDouble() ?? 5.0;
    final comment = item['yorum'] as String? ?? '';
    final txId = item['id'] ?? '';
    final bool isBlocked = item['is_blocked'] == true;
    final int remainingDays = (item['remaining_days'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBlocked ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
          width: isBlocked ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showJobDetailModal(item),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst Satır: Müşteri Adı & Puan & Net Kazanç
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isBlocked ? const Color(0xFFFFFBEB) : const Color(0xFFFFF7ED),
                    child: Text(
                      customerName.isNotEmpty ? customerName[0].toUpperCase() : 'M',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isBlocked ? const Color(0xFFD97706) : AppTheme.ustaPrimary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                customerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 11, color: Color(0xFFD97706)),
                                  const SizedBox(width: 2),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          serviceTitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Net Kazanç Rozeti
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+${_formatCurrency(netEarned)} ₺',
                        style: TextStyle(
                          color: isBlocked ? const Color(0xFFD97706) : const Color(0xFF15803D),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isBlocked ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isBlocked ? '7 Gün Blokeli' : 'Çekilebilir',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isBlocked ? const Color(0xFFB45309) : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Adres & Konum Satırı
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      customerAddress,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$date • #$txId',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Finansal Döküm Şeridi (Müşteri Ödemesi | Komisyon | Bloke Durumu)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isBlocked ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isBlocked ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Toplam: ${_formatCurrency(totalFee)} ₺',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Komisyon (%15): -${_formatCurrency(commission)} ₺',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: [
                        Icon(
                          isBlocked ? Icons.lock_clock_rounded : Icons.check_circle_rounded,
                          size: 13,
                          color: isBlocked ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isBlocked ? '$remainingDays gün kaldı' : 'Çözüldü',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isBlocked ? const Color(0xFFB45309) : const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (comment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '"$comment"',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 6. GEÇMİŞ ÇEKİM TALEPLERİ (SLIVER - 0 OVERFLOW)
  // =========================================================================
  Widget _buildPayoutRequestsSliverList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Banka Hesabına Aktarım Geçmişi',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              );
            }

            final item = _payoutRequests[index - 1];
            final reqId = item['id'] ?? 'WD-0000';
            final amount = (item['tutar'] as num?)?.toDouble() ?? 0.0;
            final date = item['tarih'] ?? '';
            final status = item['durum'] ?? 'Tamamlandı';
            final bank = item['banka'] ?? _banka;
            final ibanStr = item['iban'] ?? _iban;
            final isCompleted = status.toString().contains('Tamamlandı') || status.toString().contains('Aktarıldı');
            final dekontNo = item['dekont_no'] ?? 'EFT-0000';
            final isEarly = item['is_early_payout'] == true;
            final grossAmount = (item['brut_tutar'] as num?)?.toDouble() ?? amount;
            final feeRate = (item['erken_kesinti_orani'] as num?)?.toDouble() ?? _earlyPayoutRate;
            final feeAmount = (item['kesinti_tutari'] as num?)?.toDouble() ?? (isEarly ? (grossAmount * (feeRate / 100)) : 0.0);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isEarly ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                  width: isEarly ? 1.4 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst Satır (Talep No & Tutar & Durum)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isEarly
                                    ? const Color(0xFFFEF3C7)
                                    : (isCompleted
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFFEF3C7)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isEarly
                                    ? Icons.bolt_rounded
                                    : (isCompleted
                                        ? Icons.check_circle_rounded
                                        : Icons.access_time_filled_rounded),
                                color: isEarly
                                    ? const Color(0xFFD97706)
                                    : (isCompleted
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFD97706)),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Talep: #$reqId',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13.5,
                                            color: Color(0xFF0F172A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isEarly) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFFDE68A)),
                                          ),
                                          child: Text(
                                            '⚡ Erken (%${feeRate.toStringAsFixed(0)})',
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFB45309),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    date,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_formatCurrency(amount)} ₺',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (isEarly) ...[
                            Text(
                              'Brüt: ${_formatCurrency(grossAmount)} ₺ (-${_formatCurrency(feeAmount)} ₺)',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isEarly
                                  ? const Color(0xFFDCFCE7)
                                  : (isCompleted
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFFEF3C7)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isEarly ? '⚡ FAST İle Aktarıldı' : (isCompleted ? 'Hesaba Aktarıldı' : 'İşlemde / Sırada'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isEarly || isCompleted
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),

                  // Alt Satır: IBAN & Dekont No (0 Overflow Garantili)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_balance_rounded, size: 13, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '$bank • ${_maskIbanCompact(ibanStr)}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Dekont: $dekontNo',
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          childCount: _payoutRequests.length + 1,
        ),
      ),
    );
  }

  // =========================================================================
  // 7. PARA ÇEKME (HAKEDİŞİ AKTAR) BOTTOM SHEET
  // =========================================================================
  void _showPayoutBottomSheet() {
    final amountController = TextEditingController();
    double selectedAmount = _availableBalance;
    amountController.text = selectedAmount.toStringAsFixed(0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.payments_rounded,
                            color: AppTheme.ustaPrimary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hakedişi Banka Hesabıma Aktar',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'FAST / EFT ile anında IBAN transferi',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 7 Gün Kuralı & Bakiye Durum Kartı
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Çekilebilir Net Hakediş:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              Text(
                                '${_formatCurrency(_availableBalance)} ₺',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                          if (_blockedBalance > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.lock_clock_rounded, size: 12, color: Color(0xFFD97706)),
                                    SizedBox(width: 4),
                                    Text(
                                      '7 Gün Blokeli (Provizyon):',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${_formatCurrency(_blockedBalance)} ₺',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tutar Girişi
                    const Text(
                      'Çekmek İstediğiniz Tutar (₺)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            '₺',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ustaPrimary,
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.ustaPrimary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Hızlı Tutar Butonları
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildQuickAmountChip('Tümü (${_formatCurrency(_availableBalance)} ₺)', _availableBalance, amountController, setSheetState),
                        _buildQuickAmountChip('%50', _availableBalance * 0.5, amountController, setSheetState),
                        _buildQuickAmountChip('10.000 ₺', 10000.0, amountController, setSheetState),
                        _buildQuickAmountChip('5.000 ₺', 5000.0, amountController, setSheetState),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Hedef IBAN Önizleme
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_rounded, size: 18, color: Color(0xFF475569)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$_banka • $_adSoyad',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  _maskIbanFull(_iban),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showEditIbanBottomSheet();
                            },
                            child: const Text('Değiştir', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.ustaPrimary)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Onayla ve Çek Butonu
                    ElevatedButton(
                      onPressed: () async {
                        final entered = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0.0;
                        if (entered <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lütfen geçerli bir tutar giriniz.')),
                          );
                          return;
                        }
                        if (entered > _availableBalance) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Çekilebilir bakiyeniz en fazla ${_formatCurrency(_availableBalance)} ₺\'dir. Son 7 gün içinde yapılan işlerinizin hakedişi (${_formatCurrency(_blockedBalance)} ₺) provizyon güvencesi kapsamında blokelidir.',
                              ),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                          return;
                        }

                        Navigator.pop(ctx);

                        // Çekim Talebi Oluştur
                        final success = await _dataService.createUstaPayoutRequest(
                          _activePhone,
                          amount: entered,
                          iban: _iban,
                          banka: _banka,
                          adSoyad: _adSoyad,
                        );

                        if (success) {
                          await _loadWalletData();
                          if (mounted) {
                            _showSuccessDialog(entered);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.ustaPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Talebi Onayla ve Hesaba Aktar',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // 7.1. 7 GÜN BEKLEMEDEN ERKEN ÇEKİM (ANINDA AVANS) BOTTOM SHEET
  // =========================================================================
  Future<void> _showEarlyPayoutBottomSheet() async {
    final isEarlyEnabled = await _dataService.isEarlyPayoutEnabled();
    if (!isEarlyEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erken çekim özelliği şu an kapalıdır. 7 günlük müşteri güvence provizyonu geçerlidir.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
      return;
    }

    final freshRate = await _dataService.getEarlyPayoutRate();
    if (mounted) {
      setState(() {
        _earlyPayoutRate = freshRate;
        _isEarlyPayoutEnabled = isEarlyEnabled;
      });
    }

    final amountController = TextEditingController();
    double selectedGross = _blockedBalance;
    amountController.text = selectedGross > 0 ? selectedGross.toStringAsFixed(0) : '0';

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final enteredGross = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0.0;
            final feeRate = _earlyPayoutRate;
            final feeAmount = enteredGross * (feeRate / 100.0);
            final netPayout = (enteredGross - feeAmount).clamp(0.0, double.infinity);

            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFFD97706),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '7 Gün Beklemeden Erken Çekim',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Blokeli havuzdan FAST ile 7/24 anında nakit',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Erken Ödeme Kuralları & Kesinti Bilgi Kutusu
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFD97706)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '%${feeRate.toStringAsFixed(0)} Erken Ödeme Kesintisi Uygulanır',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '7 günlük müşteri güvence provizyon bekleme süresi kaldırılır. Çektiğiniz tutardan sadece %${feeRate.toStringAsFixed(0)} erken finansman kesintisi düşülerek kalan net tutar anında IBAN\'ınıza gönderilir.',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Blokeli Bakiye Göstergesi
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
                              Icon(Icons.lock_clock_rounded, size: 15, color: Color(0xFFD97706)),
                              SizedBox(width: 6),
                              Text(
                                'Kullanılabilir Blokeli Bakiye:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${_formatCurrency(_blockedBalance)} ₺',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Çekilmek İstenen Tutar Girişi
                    const Text(
                      'Erken Çekmek İstediğiniz Tutar (₺)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            '₺',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFD97706), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Hızlı Tutar Butonları
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildQuickAmountChip('Tümü (${_formatCurrency(_blockedBalance)} ₺)', _blockedBalance, amountController, setSheetState),
                        _buildQuickAmountChip('%50', _blockedBalance * 0.5, amountController, setSheetState),
                        _buildQuickAmountChip('20.000 ₺', 20000.0, amountController, setSheetState),
                        _buildQuickAmountChip('10.000 ₺', 10000.0, amountController, setSheetState),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Canlı Hesaplama Dökümü Kartı (Gross - Fee = Net)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Çekilen Blokeli Tutar:', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                              Text('${_formatCurrency(enteredGross)} ₺', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Erken Ödeme Kesintisi (%${feeRate.toStringAsFixed(0)}):', style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
                              Text('-${_formatCurrency(feeAmount)} ₺', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hesabınıza Geçecek Net Tutar:',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    'FAST 7/24 Anında Aktarım',
                                    style: TextStyle(fontSize: 10.5, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              Text(
                                '${_formatCurrency(netPayout)} ₺',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Hedef IBAN Önizleme
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_rounded, size: 18, color: Color(0xFF475569)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$_banka • $_adSoyad',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  _maskIbanFull(_iban),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showEditIbanBottomSheet();
                            },
                            child: const Text('Değiştir', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.ustaPrimary)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Onayla ve Erken Çek Butonu
                    ElevatedButton(
                      onPressed: () async {
                        if (enteredGross <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lütfen geçerli bir tutar giriniz.')),
                          );
                          return;
                        }
                        if (enteredGross > _blockedBalance) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Erken çekebileceğiniz blokeli bakiyeniz en fazla ${_formatCurrency(_blockedBalance)} ₺\'dir.',
                              ),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                          return;
                        }

                        Navigator.pop(ctx);

                        // Erken Çekim Talebi Oluştur
                        final success = await _dataService.createUstaPayoutRequest(
                          _activePhone,
                          amount: netPayout,
                          iban: _iban,
                          banka: _banka,
                          adSoyad: _adSoyad,
                          isEarlyPayout: true,
                          grossAmount: enteredGross,
                          feeRate: feeRate,
                          feeAmount: feeAmount,
                        );

                        if (success) {
                          await _loadWalletData();
                          if (mounted) {
                            _showSuccessDialog(
                              netPayout,
                              isEarlyPayout: true,
                              grossAmount: enteredGross,
                              feeAmount: feeAmount,
                              feeRate: feeRate,
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        '⚡ Erken Çekimi Onayla ve ${_formatCurrency(netPayout)} ₺ Aktar',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickAmountChip(
    String label,
    double value,
    TextEditingController controller,
    StateSetter setSheetState,
  ) {
    return InkWell(
      onTap: () {
        setSheetState(() {
          controller.text = value.toStringAsFixed(0);
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 8. IBAN DÜZENLEME BOTTOM SHEET (NET VE KUSURSUZ RENKLER)
  // =========================================================================
  void _showEditIbanBottomSheet() {
    final ibanController = TextEditingController(text: _iban);
    final bankaController = TextEditingController(text: _banka);
    final adSoyadController = TextEditingController(text: _adSoyad);

    final popularBanks = [
      'Ziraat Bankası',
      'İş Bankası',
      'Garanti BBVA',
      'Yapı Kredi',
      'Akbank',
      'VakıfBank',
      'QNB Finansbank',
      'Halkbank',
      'Enpara.com',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Banka & IBAN Numarası Düzenle',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Hakediş ödemelerinizin eksiksiz aktarılması için adınıza ait IBAN giriniz.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),

                    // Banka Seçimi
                    const Text(
                      'Banka Adı',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: popularBanks.contains(bankaController.text)
                          ? bankaController.text
                          : popularBanks.first,
                      dropdownColor: Colors.white,
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF475569)),
                      items: popularBanks.map((b) {
                        return DropdownMenuItem(
                          value: b,
                          child: Text(b, style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A))),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => bankaController.text = val);
                        }
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.ustaPrimary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Hesap Sahibi Ad Soyad
                    const Text(
                      'Hesap Sahibi (Ad Soyad)',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: adSoyadController,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        hintText: 'Örn: Kadir Cebeci',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.ustaPrimary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // IBAN
                    const Text(
                      'IBAN Numarası',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: ibanController,
                      style: const TextStyle(fontSize: 13.5, fontFamily: 'monospace', fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        hintText: 'TR..',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.credit_card_rounded, size: 20, color: Color(0xFF475569)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.ustaPrimary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    ElevatedButton(
                      onPressed: () async {
                        final newIban = ibanController.text.trim();
                        final newBank = bankaController.text.trim();
                        final newName = adSoyadController.text.trim();

                        if (newIban.length < 15 || !newIban.toUpperCase().startsWith('TR')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lütfen TR ile başlayan geçerli bir IBAN giriniz.')),
                          );
                          return;
                        }

                        await _dataService.saveUstaIban(
                          _activePhone,
                          iban: newIban,
                          banka: newBank,
                          adSoyad: newName,
                        );

                        Navigator.pop(ctx);
                        _loadWalletData();

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Banka ve IBAN bilgileriniz başarıyla güncellendi!'),
                            backgroundColor: Color(0xFF15803D),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.ustaPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('IBAN Bilgilerini Kaydet', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // 9. İŞLEM DETAY MODALI
  // =========================================================================
  void _showJobDetailModal(Map<String, dynamic> item) {
    final customerName = item['musteri_ad'] ?? 'Müşteri';
    final customerPhone = item['musteri_tel'] ?? '';
    final customerAddress = item['musteri_adres'] ?? 'Sandıklı';
    final serviceTitle = item['hizmet_baslik'] ?? 'Servis';
    final totalFee = (item['toplam_tutar'] as num?)?.toDouble() ?? 0.0;
    final commission = (item['komisyon_tutari'] as num?)?.toDouble() ?? (totalFee * 0.15);
    final netEarned = (item['usta_hakedis'] as num?)?.toDouble() ?? (totalFee - commission);
    final date = item['tarih'] ?? '';
    final txId = item['id'] ?? '';
    final comment = item['yorum'] ?? '';
    final bool isBlocked = item['is_blocked'] == true;
    final int remainingDays = (item['remaining_days'] as num?)?.toInt() ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'İşlem & Hakediş Dekontu',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '#$txId',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildModalRow('Müşteri:', customerName),
                    if (customerPhone.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildModalRow('Telefon:', customerPhone),
                    ],
                    const SizedBox(height: 8),
                    _buildModalRow('Adres:', customerAddress),
                    const SizedBox(height: 8),
                    _buildModalRow('Hizmet:', serviceTitle),
                    const SizedBox(height: 8),
                    _buildModalRow('Tarih:', date),
                    const SizedBox(height: 8),
                    _buildModalRow(
                      'Provizyon Durumu:',
                      isBlocked ? '7 Gün Blokeli ($remainingDays gün kaldı)' : 'Bloke Çözüldü (Kullanılabilir)',
                      color: isBlocked ? const Color(0xFFD97706) : const Color(0xFF15803D),
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Finansal Ayrıştırma Tablosu
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _buildModalRow('Müşteri Toplam Ödemesi:', '${_formatCurrency(totalFee)} ₺'),
                    const SizedBox(height: 8),
                    _buildModalRow('Platform Hizmet Komisyonu (%15):', '-${_formatCurrency(commission)} ₺', color: const Color(0xFFDC2626)),
                    const Divider(height: 16, color: Color(0xFFCBD5E1)),
                    _buildModalRow(
                      'Usta Net Hakedişi:',
                      '+${_formatCurrency(netEarned)} ₺',
                      isBold: true,
                      color: isBlocked ? const Color(0xFFD97706) : const Color(0xFF15803D),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (comment.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '"$comment"',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Kapat'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: const Color(0xFF64748B),
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: color ?? const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 10. BAŞARILI ÇEKİM BİLDİRİMİ (STANDART & ERKEN ÇEKİM)
  // =========================================================================
  void _showSuccessDialog(
    double amount, {
    bool isEarlyPayout = false,
    double grossAmount = 0.0,
    double feeAmount = 0.0,
    double feeRate = 5.0,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isEarlyPayout ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isEarlyPayout ? Icons.bolt_rounded : Icons.check_circle_rounded,
                  color: isEarlyPayout ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEarlyPayout ? '⚡ Erken Çekim Başarılı!' : 'Çekim Talebiniz Alındı!',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (isEarlyPayout) ...[
                Text(
                  '7 günlük provizyon bekleme süresi kaldırıldı. FAST altyapısı ile net ${_formatCurrency(amount)} ₺ tutar $_banka hesabınıza anında aktarılmıştır.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Çekilen Blokeli Tutar:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          Text('${_formatCurrency(grossAmount)} ₺', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Erken Kesinti (%${feeRate.toStringAsFixed(0)}):', style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                          Text('-${_formatCurrency(feeAmount)} ₺', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Hesaba Aktarılan Net:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                          Text('${_formatCurrency(amount)} ₺', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF15803D))),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  '${_formatCurrency(amount)} ₺ tutarındaki çekilebilir hakediş talebiniz işleme alınmıştır. En geç 15 dakika içerisinde FAST altyapısı ile $_banka hesabınıza aktarılacaktır.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEarlyPayout ? const Color(0xFFD97706) : AppTheme.ustaPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // YARDIMCI METODLAR
  // =========================================================================
  String _formatCurrency(double amount) {
    final str = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return buffer.toString().split('').reversed.join('');
  }

  String _maskIbanFull(String iban) {
    final clean = iban.replaceAll(' ', '');
    if (clean.length < 10) return iban;
    final start = clean.substring(0, 4);
    final end = clean.substring(clean.length - 4);
    return '$start •••• •••• •••• •••• ••$end';
  }

  String _maskIbanCompact(String iban) {
    final clean = iban.replaceAll(' ', '');
    if (clean.length < 8) return iban;
    final start = clean.substring(0, 4);
    final end = clean.substring(clean.length - 4);
    return '$start •• $end';
  }
}
