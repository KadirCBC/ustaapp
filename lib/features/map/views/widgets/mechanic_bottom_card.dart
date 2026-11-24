import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/services/app_data_service.dart';
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
  final UstaHizmetIlan? initialIlan;

  const MechanicBottomCard({
    super.key,
    required this.nearbyUstalar,
    required this.selectedUsta,
    required this.isLoadingUstalar,
    required this.onQuickPickUsta,
    required this.onClearSelection,
    this.initialIlan,
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
    if (widget.initialIlan != null) {
      _selectedIlan = widget.initialIlan;
    } else {
      _initSelectedIlan(widget.selectedUsta);
    }
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
    if (oldWidget.selectedUsta?.ustaId != widget.selectedUsta?.ustaId ||
        oldWidget.initialIlan?.id != widget.initialIlan?.id) {
      _buildingDetailController.clear();
      _faultNoteController.clear();
      _selectedFaultTags.clear();
      _hasPhotoAttached = false;
      if (widget.initialIlan != null) {
        _selectedIlan = widget.initialIlan;
      } else {
        _initSelectedIlan(widget.selectedUsta);
      }
    }
  }

  @override
  void dispose() {
    _buildingDetailController.dispose();
    _faultNoteController.dispose();
    super.dispose();
  }

  ({
    double baseServicePrice,
    double distanceKm,
    double perKmFee,
    double travelFee,
    double totalServicePrice,
    double platformCommissionBase,
    double kdvAmount,
    double stopajAmount,
    double totalPlatformFee,
    double total,
  }) _calculatePricing(
    NearbyUstaModel usta,
  ) {
    // 1. Seçilen Hizmet Taban Ücreti
    final double baseServicePrice = _selectedIlan?.fiyat ?? usta.ustaHakedis;

    // 2. Usta Yol / Mesafe Ücreti Hesabı:
    // Ustanın mesafeMetre'si km cinsine çevrilir
    final double distanceKm = usta.mesafeMetre > 0 ? (usta.mesafeMetre / 1000.0) : 0.85; // varsayılan min mesafe
    // Ustanın km başına belirlediği fiyat (varsayılan 25 TL/km)
    final double perKmFee = usta.kmBasiYakitUcreti > 0 ? usta.kmBasiYakitUcreti : 25.0;
    // Yol ücreti = km * km başı ücret (veya sabit servis ucreti ile harmanlanmış)
    final double travelFee = (distanceKm * perKmFee).clamp(20.0, 500.0);

    // Hizmet Bedeli + Usta Yol Bedeli toplam usta hakedişini oluşturur
    final double totalServicePrice = baseServicePrice + travelFee;

    // 3. Platform Komisyonu (Hizmet bedeli üzerinden %15)
    final double platformCommissionBase = totalServicePrice * (usta.komisyonOrani > 0 ? usta.komisyonOrani : 0.15);

    // 4. Yasal Vergiler:
    // Platform Komisyonu için %20 KDV
    final double kdvAmount = platformCommissionBase * 0.20;
    // %1 E-Ticaret / Pazaryeri Stopajı
    final double stopajAmount = platformCommissionBase * 0.01;

    // Toplam Platform Hizmet ve Yasal Güvence Bedeli
    final double totalPlatformFee = platformCommissionBase + kdvAmount + stopajAmount;

    // Müşterinin Ödeyeceği / Bloke Edilecek Toplam Provizyon
    final double total = totalServicePrice + totalPlatformFee;

    return (
      baseServicePrice: baseServicePrice,
      distanceKm: distanceKm,
      perKmFee: perKmFee,
      travelFee: travelFee,
      totalServicePrice: totalServicePrice,
      platformCommissionBase: platformCommissionBase,
      kdvAmount: kdvAmount,
      stopajAmount: stopajAmount,
      totalPlatformFee: totalPlatformFee,
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

    await _showPaymentCheckoutSheet(
      context: context,
      usta: usta,
      serviceTitle: _selectedIlan?.baslik ?? 'Standart Servis & Arıza Tespiti',
      pricing: pricing,
      addressAndNote: noteBuffer.toString().trim(),
    );
  }

  /// Güvenli Ödeme ve Provizyon Onay Adımı (Ödeme adımı tamamlanmadan çağrı BAŞLATILAMAZ)
  Future<void> _showPaymentCheckoutSheet({
    required BuildContext context,
    required NearbyUstaModel usta,
    required String serviceTitle,
    required dynamic pricing,
    required String addressAndNote,
  }) async {
    final mapController = ref.read(customerMapControllerProvider.notifier);
    final paymentService = ref.read(paymentServiceProvider);
    final router = GoRouter.of(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) {
        return _PaymentCheckoutModal(
          usta: usta,
          serviceTitle: serviceTitle,
          pricing: pricing,
          addressAndNote: addressAndNote,
          onConfirmPayment: () async {
            // 1. Önce İyzico ön provizyonu bloke et (Ödeme adımı tamamlanmadan çağrı BAŞLATILAMAZ!)
            final tempAuthId = 'pre-auth-${DateTime.now().millisecondsSinceEpoch}';
            final preAuthResult = await paymentService.createPreAuth(cagriId: tempAuthId);

            if (!preAuthResult.success) {
              throw Exception(
                preAuthResult.error ?? 'Ön provizyon alınamadı. Lütfen kart limitinizi kontrol ediniz.',
              );
            }

            // 2. Sadece provizyon onaylandıktan SONRA çağrı oluştur ve ustaya ilet!
            final updatedUsta = usta.copyWith(
              ustaHakedis: pricing.totalServicePrice,
              komisyonTutari: pricing.totalPlatformFee,
              toplamTutar: pricing.total,
            );

            final cagriId = await mapController.createCagri(
              usta: updatedUsta,
              adresTarifi: addressAndNote,
            );

            if (cagriId == null) {
              throw Exception('Çağrı oluşturulamadı. Lütfen tekrar deneyiniz.');
            }

            if (bottomSheetCtx.mounted) {
              Navigator.of(bottomSheetCtx).pop();
            }

            router.push('/customer/active-call/$cagriId');
          },
        );
      },
    );
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          AppTheme.ustaPrimary.withValues(alpha: 0.12),
                      backgroundImage: (usta.avatarUrl != null && usta.avatarUrl!.isNotEmpty)
                          ? NetworkImage(usta.avatarUrl!)
                          : null,
                      child: (usta.avatarUrl == null || usta.avatarUrl!.isEmpty)
                          ? Text(
                              usta.fullName.isNotEmpty ? usta.fullName[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.ustaPrimary,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF22C55E),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
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
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.customerTextDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(usta.levelBadgeEmoji, style: const TextStyle(fontSize: 11)),
                                const SizedBox(width: 3),
                                Text(
                                  'Seviye ${usta.calculatedLevel} • ${usta.levelTitle}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            '${usta.uzmanlikBasligi} • ${usta.deneyimYili} Yıl Deneyim',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.customerTextMuted,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: Colors.amber.shade600,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                usta.puan.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.customerTextDark,
                                ),
                              ),
                              Text(
                                ' (${usta.tamamlananIsSayisi})',
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
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 2. Metrik Göstergeleri (Varış, Mesafe, Tek Fiyat - ASLA KESİLMEZ)
            Row(
              children: [
                Expanded(
                  child: _MetricTag(
                    icon: Icons.timer_outlined,
                    iconColor: const Color(0xFFEA580C),
                    value: '~${usta.tahminiVarisDakika} dk',
                    label: 'Tahmini Varış',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTag(
                    icon: Icons.navigation_rounded,
                    iconColor: const Color(0xFF2563EB),
                    value: usta.formattedDistance,
                    label: 'Usta Mesafesi',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTag(
                    icon: Icons.verified_outlined,
                    iconColor: const Color(0xFF0D9488),
                    value: 'Sabit Fiyat',
                    label: 'Keşif Dahil',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 3. Zarif Güvence ve Garanti Şeridi
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.shield_rounded,
                    size: 15,
                    color: Color(0xFF16A34A),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'UstaGelio Koruması • 30 Gün İşçilik Garantisi & MYK Onaylı',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF15803D),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 4. Hizmet Seçimi & Fiyat Tarifesi (Modern & Sadeleştirilmiş)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 17,
                      color: AppTheme.customerPrimary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Hizmet Seçimi',
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
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Text(
                    '${usta.ilanlar.length} Seçenek',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.customerPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

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
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.customerPrimary
                            : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.customerPrimary.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
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
                              style: const TextStyle(fontSize: 17),
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
                              if (ilan.aciklama.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  ilan.aciklama,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.customerTextMuted,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time_rounded,
                                    size: 11.5,
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
                        const SizedBox(width: 8),
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
                            const SizedBox(height: 3),
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
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1.5),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: AppTheme.customerPrimary,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9A3412), // amber/orange dark text
                          height: 1.35,
                        ),
                        children: [
                          TextSpan(
                            text: 'Önemli Bilgilendirme: ',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(
                            text:
                                'Görüntülenen tutar sadece Keşif Ulaşım ve arıza tespiti ücretidir. ',
                          ),
                          TextSpan(
                            text: 'Gerekecek yedek parça yada malzeme ücretleri bu fiyata dahil değildir.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFC2410C),
                            ),
                          ),
                        ],
                      ),
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
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _hasPhotoAttached = !_hasPhotoAttached;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
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
                                Expanded(
                                  child: Text(
                                    _hasPhotoAttached
                                        ? '1 Fotoğraf Eklendi'
                                        : '+ Fotoğraf / Görsel Ekle',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: _hasPhotoAttached
                                          ? const Color(0xFF15803D)
                                          : AppTheme.customerPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Maks 200 kr.',
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PriceLine(
                    label: _selectedIlan != null
                        ? 'Seçilen Hizmet Bedeli (${_selectedIlan!.baslik})'
                        : 'Seçilen Hizmet Bedeli',
                    value: '${pricing.baseServicePrice.toStringAsFixed(0)} ₺',
                  ),
                  const SizedBox(height: 6),
                  _PriceLine(
                    label: 'Usta Yol / Ulaşım Ücreti (${pricing.distanceKm < 1 ? '${(pricing.distanceKm * 1000).toStringAsFixed(0)} m' : '${pricing.distanceKm.toStringAsFixed(1)} km'} • ${pricing.perKmFee.toStringAsFixed(0)} ₺/km)',
                    value: '+${pricing.travelFee.toStringAsFixed(0)} ₺',
                  ),
                  const SizedBox(height: 6),
                  _PriceLine(
                    label: 'Toplam Usta Hizmet & Yol Bedeli',
                    value: '${pricing.totalServicePrice.toStringAsFixed(0)} ₺',
                    isSubtotal: true,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ),
                  _PriceLine(
                    label: 'Platform Komisyon Bedeli (%15)',
                    value: '${pricing.platformCommissionBase.toStringAsFixed(0)} ₺',
                  ),
                  const SizedBox(height: 4),
                  _PriceLine(
                    label: 'Platform KDV (%20)',
                    value: '${pricing.kdvAmount.toStringAsFixed(0)} ₺',
                    isDimmed: true,
                  ),
                  const SizedBox(height: 4),
                  _PriceLine(
                    label: 'E-Ticaret Stopaj Kesintisi (%1)',
                    value: '${pricing.stopajAmount.toStringAsFixed(1)} ₺',
                    isDimmed: true,
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
                    ? 'Provizyon Doğrulanıyor...'
                    : 'Güvenli Ödeme ile Çağır (${pricing.total.toStringAsFixed(0)} ₺)',
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
  final String value;
  final String label;

  const _MetricTag({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.customerTextDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.customerTextMuted,
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
  final bool isSubtotal;
  final bool isDimmed;

  const _PriceLine({
    required this.label,
    required this.value,
    this.isSubtotal = false,
    this.isDimmed = false,
  });

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
            style: TextStyle(
              fontSize: isSubtotal ? 12.5 : 12,
              fontWeight: isSubtotal ? FontWeight.w700 : FontWeight.w500,
              color: isSubtotal
                  ? AppTheme.customerTextDark
                  : isDimmed
                      ? const Color(0xFF94A3B8)
                      : AppTheme.customerTextMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isSubtotal ? 13 : 12,
            fontWeight: isSubtotal ? FontWeight.w800 : FontWeight.w700,
            color: isSubtotal
                ? AppTheme.customerTextDark
                : isDimmed
                    ? const Color(0xFF64748B)
                    : AppTheme.customerTextDark,
          ),
        ),
      ],
    );
  }
}

/// İyzico 3D Güvenli Ödeme & Ön Provizyon Onay Sayfası
class _PaymentCheckoutModal extends StatefulWidget {
  final NearbyUstaModel usta;
  final String serviceTitle;
  final dynamic pricing;
  final String addressAndNote;
  final Future<void> Function() onConfirmPayment;

  const _PaymentCheckoutModal({
    required this.usta,
    required this.serviceTitle,
    required this.pricing,
    required this.addressAndNote,
    required this.onConfirmPayment,
  });

  @override
  State<_PaymentCheckoutModal> createState() => _PaymentCheckoutModalState();
}

class _PaymentCheckoutModalState extends State<_PaymentCheckoutModal> {
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Başlık & İyzico Güvence Rozeti
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFEDD5)),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppTheme.customerPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Güvenli Ödeme & Provizyon',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'İyzico 256-Bit SSL • Koruma Havuz Hesabı',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Temsili Kayıtlı Kredi Kartı Görünümü
              Container(
                height: 130,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'İyzico Korumalı Kart',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Mastercard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      '••••  ••••  ••••  4242',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.usta.fullName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          '12/28',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Hizmet ve Fiyat Dökümü
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            widget.serviceTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Text(
                          '${widget.pricing.baseServicePrice.toStringAsFixed(0)} ₺',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Usta Yol / Ulaşım Ücreti (${widget.pricing.distanceKm < 1 ? '${(widget.pricing.distanceKm * 1000).toStringAsFixed(0)} m' : '${widget.pricing.distanceKm.toStringAsFixed(1)} km'})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '+${widget.pricing.travelFee.toStringAsFixed(0)} ₺',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Platform Komisyonu & Güvence (%15)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '${widget.pricing.platformCommissionBase.toStringAsFixed(0)} ₺',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Komisyon KDV (%20) & Stopaj (%1)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        Text(
                          '+${(widget.pricing.kdvAmount + widget.pricing.stopajAmount).toStringAsFixed(1)} ₺',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_locked_rounded,
                          size: 14,
                          color: Color(0xFFD97706),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Usta Tel: ${AppDataService.maskPhone(widget.usta.phone)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          '(İş Kabul Edilince Açılır)',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18, color: Color(0xFFE2E8F0)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Toplam Provizyon Tutarı',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${widget.pricing.total.toStringAsFixed(0)} ₺',
                          style: const TextStyle(
                            fontSize: 19,
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

              // Güvenlik Açıklaması
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 18,
                      color: Color(0xFF166534),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bu tutar kartınızda sadece bloke (ön provizyon) edilir. Usta işi teslim edip siz onay vermeden ustanın hesabına aktarılmaz. Çağrı iptalinde anında açılır.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF166534),
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Onay Butonu
              ElevatedButton(
                onPressed: _isProcessing
                    ? null
                    : () async {
                        setState(() {
                          _isProcessing = true;
                          _errorMessage = null;
                        });
                        try {
                          await widget.onConfirmPayment();
                        } catch (e) {
                          if (mounted) {
                            setState(() {
                              _isProcessing = false;
                              _errorMessage = e.toString().replaceAll('Exception:', '').trim();
                            });
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.customerPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'İyzico 3D Güvenli Provizyon Alınıyor...',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ],
                      )
                    : Text(
                        'Ödemeyi Onayla ve Ustayla Başlat (${widget.pricing.total.toStringAsFixed(0)} ₺)',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
              ),
              const SizedBox(height: 10),

              // Vazgeç Butonu
              TextButton(
                onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                child: const Text(
                  'Vazgeç / İptal',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
