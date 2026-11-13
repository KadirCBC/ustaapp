import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:url_launcher/url_launcher.dart';
import 'package:ustaapp/core/constants/app_constants.dart';

/// Adım adım sürüş yönlendirme manevrası (Turn-by-turn step)
class RouteStep {
  final String instruction;
  final double distanceMeters;
  final String? modifier;
  final String? type;

  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    this.modifier,
    this.type,
  });

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.toStringAsFixed(0)} m';
  }

  IconData get icon {
    final mod = modifier?.toLowerCase() ?? '';
    final t = type?.toLowerCase() ?? '';
    if (t == 'arrive') return Icons.flag_rounded;
    if (mod.contains('right')) return Icons.turn_right_rounded;
    if (mod.contains('left')) return Icons.turn_left_rounded;
    if (mod.contains('straight')) return Icons.straight_rounded;
    if (mod.contains('uturn') || mod.contains('u-turn')) return Icons.u_turn_left_rounded;
    return Icons.navigation_rounded;
  }
}

class RouteResult {
  final List<mapbox.Position> coordinates;
  final double distanceMeters;
  final double durationMinutes;
  final List<RouteStep> steps;
  final bool isRealRoute;

  const RouteResult({
    required this.coordinates,
    required this.distanceMeters,
    required this.durationMinutes,
    this.steps = const [],
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

  /// İki nokta arasında Mapbox Directions üzerinden adım adım Türkçe sürüş manevralarını ve rotayı çeker.
  static Future<RouteResult> fetchDrivingRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    // 1. Mapbox Directions API (steps=true & language=tr)
    try {
      final token = AppConstants.mapboxAccessToken;
      final uri = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '$startLng,$startLat;$endLng,$endLat'
        '?geometries=geojson&overview=full&steps=true&language=tr&access_token=$token',
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

          final legs = primaryRoute['legs'] as List<dynamic>?;
          final rawSteps = legs?.isNotEmpty == true
              ? (legs!.first['steps'] as List<dynamic>?)
              : null;

          final List<RouteStep> parsedSteps = [];
          if (rawSteps != null) {
            for (final s in rawSteps) {
              final stepMap = s as Map<String, dynamic>;
              final maneuver = stepMap['maneuver'] as Map<String, dynamic>? ?? {};
              final instruction = maneuver['instruction'] as String? ?? '';
              final stepDist = (stepMap['distance'] as num?)?.toDouble() ?? 0.0;
              final modifier = maneuver['modifier'] as String?;
              final type = maneuver['type'] as String?;

              if (instruction.isNotEmpty) {
                parsedSteps.add(RouteStep(
                  instruction: instruction,
                  distanceMeters: stepDist,
                  modifier: modifier,
                  type: type,
                ));
              }
            }
          }

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
              steps: parsedSteps,
              isRealRoute: true,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Mapbox Directions hatası: $e, OSRM deneniyor...');
    }

    // 2. OSRM Fallback (steps=true)
    try {
      final osrmUri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '$startLng,$startLat;$endLng,$endLat'
        '?overview=full&geometries=geojson&steps=true',
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
              steps: const [],
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
      steps: const [],
      isRealRoute: false,
    );
  }

  /// Telefonun harici navigasyon uygulamasını (Google Maps / Yandex / Apple Maps) açar
  static Future<bool> openExternalNavigation({
    required double lat,
    required double lng,
  }) async {
    final googleMapsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    try {
      if (await canLaunchUrl(googleMapsUri)) {
        return await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Harici navigasyon başlatma hatası: $e');
    }
    return false;
  }
}
