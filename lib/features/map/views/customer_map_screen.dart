import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/map/controllers/map_controller.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';
import 'package:ustaapp/features/map/views/widgets/category_filter_bar.dart';
import 'package:ustaapp/features/map/views/widgets/mechanic_bottom_card.dart';

class CustomerMapScreen extends ConsumerStatefulWidget {
  const CustomerMapScreen({super.key});

  @override
  ConsumerState<CustomerMapScreen> createState() => _CustomerMapScreenState();
}

class _CustomerMapScreenState extends ConsumerState<CustomerMapScreen> {
  static const double _defaultKadikoyLat = 40.9905;
  static const double _defaultKadikoyLng = 29.0270;
  static const double _defaultZoom = 13.5;

  // Sabit ilk viewport referansı: build() tetiklendiğinde haritanın kamerasını sıfırlamamasını sağlar.
  late final CameraViewportState _initialViewport = CameraViewportState(
    center: Point(
      coordinates: Position(_defaultKadikoyLng, _defaultKadikoyLat),
    ),
    zoom: _defaultZoom,
  );

  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  Cancelable? _annotationTapCancelable;

  final Map<String, Uint8List> _markerBytesCache = {};
  final Map<String, NearbyUstaModel> _annotationIdToUsta = {};
  Uint8List? _customerPinBytes;

