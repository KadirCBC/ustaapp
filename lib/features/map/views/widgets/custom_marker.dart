import 'package:flutter/material.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/map/models/isletme_model.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';

/// Müşterinin haritadaki mevcut konum pini (yumuşak radar halkalı mavi nokta)
class CustomerLocationMarker extends StatelessWidget {
  final VoidCallback? onTap;

  const CustomerLocationMarker({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.customerSecondary.withValues(alpha: 0.20),
              border: Border.all(
                color: AppTheme.customerSecondary.withValues(alpha: 0.40),
                width: 1.5,
              ),
            ),
          ),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.customerPrimary,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Profesyonel Usta Harita Pini (Zümrüt Yeşili Usta Rozeti)
class CustomMarker extends StatelessWidget {
  final NearbyUstaModel usta;
  final bool isSelected;
  final VoidCallback onTap;

  const CustomMarker({
    super.key,
    required this.usta,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isSelected ? const Color(0xFF0F172A) : Colors.white;
    final Color textColor = isSelected ? Colors.white : const Color(0xFF0F172A);
    final Color borderColor =
        isSelected ? const Color(0xFFF97316) : const Color(0xFFE2E8F0);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isSelected ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Bilgi Rozeti (Usta Adı, Puan ve Fiyat)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                  width: isSelected ? 2.0 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? const Color(0xFFF97316).withValues(alpha: 0.35)
                        : Colors.black.withValues(alpha: 0.16),
                    blurRadius: isSelected ? 12 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Text(
                          usta.shortDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '★ ${usta.puan.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${usta.formattedPrice} Taban',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFF047857),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Bağlantı Üçgeni
            CustomPaint(
              size: const Size(10, 5),
              painter: _MarkerTrianglePainter(
                color: bgColor,
                borderColor: borderColor,
              ),
            ),
            // 3D Usta Harita Pini
            Image.asset(
              'assets/images/pin_usta.png',
              width: 46,
              height: 46,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}

/// Profesyonel İşletme / Tedarikçi Harita Pini (Altın/Amber Rozeti)
class CustomIsletmeMarker extends StatelessWidget {
  final IsletmeModel isletme;
  final bool isSelected;
  final VoidCallback onTap;

  const CustomIsletmeMarker({
    super.key,
    required this.isletme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSponsored = isletme.isSponsored;
    final Color bgColor = isSelected ? const Color(0xFF0F172A) : Colors.white;
    final Color textColor = isSelected ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor =
        isSelected ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color borderColor = isSelected
        ? const Color(0xFFF59E0B)
        : (isSponsored ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1));

    final String subLabel = isSponsored
        ? 'Öne Çıkan Mağaza'
        : (isletme.kategori.isNotEmpty
            ? isletme.kategori
            : 'Tedarikçi / Mağaza');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isSelected ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Bilgi Rozeti
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                  width: isSelected ? 2.0 : (isSponsored ? 1.6 : 1.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSponsored
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                        : Colors.black.withValues(alpha: 0.16),
                    blurRadius: isSelected ? 12 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      isletme.ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: isSponsored
                          ? const Color(0xFFD97706)
                          : (isSelected
                              ? const Color(0xFFFDE68A)
                              : subTextColor),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
            // Bağlantı Üçgeni
            CustomPaint(
              size: const Size(10, 5),
              painter: _MarkerTrianglePainter(
                color: bgColor,
                borderColor: borderColor,
              ),
            ),
            // 3D İşletme Harita Pini
            Image.asset(
              'assets/images/pin_isletme.png',
              width: 46,
              height: 46,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkerTrianglePainter extends CustomPainter {
  final Color color;
  final Color? borderColor;

  const _MarkerTrianglePainter({required this.color, this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    if (borderColor != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = borderColor!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarkerTrianglePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderColor != borderColor;
}

