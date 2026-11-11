import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ustaapp/core/theme/app_theme.dart';

class CategoryItem {
  final String key;
  final String label;
  final IconData icon;

  const CategoryItem({
    required this.key,
    required this.label,
    required this.icon,
  });
}

/// Haritanın üzerine binen Glassmorphism üst navigasyon:
/// - Adres / Semt çubuğu + 'Değiştir' oku, sağda bildirim & profil butonları
/// - Yatay kaydırılabilir CategoryFilterBar
class FloatingTopNav extends StatelessWidget {
  final String addressLabel;
  final String selectedCategory;
  final VoidCallback onChangeAddressTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileTap;
  final ValueChanged<String> onCategorySelected;

  const FloatingTopNav({
    super.key,
    required this.addressLabel,
    required this.selectedCategory,
    required this.onChangeAddressTap,
    required this.onNotificationTap,
    required this.onProfileTap,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. GLASSMORPHISM ADRES & AKSİYON ÇUBUĞU
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Sol: Konum Pin + Semt/Adres + Değiştir oku
                    Expanded(
                      child: InkWell(
                        onTap: onChangeAddressTap,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppTheme.customerPrimary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  size: 18,
                                  color: AppTheme.customerPrimary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Hizmet Konumu',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.customerTextMuted,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            addressLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.customerTextDark,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Değiştir',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.customerPrimary,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 16,
                                          color: AppTheme.customerPrimary,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Sağ: Bildirim & Profil İkonları
                    _GlassIconButton(
                      icon: Icons.notifications_none_rounded,
                      showDot: true,
                      tooltip: 'Bildirimler',
                      onTap: onNotificationTap,
                    ),
                    const SizedBox(width: 8),
                    _GlassIconButton(
                      icon: Icons.person_outline_rounded,
                      tooltip: 'Profil',
                      onTap: onProfileTap,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // 2. YATAY KAYDIRILABİLİR KATEGORİ FİLTRE BARI
        CategoryFilterBar(
          selectedCategory: selectedCategory,
          onCategorySelected: onCategorySelected,
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final bool showDot;
  final String tooltip;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    this.showDot = false,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 20, color: AppTheme.customerTextDark),
              if (showDot)
                Positioned(
                  top: 8,
                  right: 9,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.ustaPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yatay kaydırılabilir, seçildiğinde koyu lacivert arka planlı kategori hapları
class CategoryFilterBar extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const CategoryFilterBar({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  static const List<CategoryItem> _categories = [
    CategoryItem(key: 'elektrik', label: 'Elektrik', icon: Icons.bolt_rounded),
    CategoryItem(key: 'cilingir', label: 'Çilingir', icon: Icons.vpn_key_rounded),
    CategoryItem(key: 'tesisat', label: 'Tesisat', icon: Icons.build_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _categories.map((cat) {
          final isSelected = selectedCategory == cat.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onCategorySelected(cat.key),
                borderRadius: BorderRadius.circular(22),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.customerPrimary
                        : Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.customerPrimary
                          : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? AppTheme.customerPrimary.withValues(alpha: 0.28)
                            : Colors.black12,
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat.icon,
                        size: 16,
                        color: isSelected ? Colors.amber.shade300 : AppTheme.customerPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AppTheme.customerTextDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
