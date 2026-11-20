import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/auth/controllers/auth_controller.dart';

class OtpVerificationStep extends ConsumerStatefulWidget {
  const OtpVerificationStep({super.key});

  @override
  ConsumerState<OtpVerificationStep> createState() => _OtpVerificationStepState();
}

class _OtpVerificationStepState extends ConsumerState<OtpVerificationStep> {
  late final TextEditingController _otpController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final initialCode = ref.read(phoneAuthControllerProvider).otpCode;
    _otpController = TextEditingController(text: initialCode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);
    final controller = ref.read(phoneAuthControllerProvider.notifier);
    final otpText = state.otpCode;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFF),
      body: Stack(
        children: [
          // Arka plan lüks yumuşak ambiyans dalgaları
          Positioned.fill(
            child: CustomPaint(
              painter: _LuxuryOtpBackgroundPainter(),
            ),
          ),

          SafeArea(
            top: !kIsWeb,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // =======================================================
                      // 1. ÜST LÜKS HERO ALANI (UstaGelio Temasına Uygun)
                      // =======================================================
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF0F172A), // Gece siyahı / Slate 900
                              Color(0xFF1E293B), // Slate 800
                              Color(0xFF2E190E), // Sıcak amber-bakır derinliği
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: AppTheme.ustaPrimary.withValues(alpha: 0.12),
                              blurRadius: 36,
                              offset: const Offset(0, 18),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                          child: Column(
                            children: [
                              // Üst Navigasyon & Rozet Satırı
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Numarayı Değiştir Butonu
                                  InkWell(
                                    onTap: state.isLoading ? null : () => controller.backToPhoneInput(),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.16),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.arrow_back_ios_new_rounded,
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Numarayı Değiştir',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Güvenli Oturum Rozeti
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.verified_user_rounded,
                                          size: 13,
                                          color: Color(0xFF34D399),
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          'SMS Güvenliği',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF34D399),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 18),

                              // Lüks 3D Şampanya / Sıcak Turuncu Rozet
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Arka parıltı çemberi
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.ustaPrimary.withValues(alpha: 0.40),
                                          blurRadius: 26,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Ana rozet
                                  Container(
                                    width: 66,
                                    height: 66,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFFF7ED),
                                          Color(0xFFFFEDD5),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: const Color(0xFFFDBA74),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.25),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.mark_email_unread_rounded,
                                        size: 32,
                                        color: AppTheme.ustaPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              const Text(
                                'SMS Doğrulama Kodu',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Telefon Numarası Vurgulama Hapı
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.20),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.phone_iphone_rounded,
                                      size: 15,
                                      color: Color(0xFFFED7AA),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${AppConstants.defaultCountryCode} ${state.formattedPhone}',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFFED7AA),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 6),
                              Text(
                                'numarasına 6 haneli güvenlik kodu iletildi',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // =======================================================
                      // 2. KOD GİRİŞ VE İŞLEM KARTI (Lüks Beyaz Kart)
                      // =======================================================
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color(0xFFFED7AA).withValues(alpha: 0.70),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEA580C).withValues(alpha: 0.08),
                                blurRadius: 32,
                                offset: const Offset(0, 16),
                              ),
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(
                                child: Text(
                                  '6 Haneli Kodu Girin',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Center(
                                child: Text(
                                  'Telefonunuza SMS olarak gelen kodu kutulara yazın',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),

                              // ===============================================
                              // 6 HANELİ DİJİTAL KUTULAR
                              // ===============================================
                              GestureDetector(
                                onTap: () => _focusNode.requestFocus(),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(6, (index) {
                                    final char = index < otpText.length ? otpText[index] : '';
                                    final isCurrent = index == otpText.length;

                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 46,
                                      height: 56,
                                      margin: const EdgeInsets.symmetric(horizontal: 3.5),
                                      decoration: BoxDecoration(
                                        color: char.isNotEmpty
                                            ? const Color(0xFFFFF7ED)
                                            : (isCurrent ? Colors.white : const Color(0xFFF8FAFC)),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isCurrent
                                              ? AppTheme.ustaPrimary
                                              : (char.isNotEmpty
                                                  ? const Color(0xFFFB923C)
                                                  : const Color(0xFFCBD5E1)),
                                          width: isCurrent ? 2.2 : (char.isNotEmpty ? 1.8 : 1.2),
                                        ),
                                        boxShadow: isCurrent
                                            ? [
                                                BoxShadow(
                                                  color: AppTheme.ustaPrimary.withValues(alpha: 0.25),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ]
                                            : (char.isNotEmpty
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(0xFFEA580C).withValues(alpha: 0.10),
                                                      blurRadius: 6,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ]
                                                : null),
                                      ),
                                      child: Center(
                                        child: Text(
                                          char.isNotEmpty ? char : (isCurrent ? '|' : '·'),
                                          style: TextStyle(
                                            fontSize: char.isNotEmpty ? 24 : (isCurrent ? 20 : 18),
                                            fontWeight: FontWeight.w900,
                                            color: char.isNotEmpty
                                                ? const Color(0xFF9A3412)
                                                : (isCurrent
                                                    ? AppTheme.ustaPrimary
                                                    : const Color(0xFF94A3B8)),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),

                              // Görünmez Klavye TextField
                              Opacity(
                                opacity: 0.0,
                                child: SizedBox(
                                  height: 1,
                                  child: TextField(
                                    controller: _otpController,
                                    focusNode: _focusNode,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    onChanged: (val) {
                                      controller.setOtp(val);
                                      if (val.trim().length == 6) {
                                        controller.verifyOtp();
                                      }
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // ===============================================
                              // TEST HIZLI DOLDUR ROZETİ (Lüks Kehribar Rozet)
                              // ===============================================
                              Center(
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    _otpController.text = '123456';
                                    controller.setOtp('123456');
                                    controller.verifyOtp();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFFF7ED),
                                          Color(0xFFFEF3C7),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFFDBA74),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFEA580C).withValues(alpha: 0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.bolt_rounded,
                                          size: 16,
                                          color: AppTheme.ustaPrimary,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          'Hızlı Test Kodu: 123456 (Tek Tık)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFC2410C),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Hata Mesajı Kutusu
                              if (state.errorMessage != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFFECACA)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: Color(0xFFDC2626),
                                        size: 19,
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Text(
                                          state.errorMessage!,
                                          style: const TextStyle(
                                            color: Color(0xFFB91C1C),
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 24),

                              // ===============================================
                              // DOĞRULA VE DEVAM ET BUTONU (UstaGelio Turuncu)
                              // ===============================================
                              Container(
                                height: 54,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFEA580C),
                                      Color(0xFFF97316),
                                      Color(0xFFFB923C),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.ustaPrimary.withValues(alpha: 0.38),
                                      blurRadius: 18,
                                      offset: const Offset(0, 7),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: (state.isLoading || state.otpCode.trim().length != 6)
                                        ? null
                                        : () {
                                            HapticFeedback.mediumImpact();
                                            controller.verifyOtp();
                                          },
                                    child: Center(
                                      child: state.isLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Doğrula ve Devam Et',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 19,
                                                  color: Colors.white,
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 18),

                              // ===============================================
                              // TEKRAR GÖNDER SAYACI / BUTONU
                              // ===============================================
                              Center(
                                child: state.canResendOtp
                                    ? TextButton.icon(
                                        onPressed: state.isLoading
                                            ? null
                                            : () {
                                                HapticFeedback.lightImpact();
                                                controller.resendOtp();
                                              },
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                          size: 18,
                                          color: AppTheme.ustaPrimary,
                                        ),
                                        label: const Text(
                                          'Yeni Kod Gönder',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.ustaPrimary,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.timer_outlined,
                                              size: 15,
                                              color: Color(0xFFEA580C),
                                            ),
                                            const SizedBox(width: 6),
                                            RichText(
                                              text: TextSpan(
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  color: Color(0xFF475569),
                                                ),
                                                children: [
                                                  const TextSpan(text: 'Tekrar kod isteyebilirsiniz: '),
                                                  TextSpan(
                                                    text: '${state.resendCountdown} sn',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFFEA580C),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),

                              const SizedBox(height: 16),
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              const SizedBox(height: 14),

                              // 256-Bit SSL Uçtan Uca Güvenlik Dipnotu
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 14,
                                    color: Color(0xFF10B981),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '256-Bit SSL ile Uçtan Uca Güvenli Doğrulama',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Arka plan yumuşak estetik eğri ve ambiyans dokusu
class _LuxuryOtpBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Sıcak Turuncu Üst Dalga Eğrisi
    final wavePaint = Paint()
      ..color = const Color(0xFFEA580C).withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height * 0.42);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.52,
      0,
      size.height * 0.40,
    );
    path.close();
    canvas.drawPath(path, wavePaint);

    // 2. Alt Yuvarlak Işık Yansımaları
    final glowPaint = Paint()
      ..color = const Color(0xFFFED7AA).withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 48);

    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.70), 90, glowPaint);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.85), 70, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
