import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaapp/core/constants/app_constants.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/core/utils/phone_formatter.dart';
import 'package:ustaapp/features/auth/controllers/auth_controller.dart';

class PhoneInputStep extends ConsumerStatefulWidget {
  const PhoneInputStep({super.key});

  @override
  ConsumerState<PhoneInputStep> createState() => _PhoneInputStepState();
}

class _PhoneInputStepState extends ConsumerState<PhoneInputStep> {
  late final TextEditingController _phoneController;
  final _maskFormatter = PhoneFormatter.trPhoneMask;

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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          // Logo / İkon
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.customerPrimary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.build_circle_rounded,
                size: 48,
                color: AppTheme.customerPrimary,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'UstamBurada\'ya Hoş Geldiniz',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.customerTextDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Giriş yapmak veya kayıt olmak için lütfen cep telefonu numaranızı girin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.customerTextMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 36),

          // Telefon Girişi Kartı
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: state.errorMessage != null ? Colors.redAccent : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                // Ülke Kodu ve Bayrak
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
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
                          fontWeight: FontWeight.w600,
                          color: AppTheme.customerTextDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Numara Girişi
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [_maskFormatter],
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                      color: AppTheme.customerTextDark,
                    ),
                    decoration: const InputDecoration(
                      hintText: '5XX XXX XX XX',
                      hintStyle: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.normal,
                        letterSpacing: 0.5,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (val) => controller.setPhone(val),
                    onSubmitted: (_) {
                      if (!state.isLoading) controller.sendOtp();
                    },
                  ),
                ),
              ],
            ),
          ),

          if (state.errorMessage != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 28),

          // Doğrulama Kodu Gönder Butonu
          ElevatedButton(
            onPressed: state.isLoading ? null : () => controller.sendOtp(),
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
                      Text('Doğrulama Kodu Gönder'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Devam ederek Kullanıcı Sözleşmesi ve KVKK Aydınlatma Metni\'ni kabul etmiş sayılırsınız.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
