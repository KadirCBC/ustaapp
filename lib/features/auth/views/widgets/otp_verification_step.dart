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

  @override
  void initState() {
    super.initState();
    _otpController = TextEditingController();
  }

  @override
  void dispose() {
    _otpController.dispose();
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
          const SizedBox(height: 12),
          // Geri dön ve numara düzenle butonu
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: state.isLoading ? null : () => controller.backToPhoneInput(),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppTheme.customerPrimary),
                    SizedBox(width: 6),
                    Text(
                      'Numarayı Değiştir',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.customerPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'SMS Kodunu Girin',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.customerTextDark,
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: AppTheme.customerTextMuted, height: 1.5),
              children: [
                const TextSpan(text: 'Doğrulama kodu şu numaraya gönderildi:\n'),
                TextSpan(
                  text: '${AppConstants.defaultCountryCode} ${state.formattedPhone}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.customerTextDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          // OTP Giriş Alanı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: state.errorMessage != null ? Colors.redAccent : const Color(0xFFCBD5E1),
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
            child: TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: AppConstants.otpLength,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 14.0,
                color: AppTheme.customerPrimary,
              ),
              decoration: const InputDecoration(
                counterText: '',
                hintText: '••••••',
                hintStyle: TextStyle(
                  letterSpacing: 14.0,
                  color: Color(0xFFCBD5E1),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onChanged: (val) {
                controller.setOtp(val);
                if (val.trim().length == AppConstants.otpLength) {
                  controller.verifyOtp();
                }
              },
            ),
          ),

          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 28),

          // Doğrula Butonu
          ElevatedButton(
            onPressed: (state.isLoading || state.otpCode.trim().length != AppConstants.otpLength)
                ? null
                : () => controller.verifyOtp(),
            child: state.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Doğrula ve Giriş Yap'),
          ),

          const SizedBox(height: 20),

          // Geri Sayım / Tekrar Gönder
          Center(
            child: state.canResendOtp
                ? TextButton(
                    onPressed: state.isLoading ? null : () => controller.resendOtp(),
                    child: const Text(
                      'Tekrar Kod Gönder',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.customerSecondary,
                      ),
                    ),
                  )
                : Text(
                    'Yeni kod talep edebilirsiniz: (${state.resendCountdown} sn)',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
