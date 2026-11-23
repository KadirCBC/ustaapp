import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class UstaGelioApp extends ConsumerStatefulWidget {
  const UstaGelioApp({super.key});

  @override
  ConsumerState<UstaGelioApp> createState() => _UstaGelioAppState();
}

class _UstaGelioAppState extends ConsumerState<UstaGelioApp> {
  static const MethodChannel _callChannel =
      MethodChannel('com.example.ustaapp/call_screen');

  @override
  void initState() {
    super.initState();
    _setupNativeCallListener();
  }

  void _setupNativeCallListener() {
    _callChannel.setMethodCallHandler((call) async {
      if (call.method == 'onIncomingCall') {
        final cid = call.arguments?.toString();
        if (cid != null && cid.isNotEmpty && mounted) {
          debugPrint('>>> [MainActivity -> Flutter] Gelen çağrı ekranı açılıyor: $cid');
          ref.read(appRouterProvider).push('/usta/incoming-call/$cid');
        }
      }
    });

    // Soğuk açılışta bekleyen çağrıyı kontrol et
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final pendingId = await _callChannel.invokeMethod<String>('getPendingCallId');
        if (pendingId != null && pendingId.isNotEmpty && mounted) {
          debugPrint('>>> [MainActivity -> Flutter] Bekleyen çağrı açılıyor: $pendingId');
          ref.read(appRouterProvider).push('/usta/incoming-call/$pendingId');
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
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