  bool _isSyncingAnnotations = false;
  bool _needsResync = false;
  String? _lastSyncedSignature;
  CustomerMapState? _latestMapState;

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(AppConstants.mapboxAccessToken);
    _initCustomerIcon();
  }

  @override
  void dispose() {
    _annotationTapCancelable?.cancel();
    super.dispose();
  }

  Future<void> _initCustomerIcon() async {
    _customerPinBytes = await _createCustomerLocationBytes();
    final state = _latestMapState;
    if (mounted && state != null && _pointAnnotationManager != null) {
      await _syncAnnotations(state, force: true);
    }
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Üst durum çubuğuyla çakışmaması için varsayılan ölçek çubuğu ve pusulayı gizle
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));

    // Yakınlaştırma / kaydırma / çift dokunma jestlerini açıkça etkinleştir
    await mapboxMap.gestures.updateSettings(
      GesturesSettings(
        scrollEnabled: true,
        pinchToZoomEnabled: true,
        doubleTapToZoomInEnabled: true,
        doubleTouchToZoomOutEnabled: true,
        quickZoomEnabled: true,
        rotateEnabled: true,
      ),
    );

    // Arka plan haritaya dokunulduğunda seçili ustayı temizle
    mapboxMap.addInteraction(
      TapInteraction.onMap((_) {
        if (mounted) {
          ref.read(customerMapControllerProvider.notifier).clearSelectedUsta();
        }
      }),
    );

    final manager = await mapboxMap.annotations.createPointAnnotationManager();
    await manager.setIconAllowOverlap(true);
    await manager.setIconIgnorePlacement(true);

    _annotationTapCancelable = manager.tapEvents(
      onTap: (PointAnnotation annotation) {
        final usta = _annotationIdToUsta[annotation.id];
        if (usta != null && mounted) {
          final notifier = ref.read(customerMapControllerProvider.notifier);
          _selectAndFocusUsta(usta, notifier);
        }
      },
    );

    _pointAnnotationManager = manager;

    final state = _latestMapState;
    if (mounted && state != null) {
      if (state.currentLat != _defaultKadikoyLat ||
          state.currentLng != _defaultKadikoyLng) {
        await mapboxMap.setCamera(
          CameraOptions(
            center: Point(
              coordinates: Position(state.currentLng, state.currentLat),
            ),
            zoom: _defaultZoom,
          ),
        );
      }
      await _syncAnnotations(state, force: true);
    }
  }

  String _buildSyncSignature(CustomerMapState mapState) {
    final ids = mapState.nearbyUstalar
        .map(
          (u) =>
              '${u.ustaId}:${u.latitude.toStringAsFixed(5)}:${u.longitude.toStringAsFixed(5)}:${u.formattedPrice}:${u.puan}',
        )
        .join(',');
    return '${mapState.currentLat}_${mapState.currentLng}_'
        '${mapState.selectedUsta?.ustaId}_$ids';
  }

  Future<void> _syncAnnotations(
    CustomerMapState mapState, {
    bool force = false,
  }) async {
    final manager = _pointAnnotationManager;
    if (manager == null) return;

    final signature = _buildSyncSignature(mapState);
    if (!force && signature == _lastSyncedSignature) return;

    if (_isSyncingAnnotations) {
      _needsResync = true;
      return;
    }

    _isSyncingAnnotations = true;
    try {
      _lastSyncedSignature = signature;
      await manager.deleteAll();
      _annotationIdToUsta.clear();

      // 1. Müşteri konum pini
      _customerPinBytes ??= await _createCustomerLocationBytes();
      await manager.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(mapState.currentLng, mapState.currentLat),
          ),
          image: _customerPinBytes,
          iconAnchor: IconAnchor.CENTER,
          iconSize: 0.85,
        ),
      );

      // 2. Yakındaki ustaların özel rozet pinleri
      for (final usta in mapState.nearbyUstalar) {
        final isSelected = mapState.selectedUsta?.ustaId == usta.ustaId;
        final cacheKey =
            '${usta.ustaId}_${usta.formattedPrice}_${usta.puan}_$isSelected';
        final bytes = _markerBytesCache[cacheKey] ??
            await _createUstaBadgeBytes(usta: usta, isSelected: isSelected);
        _markerBytesCache[cacheKey] = bytes;

        final annotation = await manager.create(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(usta.longitude, usta.latitude),
            ),
            image: bytes,
            iconAnchor: IconAnchor.BOTTOM,
            iconSize: isSelected ? 1.15 : 1.00,
            symbolSortKey: isSelected ? 10.0 : 5.0,
          ),
        );
        _annotationIdToUsta[annotation.id] = usta;
      }
    } finally {
      _isSyncingAnnotations = false;
      if (_needsResync && mounted && _latestMapState != null) {
        _needsResync = false;
        await _syncAnnotations(_latestMapState!, force: true);
      }
    }
  }

  /// Müşteri Konumu İçin Mavi Radarlı Mapbox Pin Görseli
  Future<Uint8List> _createCustomerLocationBytes() async {
    const double size = 108;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);

    canvas.drawCircle(
      center,
      46,
      Paint()..color = AppTheme.customerSecondary.withValues(alpha: 0.22),
    );
    canvas.drawCircle(
      center,
      46,
      Paint()
        ..color = AppTheme.customerSecondary.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(center, 22, Paint()..color = Colors.white);
    canvas.drawCircle(center, 16, Paint()..color = AppTheme.customerPrimary);

    final img =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Usta Pin Rozeti (★ 4.9 Ahmet Y. + 920 ₺ koyu hap + alt üçgen ok)
  Future<Uint8List> _createUstaBadgeBytes({
    required NearbyUstaModel usta,
    required bool isSelected,
  }) async {
    const double scale = 2.6;
    const double width = 166 * scale;
    const double badgeHeight = 64 * scale;
    const double pointerHeight = 11 * scale;
    const double totalHeight = badgeHeight + pointerHeight + 12 * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final Color bgColor = isSelected ? AppTheme.ustaPrimary : Colors.white;
    final Color textColor =
        isSelected ? Colors.white : const Color(0xFF0F172A);
    final Color pillBgColor =
        isSelected ? Colors.white : const Color(0xFF0F172A);
    final Color pillTextColor =
        isSelected ? AppTheme.ustaPrimary : Colors.white;
    final Color borderColor =
        isSelected ? Colors.white : const Color(0xFFE2E8F0);

    final badgeRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(8, 4, width - 16, badgeHeight),
      const Radius.circular(18 * scale),
    );

    canvas.drawRRect(
      badgeRect.shift(const Offset(0, 6)),
      Paint()
        ..color = isSelected
            ? AppTheme.ustaPrimary.withValues(alpha: 0.38)
            : Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawRRect(badgeRect, Paint()..color = bgColor);
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isSelected ? 2.4 : 1.5) * scale,
    );

    final topTextPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
      text: TextSpan(
        children: [
          TextSpan(
            text: '★ ',
            style: TextStyle(
              fontSize: 14 * scale,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.amber.shade200 : Colors.amber.shade600,
            ),
          ),
          TextSpan(
            text: '${usta.puan.toStringAsFixed(1)} ${usta.shortDisplayName}',
            style: TextStyle(
              fontSize: 13.5 * scale,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    )..layout(maxWidth: width - 32);

    topTextPainter.paint(
      canvas,
      Offset((width - topTextPainter.width) / 2, 10 * scale),
    );

    final priceTextPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: usta.formattedPrice,
        style: TextStyle(
          fontSize: 14 * scale,
          fontWeight: FontWeight.w900,
          color: pillTextColor,
        ),
      ),
    )..layout();

    final double pillW = priceTextPainter.width + 26 * scale;
    const double pillH = 25 * scale;
    final double pillLeft = (width - pillW) / 2;
    const double pillTop = 33 * scale;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pillLeft, pillTop, pillW, pillH),
        const Radius.circular(11 * scale),
      ),
      Paint()..color = pillBgColor,
    );

    priceTextPainter.paint(
      canvas,
      Offset(
        pillLeft + (pillW - priceTextPainter.width) / 2,
        pillTop + (pillH - priceTextPainter.height) / 2,
      ),
    );

    const double pointerY = 4 + badgeHeight - 2;
    final trianglePath = Path()
      ..moveTo(width / 2 - 8 * scale, pointerY)
      ..lineTo(width / 2, pointerY + pointerHeight)
      ..lineTo(width / 2 + 8 * scale, pointerY)
      ..close();

    canvas.drawPath(
      trianglePath,
      Paint()
        ..color = isSelected ? AppTheme.ustaPrimary : const Color(0xFF0F172A),
    );

    final image = await recorder
        .endRecording()
        .toImage(width.toInt(), totalHeight.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _selectAndFocusUsta(
    NearbyUstaModel usta,
    CustomerMapController mapNotifier,
  ) {
    mapNotifier.selectUsta(usta);
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(usta.longitude, usta.latitude - 0.0012),
        ),
        zoom: 14.8,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  Future<void> _animateToCustomerLocation(
    CustomerMapState mapState,
    CustomerMapController mapNotifier,
  ) async {
    mapNotifier.clearSelectedUsta();
    await _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(mapState.currentLng, mapState.currentLat),
        ),
        zoom: _defaultZoom,
      ),
      MapAnimationOptions(duration: 650),
    );
  }

  Future<void> _zoomBy(double delta) async {
    final map = _mapboxMap;
    if (map == null) return;
    final camera = await map.getCameraState();
    final targetZoom = (camera.zoom + delta).clamp(3.0, 20.0);
    await map.flyTo(
      CameraOptions(
        center: camera.center,
        zoom: targetZoom,
      ),
      MapAnimationOptions(duration: 280),
    );
  }

  Future<void> _showAddressChangeDialog(
    String currentAddress,
    CustomerMapController mapNotifier,
  ) async {
    final textController = TextEditingController(text: currentAddress);
    const presetDistricts = [
      'Kadıköy, İstanbul',
      'Beşiktaş, İstanbul',
      'Bolvadin, Afyonkarahisar',
      'Sandıklı, Afyonkarahisar',
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
                textInputAction: TextInputAction.done,
                onSubmitted: (val) => Navigator.of(ctx).pop(val.trim()),
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
                          fontWeight:
                              isCurrent ? FontWeight.w700 : FontWeight.w500,
                          color: isCurrent
                              ? Colors.white
                              : AppTheme.customerTextDark,
                        ),
                      ),
                      backgroundColor: isCurrent
                          ? AppTheme.customerPrimary
                          : const Color(0xFFF8FAFC),
                      onPressed: () => Navigator.of(ctx).pop(district),
                    );
                  }),
                ],
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
    if (updated == null || updated.isEmpty) return;

    final bool moved;
    if (updated == '__USE_GPS__') {
      moved = await mapNotifier.useCurrentGpsLocation();
      if (!moved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPS konumu alınamadı. Konum iznini kontrol edin.'),
          ),
        );
      }
    } else {
      moved = await mapNotifier.updateLocationByAddress(updated);
      if (!moved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Adres haritada bulunamadı. Lütfen geçerli bir ilçe veya şehir yazın.',
            ),
          ),
        );
      }
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
    _latestMapState = mapState;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncAnnotations(mapState);
      }
    });

    ref.listen<CustomerMapState>(customerMapControllerProvider, (previous, next) {
      if (previous?.currentLat != next.currentLat ||
          previous?.currentLng != next.currentLng) {
        _mapboxMap?.flyTo(
          CameraOptions(
            center: Point(
              coordinates: Position(next.currentLng, next.currentLat),
            ),
            zoom: _defaultZoom,
          ),
          MapAnimationOptions(duration: 600),
        );
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

    return Scaffold(
      backgroundColor: AppTheme.customerBackground,
      body: Stack(
        children: [
          // 1. RESMİ MAPBOX HARİTA KATMANI (Minimalist Light-v11 Tema)
          Positioned.fill(
            child: MapWidget(
              key: const ValueKey('customer_mapbox_map'),
              styleUri: MapboxStyles.LIGHT, // mapbox://styles/mapbox/light-v11
              viewport: _initialViewport,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
              onMapCreated: _onMapCreated,
            ),
          ),

          // 2. ÜST YÜZEN GLASSMORPHISM NAVİGASYON & KATEGORİ FİLTRELEME
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
          if (mapState.isLoadingUstalar || mapState.isLoadingLocation)
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

          // 4. SAĞ ALT DAİRESEL KONUM FAB + ALT ÖZET / DETAY KARTI
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MapCircleControlButton(
                        icon: Icons.add_rounded,
                        tooltip: 'Yakınlaştır',
                        onTap: () => _zoomBy(1.2),
                      ),
                      const SizedBox(height: 8),
                      _MapCircleControlButton(
                        icon: Icons.remove_rounded,
                        tooltip: 'Uzaklaştır',
                        onTap: () => _zoomBy(-1.2),
                      ),
                      const SizedBox(height: 10),
                      _MapCircleControlButton(
                        icon: Icons.my_location_rounded,
                        iconColor: AppTheme.customerPrimary,
                        tooltip: 'Konumuma Git',
                        onTap: () => _animateToCustomerLocation(
                          mapState,
                          mapNotifier,
                        ),
                      ),
                    ],
                  ),
                ),
                MechanicBottomCard(
                  nearbyUstalar: mapState.nearbyUstalar,
                  selectedUsta: mapState.selectedUsta,
                  isLoadingUstalar: mapState.isLoadingUstalar,
                  onQuickPickUsta: (usta) =>
                      _selectAndFocusUsta(usta, mapNotifier),
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

class _MapCircleControlButton extends StatelessWidget {
  const _MapCircleControlButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.iconColor = const Color(0xFF0F172A),
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
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
            onTap: onTap,
            child: Icon(
              icon,
              size: 22,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
