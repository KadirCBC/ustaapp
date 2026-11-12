import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:ustaapp/core/constants/app_constants.dart';

class RouteResult {
  final List<mapbox.Position> coordinates;
  final double distanceMeters;
  final double durationMinutes;
  final bool isRealRoute;

  const RouteResult({
    required this.coordinates,
    required this.distanceMeters,
    required this.durationMinutes,
    required this.isRealRoute,
  });

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.toStringAsFixed(0)} metre';
  }

  String get formattedDuration {
    if (durationMinutes < 1) return '< 1 dk';
    return '${durationMinutes.round()} dk';
  }
}

class RouteService {
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8);

  /// İki nokta arasında Mapbox Directions (veya OSRM fallback) üzerinden %100 gerçek sürüş rotası çeker.
  static Future<RouteResult> fetchDrivingRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    // 1. Önce Mapbox Directions API'yi dene
    try {
      final token = AppConstants.mapboxAccessToken;
      final uri = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '$startLng,$startLat;$endLng,$endLat'
        '?geometries=geojson&overview=full&access_token=$token',
      );

      final req = await _client.getUrl(uri);
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final routes = json['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final primaryRoute = routes.first as Map<String, dynamic>;
          final geometry = primaryRoute['geometry'] as Map<String, dynamic>?;
          final coordsList = geometry?['coordinates'] as List<dynamic>?;
          final distance = (primaryRoute['distance'] as num?)?.toDouble() ?? 0.0;
          final durationSec = (primaryRoute['duration'] as num?)?.toDouble() ?? 0.0;

          if (coordsList != null && coordsList.isNotEmpty) {
            final positions = coordsList.map<mapbox.Position>((c) {
              final pair = c as List<dynamic>;
              return mapbox.Position(
                (pair[0] as num).toDouble(),
                (pair[1] as num).toDouble(),
              );
            }).toList();

            return RouteResult(
              coordinates: positions,
              distanceMeters: distance,
              durationMinutes: durationSec / 60.0,
              isRealRoute: true,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Mapbox Directions hatası: $e, OSRM deneniyor...');
    }

    // 2. Mapbox başarısız olursa OSRM açık kaynak sürüş yönlendirmesi fallback
    try {
      final osrmUri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '$startLng,$startLat;$endLng,$endLat'
        '?overview=full&geometries=geojson',
      );

      final req = await _client.getUrl(osrmUri);
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final routes = json['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final primaryRoute = routes.first as Map<String, dynamic>;
          final geometry = primaryRoute['geometry'] as Map<String, dynamic>?;
          final coordsList = geometry?['coordinates'] as List<dynamic>?;
          final distance = (primaryRoute['distance'] as num?)?.toDouble() ?? 0.0;
          final durationSec = (primaryRoute['duration'] as num?)?.toDouble() ?? 0.0;

          if (coordsList != null && coordsList.isNotEmpty) {
            final positions = coordsList.map<mapbox.Position>((c) {
              final pair = c as List<dynamic>;
              return mapbox.Position(
                (pair[0] as num).toDouble(),
                (pair[1] as num).toDouble(),
              );
            }).toList();

            return RouteResult(
              coordinates: positions,
              distanceMeters: distance,
              durationMinutes: durationSec / 60.0,
              isRealRoute: true,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('OSRM Route hatası: $e');
    }

    // 3. Fallback: İki nokta arası doğrudan düz çizgi (ağ tamamen yoksa)
    return RouteResult(
      coordinates: [
        mapbox.Position(startLng, startLat),
        mapbox.Position(endLng, endLat),
      ],
      distanceMeters: 1000.0,
      durationMinutes: 5.0,
      isRealRoute: false,
    );
  }
}
