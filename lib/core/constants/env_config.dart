import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get supabaseUrl {
    return dotenv.env['SUPABASE_URL'] ?? 
           const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  }

  static String get supabaseAnonKey {
    return dotenv.env['SUPABASE_ANON_KEY'] ?? 
           const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  }

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
