import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String? _getEnv(String key) {
    try {
      if (dotenv.isInitialized) {
        return dotenv.env[key];
      }
    } catch (_) {}
    return null;
  }

  static String get supabaseUrl {
    return _getEnv('SUPABASE_URL') ?? 
           const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  }

  static String get supabaseAnonKey {
    return _getEnv('SUPABASE_ANON_KEY') ?? 
           const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  }

  static String get mapboxAccessToken {
    return _getEnv('MAPBOX_ACCESS_TOKEN') ??
           const String.fromEnvironment(
             'MAPBOX_ACCESS_TOKEN',
             defaultValue: 'pk.eyJ1IjoiYnlncmFmMDEiLCJhIjoiY213Y2o2dnpmMDM3OTJ5c2M4cjV3NThsZyJ9.3asuElOYlUMITRxJLGh2Hw',
           );
  }

  static String get defaultSyncHost {
    final custom = _getEnv('SYNC_HOST');
    if (custom != null && custom.trim().isNotEmpty) return custom.trim();
    if (kIsWeb) return 'localhost';
    try {
      if (Platform.isAndroid) return '192.168.1.101';
    } catch (_) {}
    return 'localhost';
  }

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
