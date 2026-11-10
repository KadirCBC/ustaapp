import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/map/controllers/map_controller.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';

class UstaDetailSheet extends ConsumerStatefulWidget {
  final NearbyUstaModel usta;

  const UstaDetailSheet({super.key, required this.usta});

  @override
  ConsumerState<UstaDetailSheet> createState() => _UstaDetailSheetState();
}

class _UstaDetailSheetState extends ConsumerState<UstaDetailSheet> {
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usta = widget.usta;
    final mapState = ref.watch(customerMapControllerProvider);
    final mapController = ref.read(customerMapControllerProvider.notifier);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sürükleme Tutamacı
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 1. Usta Profil Başlığı & Durumu
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppTheme.customerPrimary.withOpacity(0.08),
                      backgroundImage: usta.avatarUrl != null ? NetworkImage(usta.avatarUrl!) : null,
                      child: usta.avatarUrl == null
                          ? const Icon(Icons.person_rounded, size: 34, color: AppTheme.customerPrimary)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF22C55E),
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              usta.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.customerTextDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, size: 18, color: AppTheme.customerSecondary),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Onaylı ${usta.kategori.toUpperCase()} Ustası',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.customerTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Puan Rozeti
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      Text(
                        usta.puan.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 2. Mesafe ve Tahmini Varış Süresi Kartları
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.near_me_rounded, color: AppTheme.customerSecondary, size: 20),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Uzaklık',
                              style: TextStyle(fontSize: 11, color: AppTheme.customerTextMuted),
                            ),
                            Text(
                              usta.formattedDistance,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.customerTextDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded, color: Color(0xFFEA580C), size: 20),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tahmini Varış',
                              style: TextStyle(fontSize: 11, color: AppTheme.customerTextMuted),
                            ),
                            Text(
                              usta.tahminiVarisSuresi,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.customerTextDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 3. Fiyat Kırılımı (Servis Taban Bedeli + Platform Güvence Bedeli)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9).withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Servis Taban Bedeli',
                        style: TextStyle(fontSize: 13, color: AppTheme.customerTextDark),
                      ),
                      Text(
                        '${usta.ustaHakedis.toStringAsFixed(0)} ₺',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.customerTextDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 15, color: AppTheme.customerSecondary),
                          SizedBox(width: 6),
                          Text(
                            'Platform Güvence Bedeli',
                            style: TextStyle(fontSize: 13, color: AppTheme.customerTextDark),
                          ),
                        ],
                      ),
                      Text(
                        '${usta.komisyonTutari.toStringAsFixed(0)} ₺',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.customerTextDark,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: Color(0xFFCBD5E1)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Toplam Tutar',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.customerTextDark,
                            ),
                          ),
                          Text(
                            'Kartınızdan provizyon alınır',
                            style: TextStyle(fontSize: 11, color: AppTheme.customerTextMuted),
                          ),
                        ],
                      ),
                      Text(
                        usta.formattedPrice,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.customerPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 4. Adres / Not Girişi
            TextField(
              controller: _addressController,
              maxLines: 2,
              style: const TextStyle(fontSize: 13.5, color: AppTheme.customerTextDark),
              decoration: InputDecoration(
                labelText: 'Adres ve Arıza Notu (Opsiyonel)',
                hintText: 'Örn: Daire 6, elektrik sigortası attı.',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 5. 'Ustayı Çağır (Kartla Provizyon)' Aksiyon Butonu
            ElevatedButton(
              onPressed: mapState.isCreatingCall
                  ? null
                  : () async {
                      final cagriId = await mapController.createCagri(
                        usta: usta,
                        adresTarifi: _addressController.text.trim(),
                      );

                      if (cagriId != null && context.mounted) {
                        Navigator.pop(context); // Bottom sheet'i kapat
                        context.push('/customer/active-call/$cagriId');
                      }
                    },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: mapState.isCreatingCall
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Ustayı Çağır (Kartla Provizyon) • ${usta.formattedPrice}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
