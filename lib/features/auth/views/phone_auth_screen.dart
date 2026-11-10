import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/auth/controllers/auth_controller.dart';
import 'package:ustaapp/features/auth/models/user_role.dart';
import 'package:ustaapp/features/auth/views/widgets/otp_verification_step.dart';
import 'package:ustaapp/features/auth/views/widgets/phone_input_step.dart';
import 'package:ustaapp/features/auth/views/widgets/role_selection_step.dart';

class PhoneAuthScreen extends ConsumerWidget {
  const PhoneAuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(phoneAuthControllerProvider);

    // Başarıyla tamamlandıysa yönlendir
    ref.listen<PhoneAuthState>(phoneAuthControllerProvider, (previous, next) {
      if (next.step == AuthStep.completed) {
        if (next.selectedRole == UserRole.usta) {
          context.go('/usta/orders');
        } else {
          context.go('/customer/map');
        }
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.customerBackground,
      appBar: AppBar(
        title: const Text('UstamBurada'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: _buildCurrentStep(state.step),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(AuthStep step) {
    switch (step) {
      case AuthStep.phoneInput:
        return const PhoneInputStep(key: ValueKey('PhoneInputStep'));
      case AuthStep.otpVerification:
        return const OtpVerificationStep(key: ValueKey('OtpVerificationStep'));
      case AuthStep.roleSelection:
        return const RoleSelectionStep(key: ValueKey('RoleSelectionStep'));
      case AuthStep.completed:
        return const Center(
          child: CircularProgressIndicator(),
        );
    }
  }
}
