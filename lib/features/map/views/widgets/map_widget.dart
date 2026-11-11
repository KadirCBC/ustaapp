import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

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

/// Usta ve müşteri konumları arasındaki rota çizgisini ve noktalarını Mapbox ile gösteren widget.
class UstaRouteMapWidget extends StatefulWidget {
  final double ustaLat;
  final double ustaLng;
  final double customerLat;
  final double customerLng;
  final Color routeColor;
  final Color ustaMarkerColor;
  final Color customerMarkerColor;
  final double zoom;

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
  });

  @override
  State<UstaRouteMapWidget> createState() => _UstaRouteMapWidgetState();
}

class _UstaRouteMapWidgetState extends State<UstaRouteMapWidget> {
  mapbox.PolylineAnnotationManager? _polylineManager;
  mapbox.CircleAnnotationManager? _circleManager;

  Future<void> _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    _polylineManager =
        await mapboxMap.annotations.createPolylineAnnotationManager();
    _circleManager =
        await mapboxMap.annotations.createCircleAnnotationManager();
    await _syncRouteAnnotations();
  }

  @override
  void didUpdateWidget(covariant UstaRouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ustaLat != widget.ustaLat ||
        oldWidget.ustaLng != widget.ustaLng ||
        oldWidget.customerLat != widget.customerLat ||
        oldWidget.customerLng != widget.customerLng) {
      _syncRouteAnnotations();
    }
  }

  Future<void> _syncRouteAnnotations() async {
    final polylineManager = _polylineManager;
    final circleManager = _circleManager;
    if (polylineManager == null || circleManager == null) return;

    await polylineManager.deleteAll();
    await polylineManager.create(
      mapbox.PolylineAnnotationOptions(
        geometry: mapbox.LineString(
          coordinates: [
            mapbox.Position(widget.ustaLng, widget.ustaLat),
            mapbox.Position(widget.customerLng, widget.customerLat),
          ],
        ),
        lineColor: widget.routeColor.toARGB32(),
        lineWidth: 5.0,
        lineJoin: mapbox.LineJoin.ROUND,
      ),
    );

    await circleManager.deleteAll();
    await circleManager.createMulti([
      mapbox.CircleAnnotationOptions(
        geometry: mapbox.Point(
          coordinates: mapbox.Position(widget.customerLng, widget.customerLat),
        ),
        circleRadius: 10.0,
        circleColor: widget.customerMarkerColor.toARGB32(),
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 3.0,
      ),
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
