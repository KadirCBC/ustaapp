import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/map/controllers/map_controller.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';
import 'package:ustaapp/features/map/views/widgets/category_filter_bar.dart';
import 'package:ustaapp/features/map/views/widgets/map_widget.dart';
import 'package:ustaapp/features/map/views/widgets/mechanic_bottom_card.dart';

class CustomerMapScreen extends ConsumerStatefulWidget {
  const CustomerMapScreen({super.key});

  @override
  ConsumerState<CustomerMapScreen> createState() => _CustomerMapScreenState();
}

class _CustomerMapScreenState extends ConsumerState<CustomerMapScreen> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _selectAndCenterUsta(
    NearbyUstaModel usta,
    CustomerMapController mapNotifier,
  ) {
    mapNotifier.selectUsta(usta);
    // Pin alt panelin üstünde görünür kalsın diye merkezi hafif aşağı kaydırıyoruz
    _mapController.move(
      LatLng(usta.latitude - 0.0014, usta.longitude),
      14.8,
    );
  }

  Future<void> _showAddressChangeDialog(
    String currentAddress,
    CustomerMapController mapNotifier,
  ) async {
    final textController = TextEditingController(text: currentAddress);
    const presetDistricts = [
      'Sandıklı, Afyonkarahisar',
      'Kadıköy, İstanbul',
      'Beşiktaş, İstanbul',
      'Çankaya, Ankara',
      'Karşıyaka, İzmir',
    ];

    final updated = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  hintText: 'İlçe, Şehir veya Mahalle yazın...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presetDistricts.map((district) {
                  return ActionChip(
                    label: Text(district, style: const TextStyle(fontSize: 12)),
                    backgroundColor: const Color(0xFFF8FAFC),
                    onPressed: () => Navigator.of(ctx).pop(district),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(textController.text.trim()),
                child: const Text('Konumu Güncelle'),
              ),
            ],
          ),
        );
      },
    );

    textController.dispose();
    if (updated != null && updated.isNotEmpty) {
      mapNotifier.setAddressLabel(updated);
    }
  }

  void _showNotificationsSheet() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tüm çağrılarınız İyzico güvencesi altında. Yeni bildirim yok.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(customerMapControllerProvider);
    final mapNotifier = ref.read(customerMapControllerProvider.notifier);

    ref.listen<CustomerMapState>(customerMapControllerProvider, (previous, next) {
      if (previous?.currentLat != next.currentLat ||
          previous?.currentLng != next.currentLng) {
        _mapController.move(LatLng(next.currentLat, next.currentLng), 14.2);
      }
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    });

    final customerLatLng = LatLng(mapState.currentLat, mapState.currentLng);

    return Scaffold(
      backgroundColor: AppTheme.customerBackground,
      body: Stack(
        children: [
          // 1. MİNİMALİST HARİTA & PROFESYONEL PİN KATMANI
          Positioned.fill(
            child: MapWidget(
              mapController: _mapController,
              customerLatLng: customerLatLng,
              ustalar: mapState.nearbyUstalar,
              selectedUsta: mapState.selectedUsta,
              onUstaTap: (usta) => _selectAndCenterUsta(usta, mapNotifier),
              onMapBackgroundTap: mapNotifier.clearSelectedUsta,
            ),
          ),

          // 2. ÜST GLASSMORPHISM NAVİGASYON & KATEGORİ FİLTRE BARI
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: FloatingTopNav(
                addressLabel: mapState.currentAddressLabel,
                selectedCategory: mapState.selectedCategory,
                onChangeAddressTap: () => _showAddressChangeDialog(
                  mapState.currentAddressLabel,
                  mapNotifier,
                ),
                onNotificationTap: _showNotificationsSheet,
                onProfileTap: () => context.push('/profile'),
                onCategorySelected: mapNotifier.setCategory,
              ),
            ),
          ),

          // 3. YÜKLENİYOR HAP GÖSTERGESİ
          if (mapState.isLoadingUstalar)
            Positioned(
              top: MediaQuery.of(context).padding.top + 132,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.customerPrimary,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Yakındaki ustalar taranıyor...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.customerTextDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. SAĞ ALT 'KONUMUMA GİT' FAB + ALT KAYAN PANEL
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 12),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          mapNotifier.clearSelectedUsta();
                          _mapController.move(customerLatLng, 14.4);
                        },
                        child: const Icon(
                          Icons.my_location_rounded,
                          size: 22,
                          color: AppTheme.customerPrimary,
                        ),
                      ),
                    ),
                  ),
                ),

                MechanicBottomCard(
                  nearbyUstalar: mapState.nearbyUstalar,
                  selectedUsta: mapState.selectedUsta,
                  isLoadingUstalar: mapState.isLoadingUstalar,
                  onQuickPickUsta: (usta) =>
                      _selectAndCenterUsta(usta, mapNotifier),
                  onClearSelection: mapNotifier.clearSelectedUsta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
