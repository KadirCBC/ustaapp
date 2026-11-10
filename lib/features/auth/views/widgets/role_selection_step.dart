import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/auth/controllers/auth_controller.dart';
import 'package:ustaapp/features/auth/models/user_role.dart';

class RoleSelectionStep extends ConsumerStatefulWidget {
  const RoleSelectionStep({super.key});

  @override
  ConsumerState<RoleSelectionStep> createState() => _RoleSelectionStepState();
}

class _RoleSelectionStepState extends ConsumerState<RoleSelectionStep> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
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
          const Text(
            'Son Bir Adım!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.customerTextDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'UstamBurada\'yı nasıl kullanmak istediğinizi seçin ve profilinizi tamamlayın.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.customerTextMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),

          // Ad Soyad Girişi
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.customerTextDark,
            ),
            decoration: const InputDecoration(
              labelText: 'Adınız ve Soyadınız',
              hintText: 'Örn: Ahmet Yılmaz',
              prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.customerTextMuted),
            ),
            onChanged: (val) => controller.setFullName(val),
          ),
          const SizedBox(height: 24),

          const Text(
            'Uygulamadaki Rolünüz:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.customerTextDark,
            ),
          ),
          const SizedBox(height: 14),

          // 1. Müşteri Kartı
          _RoleCard(
            title: 'Usta Arıyorum (Müşteri)',
            description: 'Elektrik, tesisat, çilingir gibi acil tamirat ihtiyaçlarım için usta çağıracağım.',
            icon: Icons.home_repair_service_rounded,
            isSelected: state.selectedRole == UserRole.musteri,
            selectedColor: AppTheme.customerPrimary,
            onTap: () => controller.selectRole(UserRole.musteri),
          ),
          const SizedBox(height: 14),

          // 2. Usta Kartı
          _RoleCard(
            title: 'Ustayım, İş Almak İstiyorum (Usta)',
            description: 'Mesleğimi icra etmek, çevremdeki müşteri çağrılarını yanıtlamak ve kazanmak istiyorum.',
            icon: Icons.engineering_rounded,
            isSelected: state.selectedRole == UserRole.usta,
            selectedColor: AppTheme.ustaPrimary,
            onTap: () => controller.selectRole(UserRole.usta),
          ),

          if (state.errorMessage != null) ...[
            const SizedBox(height: 16),
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

          const SizedBox(height: 32),

          // Kaydı Tamamla Butonu
          ElevatedButton(
            onPressed: state.isLoading ? null : () => controller.completeRegistration(),
            style: ElevatedButton.styleFrom(
              backgroundColor: state.selectedRole == UserRole.usta
                  ? AppTheme.ustaPrimary
                  : AppTheme.customerPrimary,
            ),
            child: state.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Profilimi Oluştur ve Başla'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? selectedColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? selectedColor.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? selectedColor : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppTheme.customerTextMuted,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? selectedColor : AppTheme.customerTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.customerTextMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? selectedColor : const Color(0xFFCBD5E1),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
