import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/services/payment_service.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/map/controllers/map_controller.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';

/// Haritanın alt kısmında yer alan kalıcı & dinamik açılır panel:
/// - Seçili usta yoksa: 'Bölgende X usta aktif • Tahmini varış: ... dk' özet bilgi çubuğu
/// - Pin seçildiğinde: yukarı açılarak Usta detayları, ETA, fiyat kırılımı ve çağır butonunu sunar
class MechanicBottomCard extends ConsumerStatefulWidget {
  final List<NearbyUstaModel> nearbyUstalar;
  final NearbyUstaModel? selectedUsta;
  final bool isLoadingUstalar;
  final ValueChanged<NearbyUstaModel> onQuickPickUsta;
  final VoidCallback onClearSelection;

  const MechanicBottomCard({
    super.key,
    required this.nearbyUstalar,
    required this.selectedUsta,
    required this.isLoadingUstalar,
    required this.onQuickPickUsta,
    required this.onClearSelection,
  });

  @override
  ConsumerState<MechanicBottomCard> createState() => _MechanicBottomCardState();
}

class _MechanicBottomCardState extends ConsumerState<MechanicBottomCard> {
  late final TextEditingController _noteController;
  bool _showNoteField = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant MechanicBottomCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedUsta?.ustaId != widget.selectedUsta?.ustaId) {
      _showNoteField = false;
      _noteController.clear();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _onCallUstaPressed(NearbyUstaModel usta) async {
    final mapController = ref.read(customerMapControllerProvider.notifier);
    final paymentService = ref.read(paymentServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final cagriId = await mapController.createCagri(
      usta: usta,
      adresTarifi: _noteController.text.trim(),
    );

    if (cagriId == null || !mounted) return;

    final preAuthResult = await paymentService.createPreAuth(cagriId: cagriId);
    if (!mounted) return;

    if (!preAuthResult.success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(preAuthResult.error ?? 'Karttan provizyon alınamadı.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    router.push('/customer/active-call/$cagriId');
  }

  @override
  Widget build(BuildContext context) {
    final usta = widget.selectedUsta;
    final mapState = ref.watch(customerMapControllerProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: usta == null
              ? _buildIdleSummaryBar()
              : _buildSelectedUstaCard(usta, mapState.isCreatingCall),
        ),
      ),
    );
  }

  /// Seçim yapılmadığında gösterilen özet bilgi çubuğu
  Widget _buildIdleSummaryBar() {
    final count = widget.nearbyUstalar.length;
    final minEta = widget.nearbyUstalar.isNotEmpty
        ? widget.nearbyUstalar
            .map((u) => u.tahminiVarisDakika)
            .reduce((a, b) => a < b ? a : b)
        : 15;
    final maxEta = minEta + 10;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.engineering_rounded,
                  color: Color(0xFF15803D),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isLoadingUstalar
                          ? 'Bölgendeki ustalar taranıyor...'
                          : 'Bölgende $count usta aktif • Tahmini varış: $minEta-$maxEta dk',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.customerTextDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Fiyatları ve detayları görmek için haritadaki bir pine dokunun',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.customerTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.nearbyUstalar.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.nearbyUstalar.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = widget.nearbyUstalar[index];
                  return ActionChip(
                    backgroundColor: const Color(0xFFF8FAFC),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    avatar: const Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: Colors.amber,
                    ),
                    label: Text(
                      '${item.shortDisplayName} • ${item.formattedPrice}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.customerTextDark,
                      ),
                    ),
                    onPressed: () => widget.onQuickPickUsta(item),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Usta pinine tıklandığında yukarı doğru açılan detay ve çağrı kartı
  Widget _buildSelectedUstaCard(NearbyUstaModel usta, bool isCreatingCall) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sürükleme tutamacı & kapatma
          Row(
            children: [
              const SizedBox(width: 32),
              Expanded(
                child: Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: widget.onClearSelection,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppTheme.customerTextDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 1. Profil Resmi, Adı, 'Onaylı Usta' Rozeti, Puan & İş Sayısı
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.customerPrimary.withValues(alpha: 0.1),
                    backgroundImage: usta.avatarUrl != null
                        ? NetworkImage(usta.avatarUrl!)
                        : null,
                    child: usta.avatarUrl == null
                        ? const Icon(
                            Icons.person_rounded,
                            size: 32,
                            color: AppTheme.customerPrimary,
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 15,
                      height: 15,
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
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.customerTextDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                size: 12,
                                color: AppTheme.customerPrimary,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Onaylı Usta',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.customerPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Colors.amber.shade600,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          usta.puan.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.customerTextDark,
                          ),
                        ),
                        const Text(
                          ' • ',
                          style: TextStyle(color: AppTheme.customerTextMuted),
                        ),
                        Text(
                          '${usta.tamamlananIsSayisi} tamamlanan iş',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.customerTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Varış Süresi & Mesafe Etiketleri
          Row(
            children: [
              Expanded(
                child: _MetricTag(
                  icon: Icons.access_time_filled_rounded,
                  iconColor: const Color(0xFFEA580C),
                  label: 'Varış Süresi: ~${usta.tahminiVarisDakika} dk',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTag(
                  icon: Icons.near_me_rounded,
                  iconColor: AppTheme.customerPrimary,
                  label: 'Mesafe: ${usta.formattedDistance}',
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 3. Fiyat Kırılımı Kartı
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _PriceLine(
                  label: 'Taban Ücret',
                  value: '${usta.ustaHakedis.toStringAsFixed(0)} ₺',
                ),
                const SizedBox(height: 6),
                _PriceLine(
                  label: 'Servis / Güvence Bedeli',
                  value: '${usta.komisyonTutari.toStringAsFixed(0)} ₺',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Color(0xFFCBD5E1)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Toplam Tutar',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.customerTextDark,
                      ),
                    ),
                    Text(
                      usta.formattedPrice,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.customerPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Opsiyonel adres/arıza notu açma/kapama
          if (!_showNoteField)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showNoteField = true),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 17),
                label: const Text(
                  'Adres veya arıza notu ekle (opsiyonel)',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: TextField(
                controller: _noteController,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Örn: Daire 6, sigorta kutusundan ses geliyor.',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),

          // 4. Tam Genişlikte Yüksek Kontrastlı CTA Butonu
          ElevatedButton.icon(
            onPressed: isCreatingCall ? null : () => _onCallUstaPressed(usta),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            icon: isCreatingCall
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.lock_rounded, size: 18),
            label: Text(
              isCreatingCall
                  ? 'Çağrı Başlatılıyor...'
                  : 'Hemen Çağır (Kartla Güvenceli Öde)',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTag extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _MetricTag({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.customerTextDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  final String label;
  final String value;

  const _PriceLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppTheme.customerTextMuted,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.customerTextDark,
          ),
        ),
      ],
    );
  }
}
