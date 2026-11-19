import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/core/constants/env_config.dart';
import 'package:ustaapp/core/router/app_router.dart';
import 'package:ustaapp/core/services/app_background_service.dart';
import 'package:ustaapp/core/services/notification_service.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. Bildirim servisini başlat (Hızlı UI açılışı için ana akışta)
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Bildirim servisi başlatılırken hata: $e');
  }

  // Arka plan kalıcı dinleyici servisini arayüzü (runApp) BLOKE ETMEDEN asenkron başlat
  unawaited(AppBackgroundService.instance.initialize().catchError((e) {
    debugPrint('Arka plan servisi başlatma uyarısı: $e');
  }));

  // Mapbox Public Token yapılandırması
  MapboxOptions.setAccessToken(AppConstants.mapboxAccessToken);

  // 1. Çevresel değişkenleri (.env) yükle
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('.env dosyası yüklenirken uyarı: $e');
  }

  // 2. Supabase İstemcisini Başlat
  final supabaseUrl = EnvConfig.supabaseUrl;
  final supabaseAnonKey = EnvConfig.supabaseAnonKey;

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
      debug: false,
    );
  } else {
    debugPrint(
      'UYARI: Supabase URL veya Anon Key eksik! Lütfen .env dosyanızı doldurunuz.',
    );
  }

  // 3. Uygulamayı Riverpod ProviderScope ile başlat
  runApp(
    const ProviderScope(
      child: UstamBuradaApp(),
    ),
  );
}

class UstamBuradaApp extends ConsumerWidget {
  const UstamBuradaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // GoRouter örneğini al
    final router = ref.watch(appRouterProvider);

    // Aktif kullanıcının rolünü dinle (Müşteri mi, Usta mı?)
    final authState = ref.watch(authStateProvider);

    // Kullanıcının rolüne göre Dinamik Tema:
    // - Müşteri modu: Modern Lacivert / Temiz Beyaz
    // - Usta modu: Dikkat çekici Endüstriyel Turuncu / Koyu Gri
    final activeTheme = AppTheme.themeForRole(authState.role);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: activeTheme,
      routerConfig: router,
    );
  }
}
