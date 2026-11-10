import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/core/theme/app_theme.dart';

class CustomerMapScreen extends ConsumerWidget {
  const CustomerMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppTheme.customerBackground,
      appBar: AppBar(
        title: const Text('UstamBurada - Usta Çağır'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded),
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(supabaseServiceProvider).signOut();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Harita Alanı Temsili (Placeholder)
          Container(
            color: const Color(0xFFE2E8F0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.map_rounded,
                    size: 72,
                    color: AppTheme.customerPrimary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Harita Görünümü (Müşteri Modu)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.customerTextDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Giriş Yapıldı: ${authState.user?.phone ?? 'Müşteri'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.customerTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Üst Kategori Seçim Butonları
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _buildCategoryPill('Elektrik', Icons.bolt_rounded, true),
                const SizedBox(width: 8),
                _buildCategoryPill('Çilingir', Icons.key_rounded, false),
                const SizedBox(width: 8),
                _buildCategoryPill('Tesisat', Icons.plumbing_rounded, false),
              ],
            ),
          ),

          // Alt Bilgi Kartı / Usta Çağır Butonu
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on_rounded, color: AppTheme.customerSecondary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mevcut Konumunuz',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.customerTextMuted,
                                ),
                              ),
                              Text(
                                'Kadıköy, İstanbul',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.customerTextDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('En yakın ustalar aranıyor...')),
                        );
                      },
                      child: const Text('En Yakın Ustayı Çağır'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(String label, IconData icon, bool isSelected) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.customerPrimary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppTheme.customerTextDark,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.customerTextDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
