import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/core/services/location_lookup_service.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/core/widgets/notification_sheet.dart';
import 'package:ustaapp/features/auth/models/user_role.dart';
import 'package:ustaapp/features/map/controllers/map_controller.dart';
import 'package:ustaapp/features/map/models/isletme_model.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';
import 'package:ustaapp/features/map/views/widgets/category_filter_bar.dart';
import 'package:ustaapp/features/map/views/widgets/custom_marker.dart';
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

  // Web ortamı için etkileşimli Flutter rozet pozisyonları
  Offset? _customerScreenPos;
  Map<String, Offset> _ustaScreenPos = {};
  Map<String, Offset> _isletmeScreenPos = {};
  bool _isUpdatingWebPositions = false;
  bool _hasPendingWebUpdate = false;

  final Map<String, Uint8List> _markerBytesCache = {};
  final Map<String, NearbyUstaModel> _annotationIdToUsta = {};
  final Map<String, IsletmeModel> _annotationIdToIsletme = {};
  Uint8List? _customerPinBytes;
  ui.Image? _ustaPinImage;
  ui.Image? _isletmePinImage;

  bool _isSyncingAnnotations = false;
  bool _needsResync = false;
  String? _lastSyncedSignature;
  CustomerMapState? _latestMapState;

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(AppConstants.mapboxAccessToken);
    _initPinAssets();
  }

  @override
  void dispose() {
    _annotationTapCancelable?.cancel();
    super.dispose();
  }

  Future<ui.Image> _loadUiImage(String assetPath, {int? targetWidth, int? targetHeight}) async {
    final ByteData data = await rootBundle.load(assetPath);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final ui.FrameInfo fi = await codec.getNextFrame();
    return fi.image;
  }

  Future<void> _initPinAssets() async {
    try {
      _customerPinBytes = await _createCustomerLocationBytes();
      if (!kIsWeb) {
        _ustaPinImage ??= await _loadUiImage('assets/images/pin_usta.png', targetWidth: 140);
        _isletmePinImage ??= await _loadUiImage('assets/images/pin_isletme.png', targetWidth: 140);
      }
    } catch (e) {
      debugPrint('>>> [_initPinAssets] Error loading pin assets: $e');
    }
    final state = _latestMapState;
    if (mounted && state != null && _pointAnnotationManager != null) {
      await _syncAnnotations(state, force: true);
    }
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    debugPrint('>>> [_onMapCreated] START');
    _mapboxMap = mapboxMap;

    try {
      await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    } catch (e) {
      debugPrint('>>> [_onMapCreated] scaleBar error: $e');
    }
    try {
      await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
    } catch (e) {
      debugPrint('>>> [_onMapCreated] compass error: $e');
    }

    try {
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
    } catch (e) {
      debugPrint('>>> [_onMapCreated] gestures error: $e');
    }

    // Arka plan haritaya dokunulduğunda seçili usta veya dükkanı temizle
    try {
      mapboxMap.addInteraction(
        TapInteraction.onMap((_) {
          if (mounted) {
            final notifier = ref.read(customerMapControllerProvider.notifier);
            notifier.clearSelectedUsta();
            notifier.clearSelectedIsletme();
          }
        }),
      );
    } catch (e) {
      debugPrint('>>> [_onMapCreated] tap interaction error: $e');
    }

    if (!kIsWeb) {
      try {
        final manager = await mapboxMap.annotations.createPointAnnotationManager();
        _pointAnnotationManager = manager;
        debugPrint('>>> [_onMapCreated] PointAnnotationManager created: $manager');

        try {
          await manager.setIconAllowOverlap(true);
          await manager.setIconIgnorePlacement(true);
        } catch (e) {
          debugPrint('>>> [_onMapCreated] overlap settings error: $e');
        }

        _annotationTapCancelable = manager.tapEvents(
          onTap: (PointAnnotation annotation) {
            final usta = _annotationIdToUsta[annotation.id];
            if (usta != null && mounted) {
              final notifier = ref.read(customerMapControllerProvider.notifier);
              _selectAndFocusUsta(usta, notifier);
              return;
            }

            final isletme = _annotationIdToIsletme[annotation.id];
            if (isletme != null && mounted) {
              final notifier = ref.read(customerMapControllerProvider.notifier);
              _selectAndFocusIsletme(isletme, notifier);
            }
          },
        );
      } catch (e, st) {
        debugPrint('>>> [_onMapCreated] CRITICAL annotation manager error: $e\n$st');
      }
    }

    final state = _latestMapState;
    if (mounted && state != null) {
      if (state.currentLat != _defaultKadikoyLat ||
          state.currentLng != _defaultKadikoyLng) {
        try {
          await mapboxMap.setCamera(
            CameraOptions(
              center: Point(
                coordinates: Position(state.currentLng, state.currentLat),
              ),
              zoom: _defaultZoom,
            ),
          );
        } catch (e) {
          debugPrint('>>> [_onMapCreated] setCamera error: $e');
        }
      }
      debugPrint('>>> [_onMapCreated] triggering initial _syncAnnotations');
      if (kIsWeb) {
        await _updateWebMarkerPositions(state);
      } else {
        await _syncAnnotations(state, force: true);
      }
    }
  }

  Future<void> _updateWebMarkerPositions([CustomerMapState? state]) async {
    if (!kIsWeb) return;
    final map = _mapboxMap;
    if (map == null || !mounted) return;

    if (_isUpdatingWebPositions) {
      _hasPendingWebUpdate = true;
      return;
    }
    _isUpdatingWebPositions = true;

    try {
      final s = state ?? _latestMapState;
      if (s == null) return;

      // 1. Müşteri konumu
      final custCoord = await map.pixelForCoordinate(
        Point(coordinates: Position(s.currentLng, s.currentLat)),
      );
      final customerPos = Offset(custCoord.x.toDouble(), custCoord.y.toDouble());

      // 2. Yakındaki Ustalar
      final Map<String, Offset> ustaPositions = {};
      if (s.selectedCategory != 'tedarikciler') {
        for (final usta in s.nearbyUstalar) {
          final coord = await map.pixelForCoordinate(
            Point(coordinates: Position(usta.longitude, usta.latitude)),
          );
          ustaPositions[usta.ustaId] = Offset(coord.x.toDouble(), coord.y.toDouble());
        }
      }

      // 3. Yakındaki İşletmeler / Tedarikçiler
      final Map<String, Offset> isletmePositions = {};
      for (final isletme in s.isletmeler) {
        final coord = await map.pixelForCoordinate(
          Point(coordinates: Position(isletme.longitude, isletme.latitude)),
        );
        isletmePositions[isletme.id] = Offset(coord.x.toDouble(), coord.y.toDouble());
      }

      if (mounted) {
        setState(() {
          _customerScreenPos = customerPos;
          _ustaScreenPos = ustaPositions;
          _isletmeScreenPos = isletmePositions;
        });
      }
    } catch (e) {
      debugPrint('>>> [_updateWebMarkerPositions] error: $e');
    } finally {
      _isUpdatingWebPositions = false;
      if (_hasPendingWebUpdate && mounted) {
        _hasPendingWebUpdate = false;
        _updateWebMarkerPositions();
      }
    }
  }

  String _buildSyncSignature(CustomerMapState mapState) {
    final ids = mapState.nearbyUstalar
        .map(
          (u) =>
              '${u.ustaId}:${u.latitude.toStringAsFixed(5)}:${u.longitude.toStringAsFixed(5)}:${u.formattedPrice}:${u.puan}',
        )
        .join(',');
    final isletmeIds = mapState.isletmeler
        .map(
          (i) =>
              '${i.id}:${i.latitude.toStringAsFixed(5)}:${i.longitude.toStringAsFixed(5)}:${i.isSponsored}',
        )
        .join(',');
    return '${mapState.currentLat}_${mapState.currentLng}_'
        '${mapState.selectedCategory}_'
        '${mapState.selectedUsta?.ustaId}_${mapState.selectedIsletme?.id}_'
        '$ids|$isletmeIds';
  }

  Future<void> _syncAnnotations(
    CustomerMapState mapState, {
    bool force = false,
  }) async {
    if (kIsWeb) {
      await _updateWebMarkerPositions(mapState);
      return;
    }
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
      debugPrint('>>> [_syncAnnotations] START signature: $signature, ustalar: ${mapState.nearbyUstalar.length}, isletmeler: ${mapState.isletmeler.length}');
      _lastSyncedSignature = signature;
      await manager.deleteAll();
      _annotationIdToUsta.clear();
      _annotationIdToIsletme.clear();

      // 1. Müşteri konum pini
      try {
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
        debugPrint('>>> [_syncAnnotations] customer pin created at ${mapState.currentLat}, ${mapState.currentLng}');
      } catch (e) {
        debugPrint('>>> [_syncAnnotations] customer pin error: $e');
      }

      // 2. Yakındaki ustaların standart yeşil rozet pinleri
      // (Eğer 'tedarikciler' filtresi seçili değilse)
      if (mapState.selectedCategory != 'tedarikciler') {
        debugPrint('>>> [_syncAnnotations] rendering ${mapState.nearbyUstalar.length} ustalar');
        for (final usta in mapState.nearbyUstalar) {
          try {
            final isSelected = mapState.selectedUsta?.ustaId == usta.ustaId;
            final cacheKey =
                'usta_${usta.ustaId}_${usta.formattedPrice}_${usta.puan}_$isSelected';
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
                iconSize: isSelected ? 1.12 : 1.00,
              ),
            );
            _annotationIdToUsta[annotation.id] = usta;
            debugPrint('>>> [_syncAnnotations] usta pin created for ${usta.fullName} at (${usta.latitude}, ${usta.longitude})');
          } catch (e) {
            debugPrint('>>> [_syncAnnotations] usta pin error for ${usta.fullName}: $e');
          }
        }
      }

      // 3. Yakındaki işletmeler / tedarikçilerin özel altın sarısı / turuncu rozet pinleri
      for (final isletme in mapState.isletmeler) {
        try {
          final isSelected = mapState.selectedIsletme?.id == isletme.id;
          final cacheKey =
              'isletme_${isletme.id}_${isletme.ad}_${isletme.isSponsored}_$isSelected';
          final bytes = _markerBytesCache[cacheKey] ??
              await _createIsletmeBadgeBytes(isletme: isletme, isSelected: isSelected);
          _markerBytesCache[cacheKey] = bytes;

          final annotation = await manager.create(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(isletme.longitude, isletme.latitude),
              ),
              image: bytes,
              iconAnchor: IconAnchor.BOTTOM,
              iconSize: isSelected ? 1.12 : 1.00,
            ),
          );
          _annotationIdToIsletme[annotation.id] = isletme;
          debugPrint('>>> [_syncAnnotations] isletme pin created for ${isletme.ad} at (${isletme.latitude}, ${isletme.longitude})');
        } catch (e) {
          debugPrint('>>> [_syncAnnotations] isletme pin error for ${isletme.ad}: $e');
        }
      }
    } catch (e, st) {
      debugPrint('>>> [_syncAnnotations] OUTER ERROR: $e\n$st');
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

  /// Usta Pin Rozeti - 3D Usta Harita Pini & Bilgi Rozeti
  Future<Uint8List> _createUstaBadgeBytes({
    required NearbyUstaModel usta,
    required bool isSelected,
  }) async {
    const double scale = 2.4;

    if (_ustaPinImage == null) {
      try {
        _ustaPinImage = await _loadUiImage(
          'assets/images/pin_usta.png',
          targetWidth: (48 * scale).toInt(),
        );
      } catch (e) {
        debugPrint('>>> [_createUstaBadgeBytes] lazy load pin error: $e');
      }
    }

    final Color bgColor = isSelected ? const Color(0xFF0F172A) : Colors.white;
    final Color textColor = isSelected ? Colors.white : const Color(0xFF0F172A);
    final Color borderColor = isSelected
        ? const Color(0xFFF97316)
        : const Color(0xFFCBD5E1);

    // Üst Satır: Usta Adı + ★ Puan
    final topTextPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
      text: TextSpan(
        children: [
          TextSpan(
            text: usta.shortDisplayName,
            style: TextStyle(
              fontSize: 12.0 * scale,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.2,
            ),
          ),
          TextSpan(
            text: ' ★ ${usta.puan.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 11.0 * scale,
              fontWeight: FontWeight.w800,
              color: isSelected ? const Color(0xFFFDE68A) : const Color(0xFFD97706),
            ),
          ),
        ],
      ),
    )..layout(maxWidth: 160 * scale);

    // Alt Satır: Fiyat ve Taban Bilgisi
    final priceLabel = '${usta.formattedPrice} Taban';
    final pricePainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
      text: TextSpan(
        text: priceLabel,
        style: TextStyle(
          fontSize: 9.5 * scale,
          fontWeight: FontWeight.w700,
          color: isSelected ? const Color(0xFFA7F3D0) : const Color(0xFF047857),
          letterSpacing: 0.1,
        ),
      ),
    )..layout(maxWidth: 160 * scale);

    final double maxTextWidth = math.max(topTextPainter.width, pricePainter.width);
    final double cardPaddingH = 12 * scale;
    final double cardPaddingV = 6 * scale;
    final double cardWidth = math.max(100 * scale, maxTextWidth + cardPaddingH * 2);
    final double cardHeight = topTextPainter.height + pricePainter.height + 4 * scale + cardPaddingV * 2;

    const double pointerHeight = 6 * scale;
    const double pinWidth = 48 * scale;
    const double pinHeight = 48 * scale;

    final double totalWidth = math.max(cardWidth, pinWidth) + 16 * scale;
    final double totalHeight = cardHeight + pointerHeight + pinHeight + 6 * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final double cardLeft = (totalWidth - cardWidth) / 2;
    const double cardTop = 3 * scale;

    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight),
      const Radius.circular(12 * scale),
    );

    // Drop shadow
    canvas.drawRRect(
      cardRect.shift(const Offset(0, 3 * scale)),
      Paint()
        ..color = isSelected
            ? const Color(0xFFF97316).withValues(alpha: 0.35)
            : Colors.black.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8 * scale),
    );

    // Card background
    canvas.drawRRect(cardRect, Paint()..color = bgColor);

    // Card border
    canvas.drawRRect(
      cardRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isSelected ? 2.2 : 1.2) * scale,
    );

    // Paint Texts
    final double textX = cardLeft + (cardWidth - topTextPainter.width) / 2;
    topTextPainter.paint(canvas, Offset(textX, cardTop + cardPaddingV));

    final double chipTop = cardTop + cardPaddingV + topTextPainter.height + 3 * scale;
    final double chipW = pricePainter.width + 8 * scale;
    final double chipH = pricePainter.height + 3 * scale;
    final double chipX = cardLeft + (cardWidth - chipW) / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(chipX, chipTop, chipW, chipH),
        const Radius.circular(4 * scale),
      ),
      Paint()..color = isSelected ? const Color(0xFF1E293B) : const Color(0xFFECFDF5),
    );

    pricePainter.paint(
      canvas,
      Offset(chipX + 4 * scale, chipTop + 1.5 * scale),
    );

    // Pointer
    final double pointerCenterX = totalWidth / 2;
    final double pointerTop = cardTop + cardHeight - 0.5 * scale;
    final trianglePath = Path()
      ..moveTo(pointerCenterX - 5 * scale, pointerTop)
      ..lineTo(pointerCenterX, pointerTop + pointerHeight)
      ..lineTo(pointerCenterX + 5 * scale, pointerTop)
      ..close();

    canvas.drawPath(trianglePath, Paint()..color = bgColor);
    canvas.drawPath(
      trianglePath,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isSelected ? 2.0 : 1.2) * scale,
    );

    // 3D Usta Harita Pini
    final double pinLeft = (totalWidth - pinWidth) / 2;
    final double pinTop = pointerTop + pointerHeight - 1 * scale;

    if (_ustaPinImage != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        _ustaPinImage!.width.toDouble(),
        _ustaPinImage!.height.toDouble(),
      );
      final dst = Rect.fromLTWH(pinLeft, pinTop, pinWidth, pinHeight);

      // Contact shadow
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(totalWidth / 2, pinTop + pinHeight - 1 * scale),
          width: pinWidth * 0.45,
          height: 5 * scale,
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3 * scale),
      );

      canvas.drawImageRect(_ustaPinImage!, src, dst, Paint()..filterQuality = FilterQuality.high);
    }

    final image = await recorder
        .endRecording()
        .toImage(totalWidth.toInt(), totalHeight.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// İşletme / Tedarikçi Pin Rozeti - 3D İşletme Harita Pini & Bilgi Rozeti
  Future<Uint8List> _createIsletmeBadgeBytes({
    required IsletmeModel isletme,
    required bool isSelected,
  }) async {
    const double scale = 2.4;
    final bool isSponsored = isletme.isSponsored;

    if (_isletmePinImage == null) {
      try {
        _isletmePinImage = await _loadUiImage(
          'assets/images/pin_isletme.png',
          targetWidth: (48 * scale).toInt(),
        );
      } catch (e) {
        debugPrint('>>> [_createIsletmeBadgeBytes] lazy load pin error: $e');
      }
    }

    final Color bgColor = isSelected ? const Color(0xFF0F172A) : Colors.white;
    final Color textColor = isSelected ? Colors.white : const Color(0xFF0F172A);
    final Color borderColor = isSelected
        ? const Color(0xFFF59E0B)
        : (isSponsored ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1));

    // Üst Satır: İşletme Adı + (Öne Çıkan)
    final topTextPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
      text: TextSpan(
        children: [
          TextSpan(
            text: isletme.ad,
            style: TextStyle(
              fontSize: 12.0 * scale,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.2,
            ),
          ),
          if (isSponsored)
            const TextSpan(
              text: ' ★',
              style: TextStyle(
                fontSize: 12.0 * scale,
                fontWeight: FontWeight.w900,
                color: Color(0xFFF59E0B),
              ),
            ),
        ],
      ),
    )..layout(maxWidth: 160 * scale);

    // Alt Satır: Kategori
    final subLabel = isSponsored
        ? 'Öne Çıkan Mağaza'
        : (isletme.kategori.isNotEmpty ? isletme.kategori : 'Tedarikçi');
    final subTextPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
      text: TextSpan(
        text: subLabel,
        style: TextStyle(
          fontSize: 9.5 * scale,
          fontWeight: FontWeight.w700,
          color: isSponsored
              ? const Color(0xFFD97706)
              : (isSelected ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          letterSpacing: 0.1,
        ),
      ),
    )..layout(maxWidth: 160 * scale);

    final double maxTextWidth = math.max(topTextPainter.width, subTextPainter.width);
    final double cardPaddingH = 12 * scale;
    final double cardPaddingV = 6 * scale;
    final double cardWidth = math.max(100 * scale, maxTextWidth + cardPaddingH * 2);
    final double cardHeight = topTextPainter.height + subTextPainter.height + 4 * scale + cardPaddingV * 2;

    const double pointerHeight = 6 * scale;
    const double pinWidth = 48 * scale;
    const double pinHeight = 48 * scale;

    final double totalWidth = math.max(cardWidth, pinWidth) + 16 * scale;
    final double totalHeight = cardHeight + pointerHeight + pinHeight + 6 * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final double cardLeft = (totalWidth - cardWidth) / 2;
    const double cardTop = 3 * scale;

    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight),
      const Radius.circular(12 * scale),
    );

    // Drop shadow
    canvas.drawRRect(
      cardRect.shift(const Offset(0, 3 * scale)),
      Paint()
        ..color = isSponsored
            ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
            : Colors.black.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8 * scale),
    );

    canvas.drawRRect(cardRect, Paint()..color = bgColor);

    canvas.drawRRect(
      cardRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isSelected ? 2.2 : (isSponsored ? 1.8 : 1.2)) * scale,
    );

    final double textX = cardLeft + (cardWidth - topTextPainter.width) / 2;
    topTextPainter.paint(canvas, Offset(textX, cardTop + cardPaddingV));

    final double subX = cardLeft + (cardWidth - subTextPainter.width) / 2;
    final double subY = cardTop + cardPaddingV + topTextPainter.height + 3 * scale;
    subTextPainter.paint(canvas, Offset(subX, subY));

    // Pointer
    final double pointerCenterX = totalWidth / 2;
    final double pointerTop = cardTop + cardHeight - 0.5 * scale;
    final trianglePath = Path()
      ..moveTo(pointerCenterX - 5 * scale, pointerTop)
      ..lineTo(pointerCenterX, pointerTop + pointerHeight)
      ..lineTo(pointerCenterX + 5 * scale, pointerTop)
      ..close();

    canvas.drawPath(trianglePath, Paint()..color = bgColor);
    canvas.drawPath(
      trianglePath,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isSelected ? 2.0 : 1.2) * scale,
    );

    // 3D İşletme Harita Pini
    final double pinLeft = (totalWidth - pinWidth) / 2;
    final double pinTop = pointerTop + pointerHeight - 1 * scale;

    if (_isletmePinImage != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        _isletmePinImage!.width.toDouble(),
        _isletmePinImage!.height.toDouble(),
      );
      final dst = Rect.fromLTWH(pinLeft, pinTop, pinWidth, pinHeight);

      // Contact shadow
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(totalWidth / 2, pinTop + pinHeight - 1 * scale),
          width: pinWidth * 0.45,
          height: 5 * scale,
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3 * scale),
      );

      canvas.drawImageRect(_isletmePinImage!, src, dst, Paint()..filterQuality = FilterQuality.high);
    }

    final image = await recorder
        .endRecording()
        .toImage(totalWidth.toInt(), totalHeight.toInt());
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

  void _selectAndFocusIsletme(
    IsletmeModel isletme,
    CustomerMapController mapNotifier,
  ) {
    mapNotifier.selectIsletme(isletme);
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(isletme.longitude, isletme.latitude - 0.0012),
        ),
        zoom: 15.0,
      ),
      MapAnimationOptions(duration: 600),
    );
    _showIsletmeDetailSheet(context, isletme);
  }

  Future<void> _makePhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Telefon arama hatası: $e');
    }
  }

  Future<void> _openDirections(double lat, double lng, String label) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Yol tarifi açma hatası: $e');
    }
  }

  void _showIsletmeDetailSheet(BuildContext context, IsletmeModel isletme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isSponsored = isletme.isSponsored;
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: SafeArea(
            top: false,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSponsored
                              ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                              : [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isSponsored
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        isSponsored ? Icons.verified_rounded : Icons.storefront_rounded,
                        color: isSponsored ? Colors.white : const Color(0xFFD97706),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isletme.ad,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (isSponsored) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFF59E0B),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        size: 13,
                                        color: Color(0xFFD97706),
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'SPONSORLU',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF92400E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                isletme.kategori,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                              if (isletme.formattedDistance.isNotEmpty) ...[
                                const Text(
                                  ' • ',
                                  style: TextStyle(color: Color(0xFF94A3B8)),
                                ),
                                const Icon(
                                  Icons.near_me_rounded,
                                  size: 13,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isletme.formattedDistance,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),
                // Adres Bilgisi
                if (isletme.adres.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isletme.adres,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF334155),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                // Telefon Bilgisi
                if (isletme.telefon.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 19,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isletme.telefon,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                // Aksiyon Butonları (Telefonla Ara + Yol Tarifi Al)
                Row(
                  children: [
                    if (isletme.telefon.isNotEmpty)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _makePhoneCall(isletme.telefon),
                          icon: const Icon(Icons.phone_rounded, size: 18),
                          label: const Text('Telefonla Ara'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    if (isletme.telefon.isNotEmpty) const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openDirections(
                          isletme.latitude,
                          isletme.longitude,
                          isletme.ad,
                        ),
                        icon: const Icon(Icons.directions_rounded, size: 18),
                        label: const Text('Yol Tarifi Al'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
                    const SizedBox(height: 4),
                    const Text(
                      'Haritadaki ustalar ve hizmet noktaları bu konuma göre anlık yenilenir.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),

                    // 1. Canlı Gerçek GPS Konumu Butonu
                    InkWell(
                      onTap: () => Navigator.of(ctx).pop('__USE_GPS__'),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFDBA74)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.my_location_rounded, color: AppTheme.customerPrimary, size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mevcut Canlı Konumumu Kullan (GPS)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: Color(0xFF9A3412),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Uydudan anlık %100 kesin konumunuzu tespit eder',
                                    style: TextStyle(fontSize: 11, color: Color(0xFFC2410C)),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.customerPrimary),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'veya adres arayın',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 14),

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
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.customerPrimary),
                        hintText: 'İlçe, Şehir veya Mahalle yazın...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    if (liveSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
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
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.of(ctx).pop(textController.text.trim()),
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

    if (moved && mounted) {
      final updatedState = ref.read(customerMapControllerProvider);
      final point = Point(
        coordinates: Position(updatedState.currentLng, updatedState.currentLat),
      );
      await _mapboxMap?.setCamera(
        CameraOptions(
          center: point,
          zoom: _defaultZoom,
        ),
      );
      await _mapboxMap?.flyTo(
        CameraOptions(
          center: point,
          zoom: _defaultZoom,
        ),
        MapAnimationOptions(duration: 500),
      );
    }
  }

  void _showNotificationsSheet() {
    NotificationSheet.show(context);
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
        final point = Point(
          coordinates: Position(next.currentLng, next.currentLat),
        );
        _mapboxMap?.setCamera(
          CameraOptions(
            center: point,
            zoom: _defaultZoom,
          ),
        );
        _mapboxMap?.flyTo(
          CameraOptions(
            center: point,
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
              onCameraChangeListener: (_) {
                if (kIsWeb) {
                  _updateWebMarkerPositions();
                }
              },
              onMapIdleListener: (_) {
                if (kIsWeb) {
                  _updateWebMarkerPositions();
                }
              },
            ),
          ),

          // 1.1 WEB HARİTA ROZET PİNLERİ (Web ortamında Mapbox PointAnnotation kısıtlamasını çözen etkileşimli katman)
          if (kIsWeb) ...[
            // Müşteri Konumu (Mavi Radarlı Nokta)
            if (_customerScreenPos != null)
              Positioned(
                left: _customerScreenPos!.dx - 22,
                top: _customerScreenPos!.dy - 22,
                child: CustomerLocationMarker(
                  onTap: () => _animateToCustomerLocation(mapState, mapNotifier),
                ),
              ),

            // Yakındaki İşletmeler / Tedarikçiler (Altın/Amber Rozetler)
            if (_isletmeScreenPos.isNotEmpty)
              ...mapState.isletmeler.map((isletme) {
                final pos = _isletmeScreenPos[isletme.id];
                if (pos == null) return const SizedBox.shrink();
                final isSelected = mapState.selectedIsletme?.id == isletme.id;
                return Positioned(
                  left: pos.dx,
                  top: pos.dy,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -1.0),
                    child: CustomIsletmeMarker(
                      isletme: isletme,
                      isSelected: isSelected,
                      onTap: () => _selectAndFocusIsletme(isletme, mapNotifier),
                    ),
                  ),
                );
              }),

            // Yakındaki Ustalar (Zümrüt Yeşili Fiyatlı Usta Rozetleri)
            if (mapState.selectedCategory != 'tedarikciler' && _ustaScreenPos.isNotEmpty)
              ...mapState.nearbyUstalar.map((usta) {
                final pos = _ustaScreenPos[usta.ustaId];
                if (pos == null) return const SizedBox.shrink();
                final isSelected = mapState.selectedUsta?.ustaId == usta.ustaId;
                return Positioned(
                  left: pos.dx,
                  top: pos.dy,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -1.0),
                    child: CustomMarker(
                      usta: usta,
                      isSelected: isSelected,
                      onTap: () => _selectAndFocusUsta(usta, mapNotifier),
                    ),
                  ),
                );
              }),
          ],

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
                onListingsTap: () => context.go('/customer/home'),
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
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Sol: İlan Listesi & Usta Paneli Hızlı Dönüş Butonları
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (ref.watch(authStateProvider).role == UserRole.usta) ...[
                            InkWell(
                              onTap: () => context.go('/usta/orders'),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.ustaPrimary,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.dashboard_rounded, size: 18, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text(
                                      'Usta Paneli',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          InkWell(
                            onTap: () => context.go('/customer/home'),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.grid_view_rounded, size: 18, color: AppTheme.customerPrimary),
                                  SizedBox(width: 6),
                                  Text(
                                    'İlan Listesi',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.customerTextDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Sağ: Harita Kontrolleri
                      Column(
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
