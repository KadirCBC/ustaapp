import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/map/controllers/map_controller.dart';
import 'package:ustaapp/features/map/models/isletme_model.dart';
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
  final Map<String, IsletmeModel> _annotationIdToIsletme = {};
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

    // Arka plan haritaya dokunulduğunda seçili usta veya dükkanı temizle
    mapboxMap.addInteraction(
      TapInteraction.onMap((_) {
        if (mounted) {
          final notifier = ref.read(customerMapControllerProvider.notifier);
          notifier.clearSelectedUsta();
          notifier.clearSelectedIsletme();
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
          return;
        }

        final isletme = _annotationIdToIsletme[annotation.id];
        if (isletme != null && mounted) {
          final notifier = ref.read(customerMapControllerProvider.notifier);
          _selectAndFocusIsletme(isletme, notifier);
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
      _annotationIdToIsletme.clear();

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

      // 2. Yakındaki ustaların standart yeşil rozet pinleri
      // (Eğer 'tedarikciler' filtresi seçili değilse)
      if (mapState.selectedCategory != 'tedarikciler') {
        for (final usta in mapState.nearbyUstalar) {
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
              iconSize: isSelected ? 1.15 : 1.00,
              symbolSortKey: isSelected ? 10.0 : 5.0,
            ),
          );
          _annotationIdToUsta[annotation.id] = usta;
        }
      }

      // 3. Yakındaki işletmeler / tedarikçilerin özel altın sarısı / turuncu rozet pinleri
      final isletmePayloads = await Future.wait(
        mapState.isletmeler.map((isletme) async {
          final isSelected = mapState.selectedIsletme?.id == isletme.id;
          final cacheKey =
              'isletme_${isletme.id}_${isletme.ad}_${isletme.isSponsored}_$isSelected';
          final bytes = _markerBytesCache[cacheKey] ??
              await _createIsletmeBadgeBytes(isletme: isletme, isSelected: isSelected);
          _markerBytesCache[cacheKey] = bytes;
          return (isletme: isletme, bytes: bytes, isSelected: isSelected);
        }),
      );

      for (final item in isletmePayloads) {
        final annotation = await manager.create(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(item.isletme.longitude, item.isletme.latitude),
            ),
            image: item.bytes,
            iconAnchor: IconAnchor.BOTTOM,
            iconSize: item.isSelected ? 1.12 : 1.00,
            symbolSortKey: item.isletme.isSponsored ? 12.0 : 6.0,
          ),
        );
        _annotationIdToIsletme[annotation.id] = item.isletme;
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

  /// Usta Pin Rozeti - Standart Yeşil Rozet Pin (★ 4.9 Ahmet Y. + 920 ₺ yeşil hap + alt üçgen ok)
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

    const Color greenPrimary = Color(0xFF059669);
    final Color bgColor = isSelected ? greenPrimary : Colors.white;
    final Color textColor = isSelected ? Colors.white : const Color(0xFF0F172A);
    final Color pillBgColor = isSelected ? Colors.white : const Color(0xFF064E3B);
    final Color pillTextColor = isSelected ? greenPrimary : Colors.white;
    final Color borderColor = isSelected ? const Color(0xFF34D399) : const Color(0xFF10B981);

    final badgeRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(8, 4, width - 16, badgeHeight),
      const Radius.circular(18 * scale),
    );

    canvas.drawRRect(
      badgeRect.shift(const Offset(0, 6)),
      Paint()
        ..color = isSelected
            ? greenPrimary.withValues(alpha: 0.38)
            : const Color(0xFF10B981).withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawRRect(badgeRect, Paint()..color = bgColor);
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isSelected ? 2.4 : 1.6) * scale,
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

    canvas.drawPath(trianglePath, Paint()..color = bgColor);
    canvas.drawPath(
      trianglePath,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * scale,
    );

    final image = await recorder
        .endRecording()
        .toImage(width.toInt(), totalHeight.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// İşletme / Tedarikçi Pin Rozeti - Profesyonel Modern Mağaza Tasarımı
  /// (Sol amblemde vektörel mağaza simgesi, sağda yüksek kontrastlı dükkan adı & kategori rozeti)
  Future<Uint8List> _createIsletmeBadgeBytes({
    required IsletmeModel isletme,
    required bool isSelected,
  }) async {
    const double scale = 2.6;
    final bool isSponsored = isletme.isSponsored;

    // Renk paleti - Modern Kurumsal Tasarım
    final Color amberPrimary = isSponsored ? const Color(0xFFD97706) : const Color(0xFFF59E0B);
    final Color amberGradientDark = isSponsored ? const Color(0xFFB45309) : const Color(0xFFD97706);
    final Color bgColor = isSelected ? const Color(0xFF0F172A) : Colors.white;
    final Color textColor = isSelected ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isSelected ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color borderColor = isSelected
        ? const Color(0xFFF59E0B)
        : (isSponsored ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0));

    // Dükkan Adı Metin Ölçümü (Dinamik ve profesyonel genişlik)
    final namePainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
      text: TextSpan(
        text: isletme.ad,
        style: TextStyle(
          fontSize: 12.5 * scale,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: -0.2,
        ),
      ),
    )..layout(maxWidth: 165 * scale);

    // Alt Rozet / Kategori Metin Ölçümü
    final String subLabel = isSponsored
        ? 'ÖNE ÇIKAN DÜKKAN'
        : (isletme.kategori.isNotEmpty ? isletme.kategori : 'Tedarikçi / Mağaza');
    final subPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
      text: TextSpan(
        text: subLabel,
        style: TextStyle(
          fontSize: 9.5 * scale,
          fontWeight: FontWeight.w700,
          color: isSelected
              ? const Color(0xFFFDE68A)
              : (isSponsored ? const Color(0xFFB45309) : subTextColor),
          letterSpacing: 0.1,
        ),
      ),
    )..layout(maxWidth: 165 * scale);

    // Dinamik Genişlik: Sol amblem (42) + en geniş metin + sağ dolgu (18)
    final double maxTextWidth = math.max(namePainter.width, subPainter.width);
    final double width = math.max(148 * scale, maxTextWidth + 60 * scale);
    const double badgeHeight = 48 * scale;
    const double pointerHeight = 8 * scale;
    const double totalHeight = badgeHeight + pointerHeight + 10 * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Kart RRect
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(8 * scale, 4 * scale, width - 16 * scale, badgeHeight),
      const Radius.circular(14 * scale),
    );

    // Yumuşak Profesyonel Drop Shadow
    if (isSponsored) {
      canvas.drawRRect(
        badgeRect.shift(const Offset(0, 4 * scale)),
        Paint()
          ..color = const Color(0xFFF59E0B).withValues(alpha: 0.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12 * scale),
      );
    } else {
      canvas.drawRRect(
        badgeRect.shift(const Offset(0, 3 * scale)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8 * scale),
      );
    }

    // Gövde Arka Planı
    canvas.drawRRect(badgeRect, Paint()..color = bgColor);

    // İnce / Şık Kenarlık
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isSelected ? 2.4 : (isSponsored ? 2.0 : 1.2)) * scale,
    );

    // SOL AMBLEM: Gradyanlı Turuncu / Altın Daire + Vektörel Mağaza Simgesi
    const double emblemRadius = 16 * scale;
    final Offset emblemCenter = Offset(8 * scale + 18 * scale, 4 * scale + badgeHeight / 2);

    final emblemGradient = ui.Gradient.linear(
      Offset(emblemCenter.dx - emblemRadius, emblemCenter.dy - emblemRadius),
      Offset(emblemCenter.dx + emblemRadius, emblemCenter.dy + emblemRadius),
      [amberPrimary, amberGradientDark],
    );

    canvas.drawCircle(
      emblemCenter,
      emblemRadius,
      Paint()..shader = emblemGradient,
    );

    // Mağaza Vektör Simgesi (Material Icons: storefront_rounded veya stars_rounded)
    final iconPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(
          isSponsored ? Icons.stars_rounded.codePoint : Icons.storefront_rounded.codePoint,
        ),
        style: TextStyle(
          fontSize: 18 * scale,
          fontFamily: Icons.storefront_rounded.fontFamily,
          package: Icons.storefront_rounded.fontPackage,
          color: Colors.white,
        ),
      ),
    )..layout();

    iconPainter.paint(
      canvas,
      Offset(
        emblemCenter.dx - iconPainter.width / 2,
        emblemCenter.dy - iconPainter.height / 2,
      ),
    );

    // SAĞ İÇERİK: Dükkan Adı (Üst) ve Kategori / Sponsor Rozeti (Alt)
    final double textLeft = 8 * scale + 38 * scale;
    namePainter.paint(canvas, Offset(textLeft, 4 * scale + 9 * scale));

    if (isSponsored) {
      // Sponsorlu Dükkan için Altın Rozet Çipi
      final double chipW = subPainter.width + 10 * scale;
      final double chipH = subPainter.height + 4 * scale;
      final double chipTop = 4 * scale + 27 * scale;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(textLeft, chipTop, chipW, chipH),
          const Radius.circular(5 * scale),
        ),
        Paint()..color = isSelected ? const Color(0xFF334155) : const Color(0xFFFEF3C7),
      );

      subPainter.paint(
        canvas,
        Offset(textLeft + 5 * scale, chipTop + 2 * scale),
      );
    } else {
      // Normal Kategori / Dükkan Alt Başlığı
      subPainter.paint(canvas, Offset(textLeft, 4 * scale + 28 * scale));
    }

    // ALT ÜÇGEN OK (Mükemmel sivri uç ile haritadaki konuma işaret eder)
    final double pointerCenterX = width / 2;
    final double pointerTop = 4 * scale + badgeHeight - 1 * scale;
    final trianglePath = Path()
      ..moveTo(pointerCenterX - 6 * scale, pointerTop)
      ..lineTo(pointerCenterX, pointerTop + pointerHeight)
      ..lineTo(pointerCenterX + 6 * scale, pointerTop)
      ..close();

    canvas.drawPath(trianglePath, Paint()..color = bgColor);
    canvas.drawPath(
      trianglePath,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (isSelected ? 2.2 : (isSponsored ? 1.8 : 1.2)) * scale,
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
