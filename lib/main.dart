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

  // Mapbox Public Token yapılandırması
  MapboxOptions.setAccessToken(AppConstants.mapboxAccessToken);

  // 1. Kritik servisleri paralel olarak hızlıca başlat
  await Future.wait([
    dotenv.load(fileName: '.env').catchError((e) {
      debugPrint('.env yüklenirken uyarı: $e');
    }),
    NotificationService.instance.initialize().catchError((e) {
      debugPrint('Bildirim servisi başlatma uyarısı: $e');
    }),
  ]);

  // 2. Supabase İstemcisini Başlat
  final supabaseUrl = EnvConfig.supabaseUrl;
  final supabaseAnonKey = EnvConfig.supabaseAnonKey;

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
        debug: false,
      );
    } catch (e) {
      debugPrint('Supabase başlatma uyarısı: $e');
    }
  }

  // 3. Arka plan kalıcı servisini ana iş parçacığını bekletmeden asenkron başlat
  unawaited(AppBackgroundService.instance.initialize().catchError((e) {
    debugPrint('Arka plan servisi başlatma uyarısı: $e');
  }));

  // 4. Uygulamayı Riverpod ProviderScope ile anında başlat
  runApp(
    const ProviderScope(
      child: UstaGelioApp(),
    ),
  );
}

class UstaGelioApp extends ConsumerWidget {
  const UstaGelioApp({super.key});

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
