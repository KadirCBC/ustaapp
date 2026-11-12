import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final token = 'pk.eyJ1IjoiYnlncmFmMDEiLCJhIjoiY213Y2o2dnpmMDM3OTJ5c2M4cjV3NThsZyJ9.3asuElOYlUMITRxJLGh2Hw';
  final url = 'https://api.mapbox.com/directions/v5/mapbox/driving/29.0270,40.9905;29.0325,40.9980?geometries=geojson&overview=full&steps=true&language=tr&access_token=$token';
  
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(url));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final routes = json['routes'] as List<dynamic>?;
    if (routes != null && routes.isNotEmpty) {
      final route = routes.first as Map<String, dynamic>;
      final legs = route['legs'] as List<dynamic>;
      final steps = legs.first['steps'] as List<dynamic>;
      print('FOUND ${steps.length} TURNING STEPS:');
      for (var s in steps) {
        final m = s['maneuver'] as Map<String, dynamic>;
        print('- ${m['instruction']} (${(s['distance'] as num).round()}m)');
      }
    }
  } catch (e) {
    print('ERROR: $e');
  } finally {
    client.close();
  }
}
