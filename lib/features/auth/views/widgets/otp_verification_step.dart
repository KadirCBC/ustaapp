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

class _OtpVerificationStepState extends ConsumerState<OtpVerificationStep>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _otpController;
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _pulseController;
  late final Animation<double> _cursorFadeAnimation;

  @override
  void initState() {
    super.initState();
    final initialCode = ref.read(phoneAuthControllerProvider).otpCode;
    _otpController = TextEditingController(text: initialCode);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);

    _cursorFadeAnimation = Tween<double>(begin: 0.15, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

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
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);
    final controller = ref.read(phoneAuthControllerProvider.notifier);
    final otpText = state.otpCode;
    final isCodeComplete = otpText.trim().length == 6;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Üst alan ile kusursuz bütünlük
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            children: [
              // ===============================================================
              // 1. ÜST HERO ALANI (Full-Bleed Koyu Mavi/Kehribar Gradyan)
              // ===============================================================
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0F172A), // Slate 900
                      Color(0xFF1E293B), // Slate 800
                      Color(0xFF28180E), // Sıcak amber-bakır derinliği
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  top: !kIsWeb,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Üst Navigasyon & Rozet Satırı
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Numarayı Değiştir Butonu
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: state.isLoading
                                    ? null
                                    : () => controller.backToPhoneInput(),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 13, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(20),
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
                                        size: 12,
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
                            ),

                            // SMS Güvenliği Rozeti
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.16),
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
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF34D399),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // İkon Rozeti (Katmanlı Sıcak Turuncu Doku)
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.ustaPrimary.withValues(alpha: 0.35),
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 62,
                              height: 62,
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
                                  width: 1.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.mark_email_unread_rounded,
                                  size: 30,
                                  color: AppTheme.ustaPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

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
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: state.isLoading
                                ? null
                                : () => controller.backToPhoneInput(),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.phone_iphone_rounded,
                                    size: 14,
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
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.edit_rounded,
                                    size: 12.5,
                                    color: Colors.white.withValues(alpha: 0.65),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),
                        Text(
                          'numarasına 6 haneli güvenlik kodu iletildi',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.72),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ===============================================================
              // 2. ALT FORM ALANI (Sürekli, Ferah ve Beyaz Kart)
              // ===============================================================
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 32),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
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

                          // ===================================================
                          // RESPONSIVE 6 HANELİ DİJİTAL KUTULAR
                          // ===================================================
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final availableWidth = constraints.maxWidth;
                              const double gap = 6.0;
                              final double calculatedWidth =
                                  ((availableWidth - (5 * gap)) / 6).clamp(32.0, 48.0);
                              final double boxHeight = (calculatedWidth * 1.22).clamp(42.0, 56.0);

                              return GestureDetector(
                                onTap: () => _focusNode.requestFocus(),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(11, (i) {
                                    if (i.isOdd) return const SizedBox(width: gap);
                                    final index = i ~/ 2;
                                    final char = index < otpText.length ? otpText[index] : '';
                                    final isCurrent = index == otpText.length;

                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      width: calculatedWidth,
                                      height: boxHeight,
                                      decoration: BoxDecoration(
                                        color: char.isNotEmpty
                                            ? const Color(0xFFFFF7ED)
                                            : (isCurrent
                                                ? Colors.white
                                                : const Color(0xFFF8FAFC)),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isCurrent
                                              ? AppTheme.ustaPrimary
                                              : (char.isNotEmpty
                                                  ? const Color(0xFFFB923C)
                                                  : const Color(0xFFCBD5E1)),
                                          width: isCurrent
                                              ? 2.0
                                              : (char.isNotEmpty ? 1.6 : 1.2),
                                        ),
                                        boxShadow: isCurrent
                                            ? [
                                                BoxShadow(
                                                  color: AppTheme.ustaPrimary.withValues(alpha: 0.22),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ]
                                            : (char.isNotEmpty
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(0xFFEA580C).withValues(alpha: 0.08),
                                                      blurRadius: 6,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ]
                                                : null),
                                      ),
                                      child: Center(
                                        child: char.isNotEmpty
                                            ? Text(
                                                char,
                                                style: TextStyle(
                                                  fontSize: (calculatedWidth * 0.48).clamp(16.0, 22.0),
                                                  fontWeight: FontWeight.w900,
                                                  color: const Color(0xFF9A3412),
                                                ),
                                              )
                                            : (isCurrent
                                                ? AnimatedBuilder(
                                                    animation: _cursorFadeAnimation,
                                                    builder: (context, child) {
                                                      return Opacity(
                                                        opacity: _cursorFadeAnimation.value,
                                                        child: Container(
                                                          width: 2.2,
                                                          height: 20,
                                                          decoration: BoxDecoration(
                                                            color: AppTheme.ustaPrimary,
                                                            borderRadius: BorderRadius.circular(2),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  )
                                                : Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFFCBD5E1),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  )),
                                      ),
                                    );
                                  }),
                                ),
                              );
                            },
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

                          // ===================================================
                          // TEST HIZLI DOLDUR ROZETİ
                          // ===================================================
                          Center(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _otpController.text = '123456';
                                  controller.setOtp('123456');
                                  controller.verifyOtp();
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 7.5),
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
                                      color: const Color(0xFFFDBA74).withValues(alpha: 0.9),
                                      width: 1.1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFEA580C).withValues(alpha: 0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.bolt_rounded,
                                        size: 15,
                                        color: AppTheme.ustaPrimary,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        'Hızlı Test Kodu: 123456 (Tek Tık)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFC2410C),
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Hata Mesajı Kutusu
                          if (state.errorMessage != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 13, vertical: 9),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Color(0xFFDC2626),
                                    size: 17,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      state.errorMessage!,
                                      style: const TextStyle(
                                        color: Color(0xFFB91C1C),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 22),

                          // ===================================================
                          // DOĞRULA VE DEVAM ET BUTONU
                          // ===================================================
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 52,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: (isCodeComplete && !state.isLoading)
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFEA580C),
                                        Color(0xFFF97316),
                                        Color(0xFFFB923C),
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    )
                                  : const LinearGradient(
                                      colors: [
                                        Color(0xFFE2E8F0),
                                        Color(0xFFCBD5E1),
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: (isCodeComplete && !state.isLoading)
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.ustaPrimary.withValues(alpha: 0.32),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: (!isCodeComplete || state.isLoading)
                                    ? null
                                    : () {
                                        HapticFeedback.mediumImpact();
                                        controller.verifyOtp();
                                      },
                                child: Center(
                                  child: state.isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Doğrula ve Devam Et',
                                              style: TextStyle(
                                                color: isCodeComplete
                                                    ? Colors.white
                                                    : const Color(0xFF64748B),
                                                fontSize: 15.5,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 18,
                                              color: isCodeComplete
                                                  ? Colors.white
                                                  : const Color(0xFF64748B),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ===================================================
                          // TEKRAR GÖNDER SAYACI / BUTONU
                          // ===================================================
                          Center(
                            child: state.canResendOtp
                                ? TextButton.icon(
                                    onPressed: state.isLoading
                                        ? null
                                        : () {
                                            HapticFeedback.lightImpact();
                                            controller.resendOtp();
                                          },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                    ),
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 17,
                                      color: AppTheme.ustaPrimary,
                                    ),
                                    label: const Text(
                                      'Yeni Kod Gönder',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.ustaPrimary,
                                      ),
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 7),
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
                                          size: 14,
                                          color: Color(0xFFEA580C),
                                        ),
                                        const SizedBox(width: 6),
                                        RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              fontSize: 12,
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

                          const SizedBox(height: 14),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 12),

                          // 256-Bit SSL Uçtan Uca Güvenlik Dipnotu
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 13,
                                color: Color(0xFF10B981),
                              ),
                              SizedBox(width: 5),
                              Text(
                                '256-Bit SSL ile Uçtan Uca Güvenli Doğrulama',
                                style: TextStyle(
                                  fontSize: 11,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
