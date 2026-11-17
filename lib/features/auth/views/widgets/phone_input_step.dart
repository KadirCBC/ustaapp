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
                  // 1. MARKA & LOGO BAŞLIĞI
                  // ===============================================================
                  Center(
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/app_logo.png',
                          height: 48,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'En Yakın Usta Kapında',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ===============================================================
                  // 2. PROFESYONEL 3-SEKMELİ MENÜ (Giriş Yap | Müşteri Kaydı | Usta Kaydı)
                  // ===============================================================
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        // 1. Giriş Yap
                        Expanded(
                          child: _TabButton(
                            label: 'Giriş Yap',
                            icon: Icons.login_rounded,
                            isSelected: _currentTab == AuthScreenTab.login,
                            activeColor: const Color(0xFF0F172A),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _currentTab = AuthScreenTab.login);
                            },
                          ),
                        ),
                        // 2. Müşteri Kaydı
                        Expanded(
                          child: _TabButton(
                            label: 'Müşteri Kaydı',
                            icon: Icons.person_add_alt_1_rounded,
                            isSelected: _currentTab == AuthScreenTab.customerRegister,
                            activeColor: const Color(0xFF1E3A8A),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              controller.selectRole(UserRole.musteri);
                              setState(() => _currentTab = AuthScreenTab.customerRegister);
                            },
                          ),
                        ),
                        // 3. Usta Kaydı
                        Expanded(
                          child: _TabButton(
                            label: 'Usta Kaydı',
                            icon: Icons.handyman_rounded,
                            isSelected: _currentTab == AuthScreenTab.ustaRegister,
                            activeColor: const Color(0xFFEA580C),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              controller.selectRole(UserRole.usta);
                              setState(() => _currentTab = AuthScreenTab.ustaRegister);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

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
                    // GİRİŞ YAP ALANI
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

                          const SizedBox(height: 20),

                          // Henüz hesabınız yok mu?
                          const Row(
                            children: [
                              Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'Hesabınız yok mu?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Müşteri / Usta Kaydı Hızlı Geçiş Butonları
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    controller.selectRole(UserRole.musteri);
                                    setState(() => _currentTab = AuthScreenTab.customerRegister);
                                  },
                                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Color(0xFF1E3A8A)),
                                  label: const Text(
                                    'Müşteri Kaydı',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                                    backgroundColor: const Color(0xFFEFF6FF),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    controller.selectRole(UserRole.usta);
                                    setState(() => _currentTab = AuthScreenTab.ustaRegister);
                                  },
                                  icon: const Icon(Icons.handyman_rounded, size: 16, color: Color(0xFFEA580C)),
                                  label: const Text(
                                    'Usta Kaydı',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFEA580C),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFFED7AA)),
                                    backgroundColor: const Color(0xFFFFF7ED),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
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

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _TabButton({
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
