import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/map/controllers/map_controller.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';
import 'package:ustaapp/features/map/views/widgets/usta_detail_sheet.dart';

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

  void _showUstaBottomSheet(NearbyUstaModel usta) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UstaDetailSheet(usta: usta),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(customerMapControllerProvider);
    final mapNotifier = ref.read(customerMapControllerProvider.notifier);

    // Müşteri konumu güncellendiğinde haritayı merkeze al
    ref.listen<CustomerMapState>(customerMapControllerProvider, (previous, next) {
      if (previous?.currentLat != next.currentLat || previous?.currentLng != next.currentLng) {
        _mapController.move(LatLng(next.currentLat, next.currentLng), 14.0);
      }
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: Colors.redAccent),
        );
      }
    });

    final customerLatLng = LatLng(mapState.currentLat, mapState.currentLng);

    return Scaffold(
      backgroundColor: AppTheme.customerBackground,
      appBar: AppBar(
        title: const Text('UstamBurada'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded),
            tooltip: 'Profil',
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Çıkış Yap',
            onPressed: () async => await ref.read(supabaseServiceProvider).signOut(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. FLUTTER_MAP HARİTA KATMANI
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: customerLatLng,
              initialZoom: 14.0,
              minZoom: 6.0,
              maxZoom: 18.0,
            ),
            children: [
              // OpenStreetMap Karo Katmanı
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ustamburada.app',
              ),

              // Marker Katmanı (Müşteri & Ustalar)
              MarkerLayer(
                markers: [
                  // A. MÜŞTERİ KONUM MARKER'I (Mavi Halka & Pin)
                  Marker(
                    point: customerLatLng,
                    width: 48,
                    height: 48,
                    child: _buildCustomerMarker(),
                  ),

                  // B. YAKINDAKİ AKTİF USTALARIN MARKER'LARI
                  ...mapState.nearbyUstalar.map((usta) {
                    final ustaLatLng = LatLng(usta.latitude, usta.longitude);
                    return Marker(
                      point: ustaLatLng,
                      width: 170,
                      height: 52,
                      child: GestureDetector(
                        onTap: () {
                          mapNotifier.selectUsta(usta);
                          _showUstaBottomSheet(usta);
                        },
                        child: _buildUstaBadgeMarker(usta),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),

          // 2. ÜSTTE YATAY KAYDIRILABİLİR KATEGORİ SEÇİM BARI
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: _buildHorizontalCategoryBar(mapState, mapNotifier),
          ),

          // 3. YÜKLENİYOR GÖSTERGESİ
          if (mapState.isLoadingUstalar)
            Positioned(
              top: 76,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.customerPrimary),
                      ),
                      SizedBox(width: 8),
                      Text('Ustalar taranıyor...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),

          // 4. SAĞ ALT MEVCUT KONUMUMA GİT BUTONU
          Positioned(
            bottom: 24,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'my_location_btn',
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.customerPrimary,
              elevation: 4,
              onPressed: () {
                _mapController.move(customerLatLng, 14.5);
              },
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
        ],
      ),
    );
  }

  /// Müşteri Konum Pin'i
  Widget _buildCustomerMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.customerSecondary.withOpacity(0.2),
          ),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.customerPrimary,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Usta Rozet Marker'ı (Örn: '🟢 Hasan Usta • 1.725 ₺')
  Widget _buildUstaBadgeMarker(NearbyUstaModel usta) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Yeşil Çevrimiçi Işık Noktası
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 6),
              // Usta Adı
              Flexible(
                child: Text(
                  usta.fullName.split(' ').first, // İlk isim
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.customerTextDark,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              // Nihai Fiyat
              Text(
                usta.formattedPrice,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.customerPrimary,
                ),
              ),
            ],
          ),
        ),
        // Küçük İbre Oku
        CustomPaint(
          size: const Size(10, 6),
          painter: _TrianglePainter(color: Colors.white),
        ),
      ],
    );
  }

  /// Yatay Kaydırılabilir Kategori Seçim Barı [⚡ Elektrik, 🔑 Çilingir, 🔧 Tesisat]
  Widget _buildHorizontalCategoryBar(
    CustomerMapState state,
    CustomerMapController notifier,
  ) {
    final categories = [
      {'key': 'elektrik', 'label': 'Elektrik', 'emoji': '⚡'},
      {'key': 'cilingir', 'label': 'Çilingir', 'emoji': '🔑'},
      {'key': 'tesisat', 'label': 'Tesisat', 'emoji': '🔧'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: categories.map((cat) {
          final isSelected = state.selectedCategory == cat['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => notifier.setCategory(cat['key']!),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.customerPrimary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppTheme.customerPrimary : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? AppTheme.customerPrimary.withOpacity(0.25)
                            : Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(cat['emoji']!, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(
                        cat['label']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppTheme.customerTextDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Marker altındaki küçük üçgen ibre
class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
