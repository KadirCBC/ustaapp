import 'package:flutter/material.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';

/// Müşterinin haritadaki mevcut konum pini (yumuşak radar halkalı mavi nokta)
class CustomerLocationMarker extends StatelessWidget {
  const CustomerLocationMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.customerSecondary.withValues(alpha: 0.18),
            border: Border.all(
              color: AppTheme.customerSecondary.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
        ),
        Container(
          width: 20,
          height: 20,
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
    );
  }
}

/// Profesyonel Usta Harita Pini (Üst: '★ 4.9 Ahmet Y.', Alt: koyu hap içinde fiyat + üçgen ok)
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

  static const Color _accentOrange = AppTheme.ustaPrimary; // 0xFFEA580C
  static const Color _darkNavy = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    final pointerColor = isSelected ? _accentOrange : _darkNavy;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
              decoration: BoxDecoration(
                color: isSelected ? _accentOrange : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                  width: isSelected ? 1.8 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? _accentOrange.withValues(alpha: 0.38)
                        : Colors.black.withValues(alpha: 0.14),
                    blurRadius: isSelected ? 14 : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Üst Kısım: Yıldız puanı & Usta kısa adı
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 13,
                        color: isSelected ? Colors.amber.shade200 : Colors.amber.shade600,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        usta.puan.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : _darkNavy,
                        ),
                      ),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 78),
                        child: Text(
                          usta.shortDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : _darkNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Alt Kısım: Koyu renkli hap etiket içinde nihai fiyat
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : _darkNavy,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      usta.formattedPrice,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? _accentOrange : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Haritaya işaret eden minik üçgen ok ucu
            CustomPaint(
              size: const Size(12, 6),
              painter: _MarkerTrianglePainter(color: pointerColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkerTrianglePainter extends CustomPainter {
  final Color color;

  const _MarkerTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MarkerTrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}
