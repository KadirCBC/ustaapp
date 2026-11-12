import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:ustaapp/core/services/route_service.dart';

/// Resmi mapbox_maps_flutter tabanlı yeniden kullanılabilir harita kapsayıcısı.
class UstaMapWidget extends StatelessWidget {
  final double centerLat;
  final double centerLng;
  final double zoom;
  final String styleUri;
  final mapbox.MapCreatedCallback? onMapCreated;

  const UstaMapWidget({
    super.key,
    required this.centerLat,
    required this.centerLng,
    this.zoom = 13.5,
    this.styleUri = mapbox.MapboxStyles.LIGHT,
    this.onMapCreated,
  });

  @override
  Widget build(BuildContext context) {
    return mapbox.MapWidget(
      styleUri: styleUri,
      viewport: mapbox.CameraViewportState(
        center: mapbox.Point(
          coordinates: mapbox.Position(centerLng, centerLat),
        ),
        zoom: zoom,
      ),
      onMapCreated: onMapCreated,
    );
  }
}

/// Usta ve müşteri konumları arasındaki %100 gerçek sürüş rotasını (caddeleri ve sokakları takip eden)
/// ve varış noktalarını Mapbox ile gösteren canlı navigasyon widget'ı.
class UstaRouteMapWidget extends StatefulWidget {
  final double ustaLat;
  final double ustaLng;
  final double customerLat;
  final double customerLng;
  final Color routeColor;
  final Color ustaMarkerColor;
  final Color customerMarkerColor;
  final double zoom;
  final ValueChanged<RouteResult>? onRouteCalculated;

  const UstaRouteMapWidget({
    super.key,
    required this.ustaLat,
    required this.ustaLng,
    required this.customerLat,
    required this.customerLng,
    required this.routeColor,
    required this.ustaMarkerColor,
    required this.customerMarkerColor,
    this.zoom = 14.0,
    this.onRouteCalculated,
  });

  @override
  State<UstaRouteMapWidget> createState() => _UstaRouteMapWidgetState();
}

class _UstaRouteMapWidgetState extends State<UstaRouteMapWidget> {
  mapbox.MapboxMap? _mapboxMap;
  mapbox.PolylineAnnotationManager? _polylineManager;
  mapbox.CircleAnnotationManager? _circleManager;
  bool _isRouteFetching = false;

  Future<void> _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _polylineManager =
        await mapboxMap.annotations.createPolylineAnnotationManager();
    _circleManager =
        await mapboxMap.annotations.createCircleAnnotationManager();
    await _syncRealDrivingRoute();
  }

  @override
  void didUpdateWidget(covariant UstaRouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ustaLat != widget.ustaLat ||
        oldWidget.ustaLng != widget.ustaLng ||
        oldWidget.customerLat != widget.customerLat ||
        oldWidget.customerLng != widget.customerLng) {
      _syncRealDrivingRoute();
    }
  }

  /// Mapbox Directions API üzerinden gerçek sürüş rotasını çeker ve haritaya giydirir.
  Future<void> _syncRealDrivingRoute() async {
    final polylineManager = _polylineManager;
    final circleManager = _circleManager;
    if (polylineManager == null || circleManager == null || _isRouteFetching) return;

    _isRouteFetching = true;

    try {
      final route = await RouteService.fetchDrivingRoute(
        startLat: widget.ustaLat,
        startLng: widget.ustaLng,
        endLat: widget.customerLat,
        endLng: widget.customerLng,
      );

      if (!mounted) return;

      // Çizgileri temizle ve gerçek sokak rotasını çiz
      await polylineManager.deleteAll();

      // 1. Alt gölge/kontur çizgisi (daha net ve profesyonel navigasyon görünümü)
      await polylineManager.create(
        mapbox.PolylineAnnotationOptions(
          geometry: mapbox.LineString(coordinates: route.coordinates),
          lineColor: const Color(0xFF0F172A).toARGB32(),
          lineWidth: 8.5,
          lineJoin: mapbox.LineJoin.ROUND,
        ),
      );

      // 2. Ana rota çizgisi (canlı renk)
      await polylineManager.create(
        mapbox.PolylineAnnotationOptions(
          geometry: mapbox.LineString(coordinates: route.coordinates),
          lineColor: widget.routeColor.toARGB32(),
          lineWidth: 5.5,
          lineJoin: mapbox.LineJoin.ROUND,
        ),
      );

      // 3. Usta ve Müşteri pinleri
      await circleManager.deleteAll();
      await circleManager.createMulti([
        // Müşteri hedef pini (dış beyaz çeperli kırmızı nokta)
        mapbox.CircleAnnotationOptions(
          geometry: mapbox.Point(
            coordinates: mapbox.Position(widget.customerLng, widget.customerLat),
          ),
          circleRadius: 11.0,
          circleColor: widget.customerMarkerColor.toARGB32(),
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 3.5,
        ),
        // Usta başlangıç pini (turuncu/mavi usta noktası)
        mapbox.CircleAnnotationOptions(
          geometry: mapbox.Point(
            coordinates: mapbox.Position(widget.ustaLng, widget.ustaLat),
          ),
          circleRadius: 10.0,
          circleColor: widget.ustaMarkerColor.toARGB32(),
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 3.0,
        ),
      ]);

      // Rota sonucunu üst bileşene bildir
      if (widget.onRouteCalculated != null) {
        widget.onRouteCalculated!(route);
      }
    } catch (e) {
      debugPrint('Rota çizim hatası: $e');
    } finally {
      _isRouteFetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return UstaMapWidget(
      centerLat: (widget.ustaLat + widget.customerLat) / 2,
      centerLng: (widget.ustaLng + widget.customerLng) / 2,
      zoom: widget.zoom,
      onMapCreated: _onMapCreated,
    );
  }
}
