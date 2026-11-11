import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';
import 'package:ustaapp/features/map/views/widgets/custom_marker.dart';

/// Minimalist CartoDB Positron açık temalı harita katmanı + müşteri & usta pinleri
class MapWidget extends StatelessWidget {
  final MapController mapController;
  final LatLng customerLatLng;
  final List<NearbyUstaModel> ustalar;
  final NearbyUstaModel? selectedUsta;
  final ValueChanged<NearbyUstaModel> onUstaTap;
  final VoidCallback onMapBackgroundTap;

  const MapWidget({
    super.key,
    required this.mapController,
    required this.customerLatLng,
    required this.ustalar,
    required this.selectedUsta,
    required this.onUstaTap,
    required this.onMapBackgroundTap,
  });

  // Minimalist CartoDB Positron light theme (yolları ve pinleri öne çıkaran sade görünüm)
  static const String _cartoPositronLightUrl =
      'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: customerLatLng,
        initialZoom: 14.2,
        minZoom: 6.0,
        maxZoom: 18.0,
        onTap: (_, __) => onMapBackgroundTap(),
      ),
      children: [
        TileLayer(
          urlTemplate: _cartoPositronLightUrl,
          userAgentPackageName: 'com.ustamburada.app',
        ),
        MarkerLayer(
          markers: [
            // A. Müşteri Konum Pin'i
            Marker(
              point: customerLatLng,
              width: 48,
              height: 48,
              child: const CustomerLocationMarker(),
            ),

            // B. Yakındaki Online Ustalar (Seçili olan üstte render edilir)
            ..._orderedMarkers(),
          ],
        ),
      ],
    );
  }

  List<Marker> _orderedMarkers() {
    final sorted = [...ustalar];
    if (selectedUsta != null) {
      sorted.sort((a, b) {
        if (a.ustaId == selectedUsta!.ustaId) return 1;
        if (b.ustaId == selectedUsta!.ustaId) return -1;
        return 0;
      });
    }

    return sorted.map((usta) {
      final isSelected = selectedUsta?.ustaId == usta.ustaId;
      return Marker(
        point: LatLng(usta.latitude, usta.longitude),
        width: 158,
        height: 70,
        alignment: Alignment.topCenter,
        child: CustomMarker(
          usta: usta,
          isSelected: isSelected,
          onTap: () => onUstaTap(usta),
        ),
      );
    }).toList();
  }
}
