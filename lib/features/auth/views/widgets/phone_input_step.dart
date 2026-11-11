import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/core/utils/phone_formatter.dart';
import 'package:ustaapp/features/auth/controllers/auth_controller.dart';
import 'package:ustaapp/features/auth/models/user_role.dart';

class PhoneInputStep extends ConsumerStatefulWidget {
  const PhoneInputStep({super.key});

  @override
  ConsumerState<PhoneInputStep> createState() => _PhoneInputStepState();
}

class _PhoneInputStepState extends ConsumerState<PhoneInputStep>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _phoneController;
  late final AnimationController _pulseController;
  final _maskFormatter = PhoneFormatter.trPhoneMask;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    final currentPhone = ref.read(phoneAuthControllerProvider).formattedPhone;
    _phoneController = TextEditingController(text: currentPhone);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleQuickEntry(UserRole role, String sourceLabel) {
    HapticFeedback.mediumImpact();
    final controller = ref.read(phoneAuthControllerProvider.notifier);
    final demoName = role == UserRole.usta
        ? 'Hasan Usta (Elektrikçi)'
        : 'Ahmet Demir (Müşteri)';
    controller.directDemoLogin(role, fullName: demoName);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$sourceLabel • ${role == UserRole.usta ? 'Usta' : 'Müşteri'} olarak devam ediliyor...',
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    if (role == UserRole.usta) {
      context.go('/usta/orders');
    } else {
      context.go('/customer/map');
    }
  }

  void _showLegalModal(String title, String content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF475569),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Anladım',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);
    final controller = ref.read(phoneAuthControllerProvider.notifier);
    final selectedRole = state.selectedRole ?? UserRole.musteri;
    final isUsta = selectedRole == UserRole.usta;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF1F5F9),
            Color(0xFFF8FAFC),
            Color(0xFFFFFFFF),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 14),

              // ===============================================================
              // 1. ÜST MARKA ALANI (Logo + Canlı İstatistik Rozeti)
              // ===============================================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Logo Kutusu + Canlı Yeşil Nokta
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFFFFF), Color(0xFFEFF6FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: const Color(0xFFDBEAFE),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E3A8A).withValues(alpha: 0.10),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.handyman_rounded,
                                size: 34,
                                color: Color(0xFF1E3A8A),
                              ),
                              Positioned(
                                top: 13,
                                right: 13,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF59E0B),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.bolt_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Canlı Yeşil Nabız Noktası
                        Positioned(
                          right: -3,
                          bottom: -3,
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final glow = 2.0 + (_pulseController.value * 4.0);
                              return Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.55),
                                      blurRadius: glow * 2,
                                      spreadRadius: glow * 0.4,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // UstamBurada + Altın Onay Rozeti
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'UstamBurada',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.verified_rounded,
                          size: 22,
                          color: Color(0xFFF59E0B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'En Yakın Usta Kapında!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 8.420+ ONAYLI USTA ÇEVRİMİÇİ Rozeti
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) => Opacity(
                              opacity: 0.55 + (_pulseController.value * 0.45),
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF059669),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '8.420+ ONAYLI USTA ÇEVRİMİÇİ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ===============================================================
              // 2. SEGMENTED ROL SEÇİCİ (Müşteriyim | Ustayım)
              // ===============================================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0).withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _RoleSegmentTab(
                              label: 'Müşteriyim',
                              icon: Icons.person_search_rounded,
                              isSelected: !isUsta,
                              activeColor: const Color(0xFF1E3A8A),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                controller.selectRole(UserRole.musteri);
                              },
                            ),
                          ),
                          Expanded(
                            child: _RoleSegmentTab(
                              label: 'Ustayım',
                              icon: Icons.handyman_rounded,
                              isSelected: isUsta,
                              activeColor: const Color(0xFFEA580C),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                controller.selectRole(UserRole.usta);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        isUsta
                            ? 'Çevrendeki acil işleri gör, taban ücretini belirle ve kazan'
                            : 'Tesisat, elektrik, çilingir ve tadilat için anında usta çağır',
                        key: ValueKey(isUsta),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ===============================================================
              // 3. ANA GİRİŞ KARTI
              // ===============================================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Kart Başlığı + Sağ İkon Rozeti
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Giriş Yap veya Kaydol',
                                  style: TextStyle(
                                    fontSize: 18.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Doğrulama kodu SMS ile iletilecektir',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7).withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: const Icon(
                              Icons.sms_outlined,
                              size: 20,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Telefon Label
                      const Text(
                        'Telefon Numarası',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Telefon Giriş Kutusu
                      Focus(
                        onFocusChange: (focused) => setState(() => _isFocused = focused),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: _isFocused ? Colors.white : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: state.errorMessage != null
                                  ? const Color(0xFFEF4444)
                                  : (_isFocused ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0)),
                              width: _isFocused ? 2 : 1.2,
                            ),
                            boxShadow: _isFocused
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: Row(
                            children: [
                              // Bayrak + Ülke Kodu Dropdown Görünümü
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('🇹🇷', style: TextStyle(fontSize: 16)),
                                    SizedBox(width: 6),
                                    Text(
                                      AppConstants.defaultCountryCode,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Numara TextField
                              Expanded(
                                child: TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [_maskFormatter],
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: Color(0xFF0F172A),
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: '5XX XXX XX XX',
                                    hintStyle: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    fillColor: Colors.transparent,
                                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onChanged: (val) {
                                    controller.setPhone(val);
                                    setState(() {});
                                  },
                                  onSubmitted: (_) {
                                    if (!state.isLoading) controller.sendOtp();
                                  },
                                ),
                              ),

                              if (_phoneController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _phoneController.clear();
                                    controller.setPhone('');
                                    setState(() {});
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(6.0),
                                    child: Icon(
                                      Icons.cancel_rounded,
                                      color: Color(0xFF94A3B8),
                                      size: 18,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 17),
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

                      const SizedBox(height: 12),

                      // Yeşil Kilitli Hızlı Giriş Bilgilendirmesi
                      const Row(
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 15, color: Color(0xFF059669)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Şifresiz, tek kullanımlık SMS onay kodu ile hızlı giriş',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Altın/Amber Ana CTA Butonu
                      Container(
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.38),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: state.isLoading ? null : () => controller.sendOtp(),
                            child: Center(
                              child: state.isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Devam Et / Giriş Yap',
                                          style: TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Color(0xFF0F172A),
                                          size: 20,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Ayırıcı: VEYA ŞUNUNLA DEVAM ET
                      const Row(
                        children: [
                          Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'VEYA ŞUNUNLA DEVAM ET',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Google & Apple Giriş Butonları (Aynı zamanda seçili rol için hızlı önizleme sağlar)
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () => _handleQuickEntry(selectedRole, 'Google'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  minimumSize: Size.zero,
                                  padding: EdgeInsets.zero,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CustomPaint(
                                      size: const Size(18, 18),
                                      painter: _GoogleLogoPainter(),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Google',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () => _handleQuickEntry(selectedRole, 'Apple'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  minimumSize: Size.zero,
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.apple_rounded, size: 22, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text(
                                      'Apple',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Hızlı Demo Geçiş Hapı (Seçili role göre)
                      InkWell(
                        onTap: () => _handleQuickEntry(selectedRole, 'Demo Modu'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isUsta ? const Color(0xFFFFF7ED) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isUsta ? const Color(0xFFFED7AA) : const Color(0xFFBFDBFE),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.flash_on_rounded,
                                size: 15,
                                color: isUsta ? const Color(0xFFEA580C) : const Color(0xFF1D4ED8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isUsta
                                    ? 'Hızlı Önizleme: Usta Panelini Aç'
                                    : 'Hızlı Önizleme: Müşteri Haritasını Aç',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isUsta ? const Color(0xFFEA580C) : const Color(0xFF1E3A8A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ===============================================================
              // 4. NEDEN USTAMBURADA? (Yatay Kaydırılabilir Özellik Kartları)
              // ===============================================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Neden UstamBurada?',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '100% Güvence',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 138,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: const [
                    _FeatureBenefitCard(
                      icon: Icons.location_on_outlined,
                      iconColor: Color(0xFF059669),
                      iconBgColor: Color(0xFFD1FAE5),
                      title: 'Canlı Harita Takibi',
                      badgeText: '● Anlık Konum',
                      badgeColor: Color(0xFF059669),
                      description:
                          'Çağırdığın ustanın sana kaç dakikada geleceğini canlı haritada adım adım izle.',
                    ),
                    SizedBox(width: 12),
                    _FeatureBenefitCard(
                      icon: Icons.workspace_premium_outlined,
                      iconColor: Color(0xFFD97706),
                      iconBgColor: Color(0xFFFEF3C7),
                      title: 'Doğrulanmış Ustalar',
                      badgeText: 'MYK & Adli Sicil Onaylı',
                      badgeColor: Color(0xFFB45309),
                      description:
                          'Ustaların mesleki yeterlilik belgeleri ve referansları titizlikle kontrol edilir.',
                    ),
                    SizedBox(width: 12),
                    _FeatureBenefitCard(
                      icon: Icons.shield_outlined,
                      iconColor: Color(0xFF2563EB),
                      iconBgColor: Color(0xFFDBEAFE),
                      title: 'Güvenli Provizyon',
                      badgeText: 'İyzico / PayTR Koruması',
                      badgeColor: Color(0xFF1D4ED8),
                      description:
                          'İş tamamlanıp onay vermeden ödeme tutarı ustanın hesabına aktarılmaz.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ===============================================================
              // 5. ALT YASAL METİN & SSL GÜVENLİK MÜHRÜ
              // ===============================================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(text: 'Giriş yaparak '),
                          TextSpan(
                            text: 'Kullanım Koşulları',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _showLegalModal(
                                    'Kullanım Koşulları',
                                    'UstamBurada, hizmet almak isteyen müşteriler ile onaylı ustaları buluşturan güvenli pazaryeri platformudur. Ödemeler iş tamamlanana kadar provizyon güvencesi altında tutulur.',
                                  ),
                          ),
                          const TextSpan(text: ', '),
                          TextSpan(
                            text: 'Aydınlatma Metni',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _showLegalModal(
                                    'KVKK Aydınlatma Metni',
                                    '6698 sayılı Kişisel Verilerin Korunması Kanunu kapsamında telefon numaranız ve konum verileriniz yalnızca hizmet eşleştirmesi amacıyla şifrelenerek işlenmektedir.',
                                  ),
                          ),
                          const TextSpan(text: ' ve '),
                          TextSpan(
                            text: 'Gizlilik Politikası',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _showLegalModal(
                                    'Gizlilik Politikası',
                                    'Verileriniz 256-bit SSL sertifikası ile korunur ve açık rızanız olmadan üçüncü taraflarla paylaşılmaz.',
                                  ),
                          ),
                          const TextSpan(text: '\'nı kabul etmiş olursunuz.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 14,
                          color: Color(0xFF059669),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '256-bit SSL & KVKK Korumalı Altyapı',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleSegmentTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _RoleSegmentTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? activeColor : const Color(0xFF64748B),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureBenefitCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String badgeText;
  final Color badgeColor;
  final String description;

  const _FeatureBenefitCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.badgeText,
    required this.badgeColor,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 262,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      badgeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 4 Renkli Google 'G' Amblemi
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double strokeWidth = w * 0.22;
    final Rect rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      w - strokeWidth,
      h - strokeWidth,
    );

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Kırmızı (Üst sol -> Üst sağ)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.5, 1.8, false, paint);

    // Sarı (Sol alt)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.5, 1.3, false, paint);

    // Yeşil (Alt)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.7, 1.8, false, paint);

    // Mavi (Sağ alt + yatay çizgi)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.05, 0.85, false, paint);

    final Paint barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(
      Offset(w * 0.52, h * 0.5),
      Offset(w * 0.94, h * 0.5),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
