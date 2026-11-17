import 'dart:async';
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

class _PhoneInputStepState extends ConsumerState<PhoneInputStep>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _phoneController;
  late final AnimationController _animController;
  late final Animation<double> _floatAnim;
  Timer? _categoryCycleTimer;
  int _currentCategoryIndex = 0;

  final _maskFormatter = PhoneFormatter.trPhoneMask;
  bool _isFocused = false;
  AuthScreenTab _currentTab = AuthScreenTab.login;

  static const List<Map<String, dynamic>> _serviceCategories = [
    {
      'title': 'Elektrik & Aydınlatma',
      'icon': '⚡',
      'color': Color(0xFFD97706),
      'bgColor': Color(0xFFFEF3C7),
    },
    {
      'title': 'Sıhhi Tesisat & Su',
      'icon': '🔧',
      'color': Color(0xFF2563EB),
      'bgColor': Color(0xFFDBEAFE),
    },
    {
      'title': 'Çilingir & Kilit',
      'icon': '🔑',
      'color': Color(0xFFB45309),
      'bgColor': Color(0xFFFDE68A),
    },
    {
      'title': 'Kombi & Isıtma',
      'icon': '❄️',
      'color': Color(0xFF0284C7),
      'bgColor': Color(0xFFE0F2FE),
    },
    {
      'title': 'Boya & Badana',
      'icon': '🎨',
      'color': Color(0xFF7C3AED),
      'bgColor': Color(0xFFEDE9FE),
    },
    {
      'title': 'Mobilya & Marangoz',
      'icon': '🪑',
      'color': Color(0xFFC2410C),
      'bgColor': Color(0xFFFFEDD5),
    },
  ];

  @override
  void initState() {
    super.initState();
    final currentPhone = ref.read(phoneAuthControllerProvider).formattedPhone;
    _phoneController = TextEditingController(text: currentPhone);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutSine),
    );

    _categoryCycleTimer = Timer.periodic(const Duration(milliseconds: 2300), (_) {
      if (mounted) {
        setState(() {
          _currentCategoryIndex = (_currentCategoryIndex + 1) % _serviceCategories.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _categoryCycleTimer?.cancel();
    _animController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);
    final controller = ref.read(phoneAuthControllerProvider.notifier);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Web için sağ üstte hafif yönetici linki
                  if (kIsWeb)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => context.go('/admin'),
                        icon: const Icon(Icons.admin_panel_settings_outlined, size: 16, color: Color(0xFF94A3B8)),
                        label: const Text(
                          'Yönetici Paneli',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // ===============================================================
                  // 1. MARKA & LOGO BAŞLIĞI + DİNAMİK DEĞİŞEN KATEGORİ SLOGANI
                  // ===============================================================
                  Center(
                    child: Column(
                      children: [
                        // 1. Logo (Zarif dikey süzülme ve yumuşak gölge efekti)
                        AnimatedBuilder(
                          animation: _floatAnim,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(0, _floatAnim.value),
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              height: 52,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // 2. Ana Başlık & Slogan
                        const Text(
                          'En Yakın Usta Kapında',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 7),

                        // 3. Sırayla Değişen Canlı Hizmet Kategorisi ve Varış Rozeti
                        SizedBox(
                          height: 32,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              final offsetAnim = Tween<Offset>(
                                begin: const Offset(0.0, 0.45),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(position: offsetAnim, child: child),
                              );
                            },
                            child: Row(
                              key: ValueKey<int>(_currentCategoryIndex),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _serviceCategories[_currentCategoryIndex]['bgColor'] as Color,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: (_serviceCategories[_currentCategoryIndex]['color'] as Color).withValues(alpha: 0.35),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _serviceCategories[_currentCategoryIndex]['icon'] as String,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _serviceCategories[_currentCategoryIndex]['title'] as String,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: _serviceCategories[_currentCategoryIndex]['color'] as Color,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.timer_outlined, size: 12.5, color: Color(0xFF059669)),
                                      SizedBox(width: 4),
                                      Text(
                                        '15 Dk Varış',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

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
                    const SizedBox(height: 10),
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
                    // MÜŞTERİ KAYDI VE USTA KAYDI (ALT ALTA BÜYÜK BELİRGİN BUTONLAR)
                    // =============================================================
                    _BigRegistrationButton(
                      title: 'Müşteri Kaydı',
                      subtitle: 'Hemen usta çağırın ve güvenle hizmet alın',
                      icon: Icons.person_add_alt_1_rounded,
                      iconBgColor: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF1E3A8A),
                      borderColor: const Color(0xFFBFDBFE),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        controller.selectRole(UserRole.musteri);
                        setState(() => _currentTab = AuthScreenTab.customerRegister);
                      },
                    ),

                    const SizedBox(height: 12),

                    _BigRegistrationButton(
                      title: 'Usta Kaydı',
                      subtitle: 'Usta olarak başvurun, yeni işlerle kazancınızı katlayın',
                      icon: Icons.handyman_rounded,
                      iconBgColor: const Color(0xFFFFF7ED),
                      iconColor: const Color(0xFFEA580C),
                      borderColor: const Color(0xFFFED7AA),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        controller.selectRole(UserRole.usta);
                        setState(() => _currentTab = AuthScreenTab.ustaRegister);
                      },
                    ),

                    const SizedBox(height: 22),

                    // VEYA GİRİŞ YAPIN AYIRICISI
                    const Row(
                      children: [
                        Expanded(child: Divider(color: Color(0xFFCBD5E1))),
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
                        Expanded(child: Divider(color: Color(0xFFCBD5E1))),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // =============================================================
                    // GİRİŞ YAP KARTI
                    // =============================================================
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
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
                                      'Kayıtlı telefon numaranız ile hızlıca giriş yapın',
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
                                  Icons.lock_person_rounded,
                                  size: 22,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Telefon Label
                          const Text(
                            'Cep Telefonu Numarası',
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
                                  // Türkiye Bayrağı & Ülke Kodu
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
                                        SizedBox(width: 6),
                                        Text(
                                          AppConstants.defaultCountryCode,
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
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

                          const Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 15, color: Color(0xFF059669)),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Şifresiz, tek kullanımlık SMS onay kodu ile güvenli giriş',
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

                          // Giriş Butonu
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: state.isLoading ? null : () => controller.sendOtp(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: const Color(0xFF0F172A),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
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

                  // Alt Bilgi / Güvenlik
                  const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                        SizedBox(width: 6),
                        Text(
                          '256-bit SSL şifreleme ve KVKK güvencesiyle korunmaktadır.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Büyük, belirgin ve prestijli kayıt butonu kartı
class _BigRegistrationButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _BigRegistrationButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                // İkon Kutusu
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 26,
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
                          fontSize: 16.5,
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
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Sağ Ok İkonu
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Color(0xFF64748B),
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
