import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/core/utils/phone_formatter.dart';
import 'package:ustaapp/features/auth/controllers/auth_controller.dart';
import 'package:ustaapp/features/auth/models/user_role.dart';

class PhoneInputStep extends ConsumerStatefulWidget {
  const PhoneInputStep({super.key});

  @override
  ConsumerState<PhoneInputStep> createState() => _PhoneInputStepState();
}

class _PhoneInputStepState extends ConsumerState<PhoneInputStep> {
  late final TextEditingController _phoneController;
  final _maskFormatter = PhoneFormatter.trPhoneMask;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    final currentPhone = ref.read(phoneAuthControllerProvider).formattedPhone;
    _phoneController = TextEditingController(text: currentPhone);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);
    final controller = ref.read(phoneAuthControllerProvider.notifier);

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // ===================================================================
          // 1. ÜST HERO ALANI (Modern Gradient & Kurumsal Kimlik)
          // ===================================================================
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F172A), // Slate 900
                  Color(0xFF1E3A8A), // Deep Navy
                  Color(0xFF2563EB), // Vibrant Blue
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  children: [
                    // Üst Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFFBBF24)),
                          SizedBox(width: 6),
                          Text(
                            'TÜRKİYE\'NİN USTA PLATFORMU',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Logo & İkon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.handyman_rounded,
                          size: 34,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Uygulama Başlığı
                    const Text(
                      'UstamBurada',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Slogan
                    Text(
                      'Güvenilir, onaylı ustalar 15 dakikada kapınızda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ===================================================================
          // 2. GİRİŞ FORMU & KART ALANI
          // ===================================================================
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Form Kartı
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Giriş Yap veya Kayıt Ol',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Devam etmek için cep telefonu numaranızı girin.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Telefon Girişi Label
                        const Text(
                          'CEP TELEFONU NUMARASI',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Telefon Input Alanı
                        Focus(
                          onFocusChange: (focused) => setState(() => _isFocused = focused),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: state.errorMessage != null
                                    ? const Color(0xFFEF4444)
                                    : (_isFocused ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                                width: _isFocused ? 2 : 1.5,
                              ),
                              boxShadow: _isFocused
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            child: Row(
                              children: [
                                // Ülke Bayrak Rozeti
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('🇹🇷', style: TextStyle(fontSize: 18)),
                                      SizedBox(width: 6),
                                      Text(
                                        AppConstants.defaultCountryCode,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
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
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                      color: Color(0xFF0F172A),
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: '5XX XXX XX XX',
                                      hintStyle: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.6,
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

                                // Temizleme Butonu
                                if (_phoneController.text.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      _phoneController.clear();
                                      controller.setPhone('');
                                      setState(() {});
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: Icon(
                                        Icons.cancel_rounded,
                                        color: Color(0xFF94A3B8),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Hata Mesajı Rozeti
                        if (state.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state.errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFB91C1C),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Doğrulama Kodu Gönder Butonu (Gradient)
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
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
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Doğrulama Kodu Gönder',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ===========================================================
                  // 3. GÜVEN & AVANTAJ ROZETLERİ (Sosyal Kanıt)
                  // ===========================================================
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _TrustBadge(
                          icon: Icons.verified_user_rounded,
                          color: Color(0xFF16A34A),
                          title: 'Onaylı Usta',
                          subtitle: 'Sabıka & Kimlik',
                        ),
                        _BadgeDivider(),
                        _TrustBadge(
                          icon: Icons.electric_bolt_rounded,
                          color: Color(0xFFEA580C),
                          title: '15 Dk Varış',
                          subtitle: 'En Yakın Usta',
                        ),
                        _BadgeDivider(),
                        _TrustBadge(
                          icon: Icons.shield_rounded,
                          color: Color(0xFF2563EB),
                          title: 'Güvenli Ödeme',
                          subtitle: 'Provizyonlu',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ===========================================================
                  // 4. HIZLI TEST / DEMO MODU (Geliştirici & Önizleme İçin)
                  // ===========================================================
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.touch_app_rounded, size: 16, color: Color(0xFF475569)),
                            SizedBox(width: 6),
                            Text(
                              'Hızlı Test & Keşfet (Demo Modu)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            // Müşteri Girişi
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  controller.directDemoLogin(
                                    UserRole.musteri,
                                    fullName: 'Ahmet Demir (Müşteri)',
                                  );
                                  context.go('/customer/map');
                                },
                                icon: const Icon(Icons.person_rounded, size: 18, color: Color(0xFF1E3A8A)),
                                label: const Text(
                                  'Müşteri Modu',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFF93C5FD)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  minimumSize: Size.zero,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Usta Girişi
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  controller.directDemoLogin(
                                    UserRole.usta,
                                    fullName: 'Hasan Usta (Elektrikçi)',
                                  );
                                  context.go('/usta/orders');
                                },
                                icon: const Icon(Icons.build_rounded, size: 18, color: Color(0xFFEA580C)),
                                label: const Text(
                                  'Usta Modu',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFEA580C),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFFFDBA74)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  minimumSize: Size.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // KVKK & Koşullar
                  const Text(
                    'Devam ederek Kullanıcı Sözleşmesi ve KVKK Aydınlatma Metni\'ni kabul etmiş sayılırsınız.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF94A3B8),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _TrustBadge({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 9.5,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _BadgeDivider extends StatelessWidget {
  const _BadgeDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: const Color(0xFFE2E8F0),
    );
  }
}
