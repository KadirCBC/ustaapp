import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/services/payment_service.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/map/controllers/map_controller.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';

/// Haritanın alt kısmında yer alan modern, profesyonel açılır panel:
/// - Seçili usta yoksa: Bölgedeki aktif ustalar ve tahmini varış süresi özet bilgi çubuğu
/// - Usta seçildiğinde: Usta profili, yetki/güvenceler, servis & yol ücreti,
///   eklediği hizmet ilanları tarifesi, profesyonel adres & arıza notu ve
///   kartla güvenceli ödeme çağrı kartı.
class MechanicBottomCard extends ConsumerStatefulWidget {
  final List<NearbyUstaModel> nearbyUstalar;
  final NearbyUstaModel? selectedUsta;
  final bool isLoadingUstalar;
  final ValueChanged<NearbyUstaModel> onQuickPickUsta;
  final VoidCallback onClearSelection;

  const MechanicBottomCard({
    super.key,
    required this.nearbyUstalar,
    required this.selectedUsta,
    required this.isLoadingUstalar,
    required this.onQuickPickUsta,
    required this.onClearSelection,
  });

  @override
  ConsumerState<MechanicBottomCard> createState() => _MechanicBottomCardState();
}

class _MechanicBottomCardState extends ConsumerState<MechanicBottomCard> {
  late final TextEditingController _buildingDetailController;
  late final TextEditingController _faultNoteController;
  final Set<String> _selectedFaultTags = <String>{};
  UstaHizmetIlan? _selectedIlan;
  bool _hasPhotoAttached = false;

  @override
  void initState() {
    super.initState();
    _buildingDetailController = TextEditingController();
    _faultNoteController = TextEditingController();
    _initSelectedIlan(widget.selectedUsta);
  }

  void _initSelectedIlan(NearbyUstaModel? usta) {
    if (usta == null || usta.ilanlar.isEmpty) {
      _selectedIlan = null;
      return;
    }
    _selectedIlan = usta.ilanlar.firstWhere(
      (ilan) => ilan.isDefault,
      orElse: () => usta.ilanlar.first,
    );
  }

