import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ustaapp/core/services/app_data_service.dart';
import 'package:ustaapp/core/services/location_lookup_service.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/map/controllers/map_controller.dart';
import 'package:ustaapp/features/map/models/isletme_model.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';
import 'package:ustaapp/features/map/views/widgets/mechanic_bottom_card.dart';

/// Usta ilanları kart veri modeli
class _ListingCardData {
  final String id;
  final String title;
  final String description;
  final double price;
  final String duration;
  final String icon;
  final String category;
  final NearbyUstaModel usta;
  final UstaHizmetIlan? ilan;

  const _ListingCardData({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.duration,
    required this.icon,
    required this.category,
    required this.usta,
    this.ilan,
  });
}

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'tum';
  bool _isGridView = true; // Alt alta grid görünümü varsayılan
  StreamSubscription? _dataChangedSub;

  final List<Map<String, dynamic>> _categories = const [
    {'key': 'tum', 'label': 'Tüm İlanlar', 'icon': Icons.apps_rounded},
    {'key': 'elektrik', 'label': 'Elektrik & Aydınlatma', 'icon': Icons.bolt_rounded},
    {'key': 'cilingir', 'label': 'Çilingir & Kilit', 'icon': Icons.vpn_key_rounded},
    {'key': 'tesisat', 'label': 'Sıhhi Tesisat & Su', 'icon': Icons.build_rounded},
    {'key': 'tedarikciler', 'label': 'Tedarikçiler / Dükkanlar', 'icon': Icons.storefront_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    _dataChangedSub = AppDataService.instance.onDataChanged.listen((_) {
      if (mounted) {
        ref.read(customerMapControllerProvider.notifier).fetchNearbyUstalar();
        ref.read(customerMapControllerProvider.notifier).fetchIsletmeler();
      }
    });
  }

  @override
  void dispose() {
    _dataChangedSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String categoryKey) {
    setState(() {
      _selectedCategory = categoryKey;
    });
    // Harita kontrolcüsünü de senkronize tut
    if (categoryKey != 'tum') {
      ref.read(customerMapControllerProvider.notifier).setCategory(categoryKey);
    } else {
      ref.read(customerMapControllerProvider.notifier).setCategory('elektrik');
    }
  }

  List<_ListingCardData> _buildListingItems(CustomerMapState mapState) {
    final List<_ListingCardData> items = [];

    for (final usta in mapState.nearbyUstalar) {
      if (usta.ilanlar.isNotEmpty) {
        for (final ilan in usta.ilanlar) {
          items.add(
            _ListingCardData(
              id: '${usta.ustaId}_${ilan.id}',
              title: ilan.baslik,
              description: ilan.aciklama.isNotEmpty
                  ? ilan.aciklama
                  : '${usta.fullName} • ${usta.uzmanlikBasligi}',
              price: ilan.fiyat > 0 ? ilan.fiyat : usta.ustaHakedis,
              duration: ilan.tahminiSure,
              icon: ilan.ikon,
              category: usta.kategori,
              usta: usta,
              ilan: ilan,
            ),
          );
        }
      } else {
        items.add(
          _ListingCardData(
            id: usta.ustaId,
            title: usta.uzmanlikBasligi,
            description: '${usta.deneyimYili}+ yıl tecrübe • Garantili servis',
            price: usta.ustaHakedis,
            duration: '30-45 dk',
            icon: usta.kategori == 'cilingir'
                ? '🔑'
                : usta.kategori == 'tesisat'
                    ? '🔧'
                    : '⚡',
            category: usta.kategori,
            usta: usta,
            ilan: null,
          ),
        );
      }
    }

    return items;
  }

  List<_ListingCardData> _filterListings(List<_ListingCardData> items) {
    return items.where((item) {
      // 1. Kategori filtresi
      if (_selectedCategory != 'tum') {
        final matchesCategory = item.category.toLowerCase().contains(_selectedCategory.toLowerCase()) ||
            _selectedCategory.toLowerCase().contains(item.category.toLowerCase());
        if (!matchesCategory) return false;
      }

      // 2. Arama filtresi
      if (_searchQuery.isNotEmpty) {
        final inTitle = item.title.toLowerCase().contains(_searchQuery);
        final inDesc = item.description.toLowerCase().contains(_searchQuery);
        final inUstaName = item.usta.fullName.toLowerCase().contains(_searchQuery);
        final inCategory = item.category.toLowerCase().contains(_searchQuery);
        return inTitle || inDesc || inUstaName || inCategory;
      }

      return true;
    }).toList();
  }

  List<IsletmeModel> _filterIsletmeler(List<IsletmeModel> isletmeler) {
    if (_searchQuery.isEmpty) return isletmeler;
    return isletmeler.where((isletme) {
      final inName = isletme.ad.toLowerCase().contains(_searchQuery);
      final inCat = isletme.kategori.toLowerCase().contains(_searchQuery);
      final inAddr = isletme.adres.toLowerCase().contains(_searchQuery);
      return inName || inCat || inAddr;
    }).toList();
  }

  void _openBookingSheet(NearbyUstaModel usta, {UstaHizmetIlan? ilan}) {
    ref.read(customerMapControllerProvider.notifier).selectUsta(usta);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(customerMapControllerProvider);
            return MechanicBottomCard(
              nearbyUstalar: state.nearbyUstalar,
              selectedUsta: state.selectedUsta ?? usta,
              isLoadingUstalar: state.isLoadingUstalar,
              onQuickPickUsta: (u) => ref.read(customerMapControllerProvider.notifier).selectUsta(u),
              onClearSelection: () => Navigator.of(ctx).pop(),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddressChangeDialog(String currentAddress) async {
    final textController = TextEditingController(text: currentAddress);
    const presetDistricts = [
      'Sandıklı, Afyonkarahisar',
      'Ece, Sandıklı',
      'Çakır, Sandıklı',
      'Bolvadin, Afyonkarahisar',
      'Kadıköy, İstanbul',
      'Beşiktaş, İstanbul',
      'Çankaya, Ankara',
      'Karşıyaka, İzmir',
    ];

    List<LocationSuggestion> liveSuggestions = [];

    final updated = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Hizmet Adresini Seçin veya Düzenleyin',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.customerTextDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textController,
                      textInputAction: TextInputAction.done,
                      onChanged: (val) async {
                        if (val.trim().length >= 2) {
                          final results = await LocationLookupService.searchAddress(val.trim());
                          if (ctx.mounted) {
                            setSheetState(() => liveSuggestions = results);
                          }
                        } else {
                          if (liveSuggestions.isNotEmpty && ctx.mounted) {
                            setSheetState(() => liveSuggestions = []);
                          }
                        }
                      },
                      onSubmitted: (val) => Navigator.of(ctx).pop(val.trim()),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.location_on_outlined, color: AppTheme.customerPrimary),
                        hintText: 'İlçe, Şehir veya Mahalle yazın...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    if (liveSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: liveSuggestions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final sug = liveSuggestions[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.place_rounded, size: 18, color: AppTheme.customerPrimary),
                              title: Text(
                                sug.shortLabel,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                sug.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                              onTap: () => Navigator.of(ctx).pop(sug.label),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(
                            Icons.my_location_rounded,
                            size: 16,
                            color: AppTheme.customerPrimary,
                          ),
                          label: const Text(
                            'Mevcut GPS Konumum',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.customerPrimary,
                            ),
                          ),
                          backgroundColor: const Color(0xFFEEF2FF),
                          onPressed: () => Navigator.of(ctx).pop('__USE_GPS__'),
                        ),
                        ...presetDistricts.map((district) {
                          final isCurrent = district == currentAddress;
                          return ActionChip(
                            label: Text(
                              district,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                color: isCurrent ? Colors.white : AppTheme.customerTextDark,
                              ),
                            ),
                            backgroundColor: isCurrent ? AppTheme.customerPrimary : const Color(0xFFF8FAFC),
                            onPressed: () => Navigator.of(ctx).pop(district),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(textController.text.trim()),
                      child: const Text('Konumu Güncelle'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    textController.dispose();
    if (updated == null || updated.isEmpty) return;

    final mapNotifier = ref.read(customerMapControllerProvider.notifier);
    if (updated == '__USE_GPS__') {
      final moved = await mapNotifier.useCurrentGpsLocation();
      if (!moved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS konumu alınamadı. Konum iznini kontrol edin.')),
        );
      }
    } else {
      final moved = await mapNotifier.updateLocationByAddress(updated);
      if (!moved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adres bulunamadı. Lütfen geçerli bir ilçe veya şehir yazın.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(customerMapControllerProvider);
    final rawListings = _buildListingItems(mapState);
    final filteredListings = _filterListings(rawListings);
    final filteredIsletmeler = _filterIsletmeler(mapState.isletmeler);

    final isTedarikci = _selectedCategory == 'tedarikciler';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. ÜST HEADER: Konum, Bildirim ve Profil
            _buildTopHeader(mapState),

            // 2. ARAMA VE KATEGORİ ÇUBUĞU
            _buildSearchBar(),
            _buildCategorySelector(),

            // 3. İLAN LİSTESİ / GRİD İÇERİĞİ
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.customerPrimary,
                onRefresh: () async {
                  await Future.wait([
                    ref.read(customerMapControllerProvider.notifier).fetchNearbyUstalar(),
                    ref.read(customerMapControllerProvider.notifier).fetchIsletmeler(),
                  ]);
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    // Bilgi & Güvence Şeridi
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        child: _buildGuaranteeBanner(),
                      ),
                    ),

                    // Başlık ve Filtre Sayacı
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                        child: Row(
                          children: [
                            Text(
                              isTedarikci ? 'Yetkili Dükkan & Tedarikçiler' : 'Usta Hizmet İlanları',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isTedarikci
                                    ? '${filteredIsletmeler.length}'
                                    : '${filteredListings.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Grid / Liste Görünüm Değiştirici
                            if (!isTedarikci)
                              InkWell(
                                onTap: () => setState(() => _isGridView = !_isGridView),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Icon(
                                    _isGridView ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
                                    size: 19,
                                    color: AppTheme.customerPrimary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // İlanlar veya Dükkanlar
                    if (isTedarikci)
                      _buildTedarikcilerSliver(filteredIsletmeler, mapState.isLoadingUstalar)
                    else if (_isGridView)
                      _buildGridSliver(filteredListings, mapState.isLoadingUstalar)
                    else
                      _buildListSliver(filteredListings, mapState.isLoadingUstalar),

                    // Alt butona alan bırakmak için boşluk
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 90),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // 4. ALT SABİT / YÜZEN: HARİTA ÜZERİNDE USTA ARA BUTONU
      bottomNavigationBar: _buildBottomMapSearchButton(),
    );
  }

  /// Üst Navigasyon & Konum Başlığı
  Widget _buildTopHeader(CustomerMapState mapState) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Konum Seçici Pill
          Expanded(
            child: InkWell(
              onTap: () => _showAddressChangeDialog(mapState.currentAddressLabel),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.customerPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: AppTheme.customerPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Hizmet Konumu',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  mapState.currentAddressLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: AppTheme.customerPrimary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Bildirim Butonu
          _buildCircleIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Bildirimler',
            hasBadge: true,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tüm çağrılarınız İyzico güvencesi altında. Yeni bildiriminiz yok.'),
                ),
              );
            },
          ),
          const SizedBox(width: 8),

          // Profil Butonu
          _buildCircleIconButton(
            icon: Icons.person_outline_rounded,
            tooltip: 'Profilim',
            onTap: () => context.push('/profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool hasBadge = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 20, color: const Color(0xFF1E293B)),
              if (hasBadge)
                Positioned(
                  top: 9,
                  right: 9,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.ustaPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Modern Arama Çubuğu
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Usta, ilan veya hizmet ara (Örn: Çilingir, Priz)...',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                    onPressed: () => _searchController.clear(),
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ),
    );
  }

  /// Yatay Kategori Çubuğu
  Widget _buildCategorySelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final isSelected = cat['key'] == _selectedCategory;

            return InkWell(
              onTap: () => _onCategorySelected(cat['key'] as String),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat['icon'] as IconData,
                      size: 15,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat['label'] as String,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Güvence & Hızlı Servis Banner
  Widget _buildGuaranteeBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x261E3A8A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sabit Fiyat & İyzico Güvencesi',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'İşiniz onaylanana kadar ödemeniz koruma havuzunda bekler.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFFE2E8F0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Usta gerçekçi profil resmi URL yardımcısı
  String _getUstaAvatarUrl(NearbyUstaModel usta) {
    if (usta.avatarUrl != null && usta.avatarUrl!.trim().isNotEmpty) {
      return usta.avatarUrl!;
    }
    final cat = usta.kategori.toLowerCase();
    if (cat.contains('cilingir')) {
      return 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=600&auto=format&fit=crop';
    } else if (cat.contains('tesisat')) {
      return 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?q=80&w=600&auto=format&fit=crop';
    } else if (cat.contains('elektrik')) {
      return 'https://images.unsplash.com/photo-1541888946425-d0fbb186156f?q=80&w=600&auto=format&fit=crop';
    }
    return 'https://images.unsplash.com/photo-1541888946425-d0fbb186156f?q=80&w=600&auto=format&fit=crop';
  }

  /// Güvenilir resim yükleyici: Ağ hatası veya çevrimdışı durumda kaliteli yerel usta görseline düşer
  Widget _buildUstaImage(String url, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/images/hero_worker_hd.png',
          width: width,
          height: height,
          fit: fit,
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height,
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.customerPrimary),
            ),
          ),
        );
      },
    );
  }

  /// Alt alta 2 sütunlu Grid Sliver Görünümü
  Widget _buildGridSliver(List<_ListingCardData> items, bool isLoading) {
    if (isLoading && items.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.customerPrimary),
        ),
      );
    }

    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          childAspectRatio: 0.62,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            return _buildGridCard(item);
          },
          childCount: items.length,
        ),
      ),
    );
  }

  /// Liste Sliver Görünümü (Alternatif)
  Widget _buildListSliver(List<_ListingCardData> items, bool isLoading) {
    if (isLoading && items.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.customerPrimary),
        ),
      );
    }

    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildListCard(item),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }

  /// Tekil Profesyonel Grid Kartı
  Widget _buildGridCard(_ListingCardData item) {
    final usta = item.usta;
    final photoUrl = _getUstaAvatarUrl(usta);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E0F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openBookingSheet(usta, ilan: item.ilan),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. ÜST: USTA PROFİL RESMİ VE ROZETLER
              SizedBox(
                height: 114,
                child: Stack(
                  children: [
                    // Usta Profil Fotoğrafı
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                        child: _buildUstaImage(photoUrl, height: 114, fit: BoxFit.cover),
                      ),
                    ),

                    // Üst Karartma Gradyanı (Rozetlerin net okunması için)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    // Alt Karartma Gradyanı
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 42,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.65),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    // Sol Üst: Kategori İkonu ve Adı
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xCC0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(item.icon, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              usta.kategori.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Sağ Üst: Puan Rozeti
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 13, color: Color(0xFFD97706)),
                            const SizedBox(width: 2),
                            Text(
                              usta.puan.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Sol Alt: Onaylı Usta Rozeti
                    Positioned(
                      bottom: 6,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user_rounded, size: 10, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              'Onaylı Usta',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Sağ Alt: Tahmini Varış
                    Positioned(
                      bottom: 6,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xCC0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${usta.tahminiVarisDakika} dk',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. ORTA: USTA BİLGİSİ, BAŞLIK VE AYRINTILAR
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Usta Adı ve Doğrulama
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _buildUstaImage(photoUrl, width: 18, height: 18),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              usta.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 13,
                            color: Color(0xFF3B82F6),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // İlan Başlığı (2 Satır, Net ve Kalın)
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          height: 1.22,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Tahmini Süre & Garanti Şeridi
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF64748B)),
                          const SizedBox(width: 3),
                          Text(
                            item.duration,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                          const SizedBox(width: 6),
                          const Text(
                            'Garantili',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // 3. ALT: FİYAT VE ÇAĞIR BUTONU
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'TABAN',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF94A3B8),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                Text(
                                  '${item.price.toStringAsFixed(0)} ₺',
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF15803D),
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Çağır',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 3),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tekil Profesyonel Liste Kartı
  Widget _buildListCard(_ListingCardData item) {
    final usta = item.usta;
    final photoUrl = _getUstaAvatarUrl(usta);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openBookingSheet(usta, ilan: item.ilan),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Sol Usta Portre Fotoğrafı (Rozetli)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _buildUstaImage(photoUrl, width: 82, height: 82),
                    ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xCC0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.icon,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 12, color: Color(0xFFD97706)),
                            const SizedBox(width: 1),
                            Text(
                              usta.puan.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Orta Metinler
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
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF3B82F6)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${usta.kategori} • ${item.duration}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '• 📍 ${usta.tahminiVarisDakika} dk varış',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Sağ Fiyat & Çağır Butonu
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.price.toStringAsFixed(0)} ₺',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF15803D),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Çağır',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tedarikçiler / Dükkanlar Kartları
  Widget _buildTedarikcilerSliver(List<IsletmeModel> isletmeler, bool isLoading) {
    if (isLoading && isletmeler.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.customerPrimary),
        ),
      );
    }

    if (isletmeler.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(message: 'Bölgenizde kayıtlı tedarikçi veya dükkan bulunmuyor.'),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final shop = isletmeler[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Icon(
                        Icons.store_rounded,
                        color: Color(0xFFD97706),
                        size: 24,
                      ),
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
                                  shop.ad,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (shop.isSponsored) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'ÖNE ÇIKAN',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${shop.kategori} • ${shop.adres}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '📞 ${shop.telefon}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      onPressed: () {
                        final uri = Uri.parse('tel:${shop.telefon}');
                        launchUrl(uri);
                      },
                      child: const Text('Ara', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: isletmeler.length,
        ),
      ),
    );
  }

  /// Boş Durum Görünümü
  Widget _buildEmptyState({String message = 'Bu kategoride veya aramada ilan bulunamadı.'}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 40,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Farklı bir arama yapabilir veya harita üzerinden tüm ustaları inceleyebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Tüm İlanları Göster'),
              onPressed: () {
                _searchController.clear();
                _onCategorySelected('tum');
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Alt Kısım: Harita Üzerinde Usta Ara Butonu
  Widget _buildBottomMapSearchButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 6 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: const Color(0x400F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18),
          ),
          onPressed: () {
            context.push('/customer/map');
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.map_rounded,
                  size: 20,
                  color: Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Harita Üzerinde Usta Ara',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
