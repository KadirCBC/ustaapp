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
    const Color emeraldPrimary = Color(0xFF059669);
    const Color emeraldGradientDark = Color(0xFF047857);
    final Color bgColor = isSelected ? const Color(0xFF0F172A) : Colors.white;
    final Color textColor = isSelected ? Colors.white : const Color(0xFF0F172A);
    final Color borderColor =
        isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0);

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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: borderColor,
                  width: isSelected ? 2.2 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? emeraldPrimary.withValues(alpha: 0.35)
                        : Colors.black.withValues(alpha: 0.16),
                    blurRadius: isSelected ? 14 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sol Embiye
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF10B981), emeraldGradientDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.handyman_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sağ Metinler
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          usta.formattedPrice,
                          style: TextStyle(
                            fontSize: 10,
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
                ],
              ),
            ),
            CustomPaint(
              size: const Size(12, 6),
              painter: _MarkerTrianglePainter(
                color: bgColor,
                borderColor: borderColor,
              ),
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
    final Color amberPrimary =
        isSponsored ? const Color(0xFFD97706) : const Color(0xFFF59E0B);
    final Color amberGradientDark =
        isSponsored ? const Color(0xFFB45309) : const Color(0xFFD97706);
    final Color bgColor = isSelected ? const Color(0xFF0F172A) : Colors.white;
    final Color textColor = isSelected ? Colors.white : const Color(0xFF0F172A);
    final Color borderColor = isSelected
        ? const Color(0xFFF59E0B)
        : (isSponsored ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0));

    final String subLabel = isSponsored
        ? 'ÖNE ÇIKAN DÜKKAN'
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: borderColor,
                  width: isSelected ? 2.2 : (isSponsored ? 1.8 : 1.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSponsored
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.32)
                        : Colors.black.withValues(alpha: 0.16),
                    blurRadius: isSelected ? 14 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sol Embiye
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [amberPrimary, amberGradientDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(
                      isSponsored
                          ? Icons.stars_rounded
                          : Icons.storefront_rounded,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sağ Metinler
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF334155)
                              : (isSponsored
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          subLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? const Color(0xFFFDE68A)
                                : (isSponsored
                                    ? const Color(0xFFB45309)
                                    : const Color(0xFF64748B)),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            CustomPaint(
              size: const Size(12, 6),
              painter: _MarkerTrianglePainter(
                color: bgColor,
                borderColor: borderColor,
              ),
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

