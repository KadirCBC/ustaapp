import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/auth/models/user_role.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isUsta = authState.role == UserRole.usta;

    return Scaffold(
      backgroundColor: isUsta ? AppTheme.ustaDarkBackground : AppTheme.customerBackground,
      appBar: AppBar(
        title: const Text('Profilim'),
        backgroundColor: isUsta ? AppTheme.ustaDarkBackground : Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 44,
              backgroundColor: isUsta ? AppTheme.ustaPrimary : AppTheme.customerPrimary,
              child: const Icon(Icons.person_rounded, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              authState.user?.phone ?? 'Kullanıcı',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isUsta ? AppTheme.ustaTextLight : AppTheme.customerTextDark,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: (isUsta ? AppTheme.ustaPrimary : AppTheme.customerPrimary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Rol: ${authState.role?.displayName ?? 'Belirlenmedi'}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isUsta ? AppTheme.ustaPrimary : AppTheme.customerPrimary,
                ),
              ),
            ),
            const SizedBox(height: 36),

            // Çıkış Yap Butonu
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(supabaseServiceProvider).signOut();
                if (context.mounted) {
                  context.go('/auth');
                }
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Oturumu Kapat'),
            ),
          ],
        ),
      ),
    );
  }
}
