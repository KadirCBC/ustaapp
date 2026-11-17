import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/core/utils/phone_formatter.dart';
import 'package:ustaapp/features/auth/controllers/auth_controller.dart';
import 'package:ustaapp/features/auth/models/user_role.dart';
import 'package:ustaapp/features/auth/views/widgets/customer_register_form.dart';
import 'package:ustaapp/features/auth/views/widgets/usta_register_form.dart';

enum AuthScreenTab {
  login,
  customerRegister,
  ustaRegister,
}

class PhoneInputStep extends ConsumerStatefulWidget {
  const PhoneInputStep({super.key});

  @override
  ConsumerState<PhoneInputStep> createState() => _PhoneInputStepState();
}

class _PhoneInputStepState extends ConsumerState<PhoneInputStep> {
  late final TextEditingController _phoneController;

  final _maskFormatter = PhoneFormatter.trPhoneMask;
  bool _isFocused = false;
  AuthScreenTab _currentTab = AuthScreenTab.login;

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

  void _showHelpModal() {
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
            const Row(
              children: [
                Icon(Icons.help_outline_rounded, color: Color(0xFFEA580C), size: 22),
                SizedBox(width: 8),
                Text(
                  'Nasıl Giriş Yapılır?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '1. 10 haneli cep telefonu numaranızı girin.\n'
              '2. "Giriş Yap" butonuna basın.\n'
              '3. Telefonunuza SMS ile gelen doğrulama kodunu yazarak şifresiz ve güvenli şekilde giriş yapın.\n\n'
              'Henüz kaydınız yoksa üstteki "Müşteri Kaydı" veya "Usta Kaydı" butonlarına tıklayarak hemen hesap oluşturabilirsiniz.',
              style: TextStyle(
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
                child: const Text('Anladım', style: TextStyle(fontWeight: FontWeight.bold)),
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

    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFF),
      body: Stack(
        children: [
          // Arka plan eğrileri (1. Görseldeki yumuşak turuncu dalga dokusu)
          Positioned.fill(
            child: CustomPaint(
              painter: _BackgroundWavesPainter(),
            ),
          ),

          SafeArea(
            top: !kIsWeb,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ===============================================================
                      // 1. ÜST BAR (En Tepe Noktaya Taşındı)
                      // ===============================================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (kIsWeb)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => context.go('/admin'),
                                icon: const Icon(Icons.admin_panel_settings_outlined, size: 18, color: Color(0xFF94A3B8)),
                                tooltip: 'Yönetici Paneli',
                              ),
                            ),
                          InkWell(
                            onTap: _showHelpModal,
                            borderRadius: BorderRadius.circular(10),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.headset_mic_outlined, size: 15, color: Color(0xFF64748B)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Nasıl Giriş Yapılır?',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(Icons.chevron_right_rounded, size: 15, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 2),

                      // ===============================================================
                      // 2. KAYIT MODUNDA İSE GERİ DÖNÜŞ BAŞLIĞI
                      // ===============================================================
                      if (_currentTab != AuthScreenTab.login) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(() => _currentTab = AuthScreenTab.login),
                            icon: const Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF0F172A)),
                            label: const Text(
                              '← Giriş Ekranına Dön',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // ===============================================================
                      // 3. SEÇİLİ SEKMENİN İÇERİĞİ
                      // ===============================================================
                      if (_currentTab == AuthScreenTab.customerRegister) ...[
                        CustomerRegisterForm(
                          onSwitchToLogin: () => setState(() => _currentTab = AuthScreenTab.login),
                          onSwitchToUsta: () => setState(() => _currentTab = AuthScreenTab.ustaRegister),
                        ),
                      ] else if (_currentTab == AuthScreenTab.ustaRegister) ...[
                        UstaRegisterForm(
                          onSwitchToLogin: () => setState(() => _currentTab = AuthScreenTab.login),
                          onSwitchToCustomer: () => setState(() => _currentTab = AuthScreenTab.customerRegister),
                        ),
                      ] else ...[
                        // =============================================================
                        // ORTALANMIŞ VE BÜYÜTÜLMÜŞ LOGO (Kırmızı Alandaki Boşluk Azaltıldı)
                        // =============================================================
                        Center(
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                        ),

                        const SizedBox(height: 2),

                        // =============================================================
                        // HERO ALANI (Mavi Alandaki Boşluk Azaltıldı & Hizalandı)
                        // =============================================================
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sol: Animasyonlu Başlık ve Açıklama
                            const Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Animasyonlu Başlık (Işık geçişi ve yumuşak nabız efekti)
                                  _AnimatedHeroTitle(),
                                  SizedBox(height: 6),
                                  Text(
                                    'Profesyonel ustalarla\nhızlı ve güvenli hizmet.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.35,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 6),

                            // Sağ: 3D Baret, Pin ve Plan Görseli (Büyütülmüş Hareketsiz Görsel)
                            Expanded(
                              flex: 6,
                              child: Transform.scale(
                                scale: 1.15,
                                alignment: Alignment.topRight,
                                child: Image.asset(
                                  'assets/images/hero_worker_hd.png',
                                  height: 160,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // =============================================================
                        // 1. GÖRSELDEKİ MÜŞTERİ KAYDI BUTONU
                        // =============================================================
                        _RegistrationCard(
                          title: 'Müşteri Kaydı',
                          subtitle: 'Hizmet almak için hemen üye olun!',
                          icon: Icons.people_alt_rounded,
                          iconBgColor: const Color(0xFFEFF6FF),
                          iconColor: const Color(0xFF1E3A8A),
                          hasBorder: false,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            controller.selectRole(UserRole.musteri);
                            setState(() => _currentTab = AuthScreenTab.customerRegister);
                          },
                        ),

                        const SizedBox(height: 12),

                        // =============================================================
                        // 1. GÖRSELDEKİ USTA KAYDI BUTONU (Turuncu Çerçeveli)
                        // =============================================================
                        _RegistrationCard(
                          title: 'Usta Kaydı',
                          subtitle: 'Usta olarak siz de hizmet verin,\nkazancınızı artırın!',
                          icon: Icons.handyman_rounded,
                          iconBgColor: const Color(0xFFFFF7ED),
                          iconColor: const Color(0xFFEA580C),
                          hasBorder: true,
                          borderColor: const Color(0xFFFED7AA),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            controller.selectRole(UserRole.usta);
                            setState(() => _currentTab = AuthScreenTab.ustaRegister);
                          },
                        ),

                        const SizedBox(height: 20),

                        // VEYA HESABINIZA GİRİŞ YAPIN AYIRICISI
                        const Row(
                          children: [
                            Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'VEYA HESABINIZA GİRİŞ YAPIN',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // =============================================================
                        // 1. GÖRSELDEKİ GİRİŞ YAP KARTI
                        // =============================================================
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Giriş Yap',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.4,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          'Hesabınıza giriş yaparak hizmetlere erişin',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.lock_rounded,
                                      size: 22,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Telefon Label
                              const Text(
                                'Cep Telefonu Numaranız',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Telefon Input Alanı
                              Focus(
                                onFocusChange: (focused) => setState(() => _isFocused = focused),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: _isFocused ? Colors.white : const Color(0xFFF8FAFC),
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
                                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  child: Row(
                                    children: [
                                      // Türkiye Bayrağı & Ülke Kodu Dropdown
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('🇹🇷', style: TextStyle(fontSize: 16)),
                                            SizedBox(width: 5),
                                            Text(
                                              AppConstants.defaultCountryCode,
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            SizedBox(width: 2),
                                            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
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
                                            letterSpacing: 1.1,
                                            color: Color(0xFF0F172A),
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: '5XX XXX XX XX',
                                            hintStyle: TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontWeight: FontWeight.w500,
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

                              // Güvenlik Bilgilendirmesi (1. Görseldeki yeşil ikonlu satır)
                              const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF059669)),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Güvenliğiniz için kayıtlı telefon numaranızı girin.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 18),

                              // Giriş Butonu (1. Görseldeki dolgun turuncu buton)
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: state.isLoading ? null : () => controller.sendOtp(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF59E0B),
                                    foregroundColor: const Color(0xFF0F172A),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: state.isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Giriş Yap',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(Icons.arrow_forward_rounded, size: 20),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Alt Bilgi (1. Görseldeki KVKK yazısı)
                      const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                            SizedBox(width: 6),
                            Text(
                              'Kişisel verileriniz KVKK kapsamında korunmaktadır.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
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

/// 1. Görseldeki Müşteri ve Usta Kaydı Buton Kartı
class _RegistrationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final bool hasBorder;
  final Color? borderColor;
  final VoidCallback onTap;

  const _RegistrationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    this.hasBorder = false,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: hasBorder
            ? Border.all(color: borderColor ?? const Color(0xFFFED7AA), width: 1.5)
            : Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: hasBorder
                ? const Color(0xFFEA580C).withValues(alpha: 0.08)
                : const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                // İkon Kutusu
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 14),

                // Başlık & Açıklama
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Sağ Chevron Butonu
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 1. Görseldeki yumuşak turuncu dalga dekorasyonları
class _BackgroundWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Üst sağ zarif turuncu dalga
    final paint1 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF97316), Color(0xFFFB923C)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(Rect.fromLTWH(size.width * 0.4, 0, size.width * 0.6, 260))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final path1 = Path();
    path1.moveTo(size.width, 40);
    path1.cubicTo(size.width * 0.88, 70, size.width * 0.72, 190, size.width, 240);
    canvas.drawPath(path1, paint1);

    // Alt sol kalın turuncu eğri
    final paint2 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFEA580C), Color(0xFFF97316)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Rect.fromLTWH(0, size.height - 120, size.width * 0.5, 120))
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height - 24);
    path2.cubicTo(size.width * 0.18, size.height - 12, size.width * 0.28, size.height, size.width * 0.38, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Canlı ve modern parıltı & yumuşak nabız animasyonuna sahip hero başlığı
class _AnimatedHeroTitle extends StatefulWidget {
  const _AnimatedHeroTitle();

  @override
  State<_AnimatedHeroTitle> createState() => _AnimatedHeroTitleState();
}

class _AnimatedHeroTitleState extends State<_AnimatedHeroTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.03)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.03, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        return Transform.scale(
          scale: _scaleAnimation.value,
          alignment: Alignment.centerLeft,
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment(-2.2 + progress * 4.4, -0.6),
                end: Alignment(-0.6 + progress * 4.4, 0.6),
                colors: const [
                  Color(0xFF0F172A), // Lacivert ana renk
                  Color(0xFFEA580C), // Canlı turuncu ışıltı
                  Color(0xFFF97316), // Parlak amber vurgu
                  Color(0xFF0F172A), // Lacivert ana renk
                ],
                stops: const [0.0, 0.45, 0.55, 1.0],
              ).createShader(bounds);
            },
            child: child,
          ),
        );
      },
      child: const Text(
        'En Yakın Usta\nKapında!',
        style: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w900,
          height: 1.15,
          letterSpacing: -0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}

