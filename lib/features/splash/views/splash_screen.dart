import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  late final AnimationController _shimmerController;

  // Animasyonlar
  late final Animation<double> _iconScale;
  late final Animation<double> _iconFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _logoFade;
  late final Animation<double> _sloganFade;
  late final Animation<double> _sloganScale;
  late final Animation<Offset> _sloganSlide;
  late final Animation<double> _lineWidth;
  late final Animation<double> _progressFade;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Sistem çubuklarını ayarla
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // Ana koreografi zamanlayıcısı (2.3 saniye)
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    );

    // Dairesel radar/halka efekti
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    // Slogan altın ışıltı/shimmer animasyonu
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // 1. İkon belirişi (0.0 - 0.42)
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

    // 2. Logo kayması ve belirişi (0.35 - 0.65)
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

    // 3. Slogan Büyüme, Kayma ve Beliriş Animasyonu (0.48 - 0.82)
    _sloganFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.48, 0.78, curve: Curves.easeIn),
    );
    _sloganScale = Tween<double>(begin: 0.80, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.48, 0.82, curve: Curves.easeOutBack),
      ),
    );
    _sloganSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.48, 0.80, curve: Curves.easeOutCubic),
      ),
    );
    _lineWidth = Tween<double>(begin: 0.0, end: 32.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.55, 0.88, curve: Curves.easeOutCubic),
      ),
    );

    // 4. İnce yükleme çubuğu (0.75 - 1.0)
    _progressFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.75, 0.98, curve: Curves.easeIn),
    );

    // Animasyonu başlat ve bitince yönlendir
    _mainController.forward().then((_) => _checkAuthAndNavigate());
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
      context.go('/customer/map');
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _rippleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // ===============================================================
              // İKON VE RADAR DALGASI ANİMASYONU
              // ===============================================================
              Stack(
                alignment: Alignment.center,
                children: [
                  // Dışarıya doğru genişleyen radar halkaları
                  AnimatedBuilder(
                    animation: _rippleController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _RipplePainter(_rippleController.value),
                        size: const Size(220, 220),
                      );
                    },
                  ),

                  // Ana Uygulama İkonu (Scale & Fade & Shadow)
                  FadeTransition(
                    opacity: _iconFade,
                    child: ScaleTransition(
                      scale: _iconScale,
                      child: Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.22),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: const Color(0xFFF97316).withValues(alpha: 0.25),
                              blurRadius: 36,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            width: 104,
                            height: 104,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ===============================================================
              // YATAY LOGO VE METİNLER (Slide & Fade)
              // ===============================================================
              SlideTransition(
                position: _logoSlide,
                child: FadeTransition(
                  opacity: _logoFade,
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    height: 54,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Modern & Profesyonel Hareketli Slogan
              FadeTransition(
                opacity: _sloganFade,
                child: SlideTransition(
                  position: _sloganSlide,
                  child: ScaleTransition(
                    scale: _sloganScale,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_shimmerController, _lineWidth]),
                      builder: (context, _) {
                        final shimmerValue = _shimmerController.value;
                        final currentLineWidth = _lineWidth.value;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Sol açılan degrade çizgi
                            Container(
                              width: currentLineWidth,
                              height: 2.0,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFF97316).withValues(alpha: 0.0),
                                    const Color(0xFFF97316).withValues(alpha: 0.85),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Büyütülmüş & Altın/Turuncu Shimmer Işıltılı Slogan
                            ShaderMask(
                              shaderCallback: (bounds) {
                                return LinearGradient(
                                  begin: Alignment(-1.6 + (shimmerValue * 3.2), -0.3),
                                  end: Alignment(-0.4 + (shimmerValue * 3.2), 0.3),
                                  colors: const [
                                    Color(0xFF0F172A),
                                    Color(0xFFF97316),
                                    Color(0xFFFBBF24),
                                    Color(0xFF0F172A),
                                  ],
                                  stops: const [0.0, 0.45, 0.55, 1.0],
                                ).createShader(bounds);
                              },
                              child: const Text(
                                'En Yakın Usta Kapında!',
                                style: TextStyle(
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Sağ açılan degrade çizgi
                            Container(
                              width: currentLineWidth,
                              height: 2.0,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFF97316).withValues(alpha: 0.85),
                                    const Color(0xFFF97316).withValues(alpha: 0.0),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 4),

              // Alt Yükleniyor Çizgisi
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
      final radius = 52.0 + (p * (maxRadius - 52.0));
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
