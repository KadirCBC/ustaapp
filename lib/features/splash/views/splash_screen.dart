import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/features/auth/models/user_role.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _rippleController;

  // Animasyonlar
  late final Animation<double> _iconScale;
  late final Animation<double> _iconFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _logoFade;

  late final Animation<double> _progressFade;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Uygulama ilk açıldığında hemen konum iznini sor ve uyduları hazırla
    _requestInitialLocationPermission();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // Hızlı ve akıcı açılış süresi (850 milisaniye)
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    // Dairesel radar dalgası
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();



    // 1. İkon belirişi
    _iconScale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.42, curve: Curves.easeOutBack),
      ),
    );
    _iconFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
    );

    // 2. UstaGelio logo kayması
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOutCubic),
      ),
    );
    _logoFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.35, 0.60, curve: Curves.easeIn),
    );



    // 4. İnce yükleme çizgisi
    _progressFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.75, 0.98, curve: Curves.easeIn),
    );

    _mainController.forward().then((_) => _checkAuthAndNavigate());
  }

  Future<void> _requestInitialLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Konum servisi kapalı.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        try {
          await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Açılışta konum izni hatası: $e');
    }
  }

  void _checkAuthAndNavigate() {
    if (_navigated || !mounted) return;
    _navigated = true;

    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated || authState.role == null) {
      context.go('/auth');
    } else if (authState.role == UserRole.usta) {
      context.go('/usta/orders');
    } else {
      context.go('/customer/home');
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: _checkAuthAndNavigate,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
          // 0. Temel Degrade Arka Plan
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFF8FAFC),
                  Color(0xFFEFF6FF),
                ],
              ),
            ),
          ),

          // 1. 3D Usta & Servis Arka Plan Kahraman Görseli (Alt boşluksuz, kenara sıfır oturan)
          Positioned(
            left: -20,
            right: -20,
            bottom: -32,
            top: 60,
            child: Opacity(
              opacity: 0.42,
              child: Image.asset(
                'assets/images/splash_hero_bg.png',
                fit: BoxFit.fitWidth,
                alignment: Alignment.bottomCenter,
              ),
            ),
          ),

          // 2. Okunurluk ve Yumuşak Işık Katmanı
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.85),
                  Colors.white.withValues(alpha: 0.20),
                  Colors.white.withValues(alpha: 0.75),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // 3. Ön Plan İçerikleri
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),

                // ===============================================================
                // 1. İKON & RADAR DALGASI (Mavi Çizgi Alanı - En Üst)
                // ===============================================================
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dışarıya doğru genişleyen radar dalgası
                    AnimatedBuilder(
                      animation: _rippleController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _RipplePainter(_rippleController.value),
                          size: const Size(170, 170),
                        );
                      },
                    ),

                    // Ana Uygulama İkonu
                    FadeTransition(
                      opacity: _iconFade,
                      child: ScaleTransition(
                        scale: _iconScale,
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.22),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                              BoxShadow(
                                color: const Color(0xFFF97316).withValues(alpha: 0.25),
                                blurRadius: 32,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ===============================================================
                // 2. YATAY LOGO & SLOGAN (Kırmızı Çizgi Alanı - İkonun Hemen Altı)
                // ===============================================================
                SlideTransition(
                  position: _logoSlide,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: Image.asset(
                      'assets/images/ustagelio_logo.png',
                      height: 56,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/app_logo.png',
                        height: 56,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // ===============================================================
                // 4. ALT YÜKLENİYOR ÇİZGİSİ
                // ===============================================================
                FadeTransition(
                  opacity: _progressFade,
                  child: SizedBox(
                    width: 56,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: const LinearProgressIndicator(
                        minHeight: 3.5,
                        backgroundColor: Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF97316)),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 36),
              ],
            ),
          ),
      ],
    ),
  ),
);
  }
}

/// İkonun arkasından dışarıya doğru açılan şık radar dalgası
class _RipplePainter extends CustomPainter {
  final double progress;

  _RipplePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 2; i++) {
      final p = (progress + (i * 0.5)) % 1.0;
      final radius = 46.0 + (p * (maxRadius - 46.0));
      final opacity = (1.0 - p) * 0.35;

      final paint = Paint()
        ..color = const Color(0xFFF97316).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