  @override
  void didUpdateWidget(covariant MechanicBottomCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedUsta?.ustaId != widget.selectedUsta?.ustaId) {
      _buildingDetailController.clear();
      _faultNoteController.clear();
      _selectedFaultTags.clear();
      _hasPhotoAttached = false;
      _initSelectedIlan(widget.selectedUsta);
    }
  }

  @override
  void dispose() {
    _buildingDetailController.dispose();
    _faultNoteController.dispose();
    super.dispose();
  }

  ({double servicePrice, double commission, double total}) _calculatePricing(
    NearbyUstaModel usta,
  ) {
    final double servicePrice = _selectedIlan?.fiyat ?? usta.ustaHakedis;
    final double commission = servicePrice * usta.komisyonOrani;
    final double total = servicePrice + commission;
    return (
      servicePrice: servicePrice,
      commission: commission,
      total: total,
    );
  }

  List<String> _getCategoryFaultTags(String category) {
    switch (category) {
      case 'cilingir':
        return const [
          '🔑 Kapıda Kaldım (Anahtar İçeride)',
          '🔒 Kilit Bozuldu / Dönmüyor',
          '🚪 Çelik Kapı Açımı',
          '🛡️ Barel Değişimi',
          '🚗 Oto Çilingir / Kapı Açımı',
        ];
      case 'tesisat':
        return const [
          '💧 Su Sızıntısı & Kaçak',
          '🚿 Tıkalı Gider / Lavabo',
          '🚰 Musluk & Batarya Tamiri',
          '🚽 Klozet Sifon Arızası',
          '🔥 Şofben / Petek Tesisatı',
        ];
      case 'elektrik':
      default:
        return const [
          '⚡ Sigorta Sürekli Atıyor',
          '🔌 Priz Çalışmıyor / Kırık',
          '💡 Avize & Aydınlatma Montajı',
          '⚠️ Kısa Devre & Yanık Kokusu',
          '🚨 Acil Elektrik Kesintisi',
        ];
    }
  }

  Future<void> _onCallUstaPressed(NearbyUstaModel usta) async {
    final mapController = ref.read(customerMapControllerProvider.notifier);
    final paymentService = ref.read(paymentServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final pricing = _calculatePricing(usta);

    // Yapılandırılmış profesyonel adres ve arıza notu
    final noteBuffer = StringBuffer();
    if (_selectedIlan != null) {
      noteBuffer.writeln(
        '📋 Seçilen Hizmet: ${_selectedIlan!.baslik} (${_selectedIlan!.fiyat.toStringAsFixed(0)} ₺)',
      );
    }
    if (_selectedFaultTags.isNotEmpty) {
      noteBuffer.writeln('🏷️ Arıza Türü: ${_selectedFaultTags.join(', ')}');
    }
    final building = _buildingDetailController.text.trim();
    if (building.isNotEmpty) {
      noteBuffer.writeln('🏠 Daire / Kat / Zil: $building');
    }
    final customNote = _faultNoteController.text.trim();
    if (customNote.isNotEmpty) {
      noteBuffer.writeln('📝 Müşteri Notu: $customNote');
    }
    if (_hasPhotoAttached) {
      noteBuffer.writeln('📷 Fotoğraf: 1 Adet Görsel Eklendi');
    }

    final updatedUsta = usta.copyWith(
      ustaHakedis: pricing.servicePrice,
      komisyonTutari: pricing.commission,
      toplamTutar: pricing.total,
    );

    final cagriId = await mapController.createCagri(
      usta: updatedUsta,
      adresTarifi: noteBuffer.toString().trim(),
    );

    if (cagriId == null || !mounted) return;

    final preAuthResult = await paymentService.createPreAuth(cagriId: cagriId);
    if (!mounted) return;

    if (!preAuthResult.success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(preAuthResult.error ?? 'Karttan provizyon alınamadı.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    router.push('/customer/active-call/$cagriId');
  }

  @override
  Widget build(BuildContext context) {
    final usta = widget.selectedUsta;
    final mapState = ref.watch(customerMapControllerProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: usta == null
              ? _buildIdleSummaryBar()
              : _buildSelectedUstaCard(usta, mapState),
        ),
      ),
    );
  }

  /// Seçim yapılmadığında gösterilen özet bilgi çubuğu
  Widget _buildIdleSummaryBar() {
    final mapState = ref.watch(customerMapControllerProvider);
    final isTedarikciModu = mapState.selectedCategory == 'tedarikciler';

    final count = widget.nearbyUstalar.length;
    final minEta = widget.nearbyUstalar.isNotEmpty
        ? widget.nearbyUstalar
            .map((u) => u.tahminiVarisDakika)
            .reduce((a, b) => a < b ? a : b)
        : 15;
    final maxEta = minEta + 10;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isTedarikciModu
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isTedarikciModu
                      ? Icons.storefront_rounded
                      : Icons.engineering_rounded,
                  color: isTedarikciModu
                      ? const Color(0xFFD97706)
                      : const Color(0xFF15803D),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTedarikciModu
                          ? (mapState.isLoadingIsletmeler
                              ? 'Bölgenizdeki dükkanlar taranıyor...'
                              : mapState.isletmeler.isEmpty
                                  ? 'Bölgenizde aktif dükkan / tedarikçi bulunamadı'
                                  : 'Bölgenizde ${mapState.isletmeler.length} dükkan & tedarikçi aktif')
                          : (widget.isLoadingUstalar
                              ? 'Bölgendeki ustalar taranıyor...'
                              : count == 0
                                  ? 'Bölgenizde aktif usta bulunmuyor'
                                  : 'Bölgende $count usta aktif • Tahmini varış: $minEta-$maxEta dk'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.customerTextDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isTedarikciModu
                          ? (mapState.isletmeler.isEmpty
                              ? 'Yönetici panelinden yeni işletme ve dükkan ekleyebilirsiniz.'
                              : 'İletişim ve yol tarifi için dükkan pinlerine dokunun')
                          : (count == 0
                              ? 'Yönetici panelinden yeni usta ekleyebilir veya servis çağrısı açabilirsiniz.'
                              : 'Fiyatları ve detayları görmek için haritadaki bir pine dokunun'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.customerTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isTedarikciModu && mapState.isletmeler.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: mapState.isletmeler.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = mapState.isletmeler[index];
                  return ActionChip(
                    backgroundColor: const Color(0xFFFFFBEB),
                    side: const BorderSide(color: Color(0xFFFDE68A)),
                    avatar: Icon(
                      item.isSponsored ? Icons.star_rounded : Icons.store_rounded,
                      size: 15,
                      color: const Color(0xFFD97706),
                    ),
                    label: Text(
                      '${item.ad} • ${item.kategori}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    onPressed: () {
                      ref.read(customerMapControllerProvider.notifier).selectIsletme(item);
                    },
                  );
                },
              ),
            ),
          ] else if (widget.nearbyUstalar.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.nearbyUstalar.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = widget.nearbyUstalar[index];
                  return ActionChip(
                    backgroundColor: const Color(0xFFF8FAFC),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    avatar: const Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: Colors.amber,
                    ),
                    label: Text(
                      '${item.shortDisplayName} • ${item.formattedPrice}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.customerTextDark,
                      ),
                    ),
                    onPressed: () => widget.onQuickPickUsta(item),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Usta seçildiğinde yukarı doğru açılan kapsamlı profesyonel detay kartı
  Widget _buildSelectedUstaCard(
    NearbyUstaModel usta,
    CustomerMapState mapState,
  ) {
    final pricing = _calculatePricing(usta);
    final categoryFaultTags = _getCategoryFaultTags(usta.kategori);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tutamaç & Kapatma Butonu
            Row(
              children: [
                const SizedBox(width: 32),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: widget.onClearSelection,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppTheme.customerTextDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 1. Profil Bilgileri & Başlık
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor:
                          AppTheme.customerPrimary.withValues(alpha: 0.1),
                      backgroundImage: usta.avatarUrl != null
                          ? NetworkImage(usta.avatarUrl!)
                          : null,
                      child: usta.avatarUrl == null
                          ? const Icon(
                              Icons.person_rounded,
                              size: 34,
                              color: AppTheme.customerPrimary,
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF22C55E),
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              usta.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.customerTextDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  size: 12,
                                  color: AppTheme.customerPrimary,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Onaylı Usta',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.customerPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${usta.uzmanlikBasligi} • ${usta.deneyimYili} Yıl Deneyim',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.customerTextMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber.shade600,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            usta.puan.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.customerTextDark,
                            ),
                          ),
                          const Text(
                            ' • ',
                            style: TextStyle(color: AppTheme.customerTextMuted),
                          ),
                          Text(
                            '${usta.tamamlananIsSayisi} tamamlanan iş',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.customerTextMuted,
                            ),
                          ),
                          const Text(
                            ' • ',
                            style: TextStyle(color: AppTheme.customerTextMuted),
                          ),
                          const Text(
                            '%99 Memnuniyet',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 2. Metrik Göstergeleri (Varış, Mesafe, Servis Ücreti)
            Row(
              children: [
                Expanded(
                  child: _MetricTag(
                    icon: Icons.access_time_filled_rounded,
                    iconColor: const Color(0xFFEA580C),
                    label: 'Varış: ~${usta.tahminiVarisDakika} dk',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTag(
                    icon: Icons.near_me_rounded,
                    iconColor: AppTheme.customerPrimary,
                    label: 'Mesafe: ${usta.formattedDistance}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTag(
                    icon: Icons.directions_car_rounded,
                    iconColor: const Color(0xFF0D9488),
                    label: 'Servis: ${usta.servisUcreti.toStringAsFixed(0)} ₺',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 3. Güvence Rozetleri
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: usta.guvenceler.map((guvence) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 13,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        guvence,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            // 4. Ustanın Hizmet İlanları & Fiyat Tarifesi
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 18,
                            color: AppTheme.customerPrimary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Ustanın Hizmet İlanları & Tarifesi',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.customerTextDark,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${usta.ilanlar.length} Hizmet',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.customerPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'İhtiyacınıza uygun ilana dokunarak seçebilirsiniz:',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.customerTextMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: usta.ilanlar.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final ilan = usta.ilanlar[index];
                      final isSelected = _selectedIlan?.id == ilan.id;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedIlan = ilan;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.customerPrimary
                                  : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.customerPrimary
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    ilan.ikon,
                                    style: const TextStyle(fontSize: 18),
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
                                        Expanded(
                                          child: Text(
                                            ilan.baslik,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.w800
                                                  : FontWeight.w700,
                                              color: isSelected
                                                  ? AppTheme.customerPrimary
                                                  : AppTheme.customerTextDark,
                                            ),
                                          ),
                                        ),
                                        if (ilan.isDefault)
                                          Container(
                                            margin: const EdgeInsets.only(left: 4),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Taban',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF15803D),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      ilan.aciklama,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.customerTextMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.timer_outlined,
                                          size: 12,
                                          color: AppTheme.customerTextMuted,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          ilan.tahminiSure,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.customerTextMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${ilan.fiyat.toStringAsFixed(0)} ₺',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: isSelected
                                          ? AppTheme.customerPrimary
                                          : AppTheme.customerTextDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    size: 18,
                                    color: isSelected
                                        ? AppTheme.customerPrimary
                                        : const Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: AppTheme.customerPrimary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Ustanın yol/keşif servis bedeli (${usta.servisUcreti.toStringAsFixed(0)} ₺) seçilen hizmet paketine dahildir.',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.customerPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 5. Profesyonel Adres ve Arıza Notu Alanı
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 18,
                        color: Color(0xFFE11D48),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Hizmet Adresi & Arıza Bildirimi',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.customerTextDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Mevcut Adres Bilgisi
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.my_location_rounded,
                          size: 15,
                          color: AppTheme.customerPrimary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            mapState.currentAddressLabel,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.customerTextDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Daire / Kat / Blok Alanı
                  TextField(
                    controller: _buildingDetailController,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.home_work_outlined,
                        size: 18,
                        color: AppTheme.customerTextMuted,
                      ),
                      hintText: 'Daire no, kat, blok veya zil adı (örn: Kat 2, Daire 5, Zil: Yılmaz)',
                      hintStyle: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF94A3B8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Hızlı Arıza Etiketleri
                  const Text(
                    'Hızlı Arıza Seçimi:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.customerTextDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: categoryFaultTags.map((tag) {
                      final isSelected = _selectedFaultTags.contains(tag);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.customerTextDark,
                          ),
                        ),
                        backgroundColor: Colors.white,
                        selectedColor: AppTheme.customerPrimary,
                        side: BorderSide(
                          color: isSelected
                              ? AppTheme.customerPrimary
                              : const Color(0xFFE2E8F0),
                        ),
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedFaultTags.add(tag);
                            } else {
                              _selectedFaultTags.remove(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Detaylı Açıklama / Usta Notu
                  TextField(
                    controller: _faultNoteController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 32),
                        child: Icon(
                          Icons.edit_note_rounded,
                          size: 20,
                          color: AppTheme.customerTextMuted,
                        ),
                      ),
                      hintText: 'Arızanın detayını veya ustanın yanında getirmesi gereken özel malzemeyi yazabilirsiniz...',
                      hintStyle: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF94A3B8),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Fotoğraf Ekleme Düğmesi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _hasPhotoAttached = !_hasPhotoAttached;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _hasPhotoAttached
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _hasPhotoAttached
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _hasPhotoAttached
                                    ? Icons.check_circle_rounded
                                    : Icons.add_a_photo_outlined,
                                size: 14,
                                color: _hasPhotoAttached
                                    ? const Color(0xFF15803D)
                                    : AppTheme.customerPrimary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _hasPhotoAttached
                                    ? '1 Arıza Fotoğrafı Eklendi'
                                    : '+ Fotoğraf / Görsel Ekle (Opsiyonel)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _hasPhotoAttached
                                      ? const Color(0xFF15803D)
                                      : AppTheme.customerPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Text(
                        'Maks 200 karakter',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 6. Şeffaf Fiyat Kırılımı Kartı
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _PriceLine(
                    label: _selectedIlan != null
                        ? 'Seçilen Hizmet (${_selectedIlan!.baslik})'
                        : 'Taban Hizmet Ücreti',
                    value: '${pricing.servicePrice.toStringAsFixed(0)} ₺',
                  ),
                  const SizedBox(height: 6),
                  _PriceLine(
                    label: 'Usta Servis / Yol & Keşif Bedeli',
                    value: '${usta.servisUcreti.toStringAsFixed(0)} ₺ (Dahil)',
                  ),
                  const SizedBox(height: 6),
                  _PriceLine(
                    label: 'Platform Güvence & İyzico Sigorta Bedeli',
                    value: '${pricing.commission.toStringAsFixed(0)} ₺',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: Color(0xFFCBD5E1)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Toplam Provizyon Tutarı',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.customerTextDark,
                            ),
                          ),
                          Text(
                            'İş tamamlanana kadar bloke tutulur',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppTheme.customerTextMuted,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${pricing.total.toStringAsFixed(0)} ₺',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.customerPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 7. Yüksek Kontrastlı Güvenli Çağır Butonu (CTA)
            ElevatedButton.icon(
              onPressed: mapState.isCreatingCall
                  ? null
                  : () => _onCallUstaPressed(usta),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: mapState.isCreatingCall
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_rounded, size: 18),
              label: Text(
                mapState.isCreatingCall
                    ? 'Çağrı Başlatılıyor...'
                    : 'Hemen Çağır (${pricing.total.toStringAsFixed(0)} ₺ ile Güvenceli Öde)',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                '🔒 İyzico korumalı havuz hesap • Usta işi teslim edip siz onaylayana kadar ödeme aktarılmaz',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.customerTextMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTag extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _MetricTag({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.customerTextDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  final String label;
  final String value;

  const _PriceLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppTheme.customerTextMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.customerTextDark,
          ),
        ),
      ],
    );
  }
}
