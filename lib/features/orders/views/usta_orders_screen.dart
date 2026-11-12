import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/auth/controllers/auth_controller.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';
import 'package:ustaapp/features/orders/controllers/usta_dashboard_controller.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';
import 'package:ustaapp/features/orders/views/widgets/incoming_call_dialog.dart';

class UstaOrdersScreen extends ConsumerStatefulWidget {
  const UstaOrdersScreen({super.key});

  @override
  ConsumerState<UstaOrdersScreen> createState() => _UstaOrdersScreenState();
}

class _UstaOrdersScreenState extends ConsumerState<UstaOrdersScreen> {
  late final TextEditingController _tabanFeeController;
  late final TextEditingController _kmFeeController;
  late final TextEditingController _freeKmController;
  late final TextEditingController _emergencyFeeController;
  double _radiusKm = 20.0;
  bool _initializedControllers = false;

  @override
  void initState() {
    super.initState();
    _tabanFeeController = TextEditingController(text: '750');
    _kmFeeController = TextEditingController(text: '18');
    _freeKmController = TextEditingController(text: '3');
    _emergencyFeeController = TextEditingController(text: '250');
  }

  void _syncControllers(UstaDashboardState state) {
    if (!_initializedControllers) {
      _tabanFeeController.text = state.servisUcreti.toStringAsFixed(0);
      _kmFeeController.text = state.kmBasiYakitUcreti.toStringAsFixed(0);
      _freeKmController.text = state.ucretsizMesafeKm.toStringAsFixed(0);
      _emergencyFeeController.text = state.acilGeceUcreti.toStringAsFixed(0);
      _radiusKm = state.calismaYaricapiKm;
      _initializedControllers = true;
    }
  }

  @override
  void dispose() {
    _tabanFeeController.dispose();
    _kmFeeController.dispose();
    _freeKmController.dispose();
    _emergencyFeeController.dispose();
    super.dispose();
  }

  void _showHizmetDialog({UstaHizmetIlan? existingHizmet}) {
    final isEditing = existingHizmet != null;
    final titleController =
        TextEditingController(text: existingHizmet?.baslik ?? '');
    final descController =
        TextEditingController(text: existingHizmet?.aciklama ?? '');
    final priceController = TextEditingController(
      text:
          existingHizmet != null ? existingHizmet.fiyat.toStringAsFixed(0) : '',
    );
    final durationController = TextEditingController(
      text: existingHizmet?.tahminiSure ?? '30 dk',
    );
    String selectedIcon = existingHizmet?.ikon ?? '⚡';
    bool isDefault = existingHizmet?.isDefault ?? false;

    const availableIcons = [
      '⚡',
      '🔌',
      '💡',
      '🛡️',
      '🔧',
      '🔑',
      '🚗',
      '🚰',
      '🚿',
      '🚽',
      '🔥',
      '🔔'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF475569),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing
                              ? 'Hizmeti Düzenle'
                              : 'Yeni Hizmet / İş Ekle',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // İkon Seçici
                    const Text(
                      'Hizmet İkonu Seçin:',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: availableIcons.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          final icon = availableIcons[idx];
                          final isSelected = selectedIcon == icon;
                          return InkWell(
                            onTap: () =>
                                setModalState(() => selectedIcon = icon),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.ustaPrimary
                                    : const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF334155),
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                              ),
                              child: Center(
                                child: Text(icon,
                                    style: const TextStyle(fontSize: 20)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Hizmet Başlığı
                    TextField(
                      controller: titleController,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13.5),
                      decoration: InputDecoration(
                        labelText: 'Hizmet / İş Başlığı',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        hintText: 'Örn: Avize & Aydınlatma Montajı',
                        hintStyle: const TextStyle(color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF334155)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Fiyat & Süre Yan Yana
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'Hizmet Ücreti (₺)',
                              labelStyle:
                                  const TextStyle(color: Color(0xFF94A3B8)),
                              suffixText: '₺',
                              suffixStyle: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold),
                              hintText: '500',
                              hintStyle:
                                  const TextStyle(color: Color(0xFF64748B)),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFF334155)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: durationController,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Tahmini Süre',
                              labelStyle:
                                  const TextStyle(color: Color(0xFF94A3B8)),
                              hintText: '30-45 dk',
                              hintStyle:
                                  const TextStyle(color: Color(0xFF64748B)),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFF334155)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Açıklama
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Hizmet Açıklaması & Kapsamı',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        hintText:
                            'Örn: Tavana sağlam dübelleme ve dimmer bağlantısı dahil.',
                        hintStyle: const TextStyle(color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFF334155)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Taban Paket mi? Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Varsayılan Taban Paket Olarak İşaretle',
                        style: TextStyle(color: Colors.white, fontSize: 12.5),
                      ),
                      value: isDefault,
                      activeThumbColor: AppTheme.ustaPrimary,
                      onChanged: (val) => setModalState(() => isDefault = val),
                    ),
                    const SizedBox(height: 12),

                    // Kaydet Butonu
                    ElevatedButton(
                      onPressed: () {
                        final title = titleController.text.trim();
                        final price =
                            double.tryParse(priceController.text.trim()) ?? 0.0;
                        if (title.isEmpty || price <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Lütfen geçerli bir başlık ve ücret giriniz.')),
                          );
                          return;
                        }

                        final controller =
                            ref.read(ustaDashboardControllerProvider.notifier);
                        final item = UstaHizmetIlan(
                          id: isEditing
                              ? existingHizmet.id
                              : 'hizmet-${DateTime.now().millisecondsSinceEpoch}',
                          baslik: title,
                          aciklama: descController.text.trim(),
                          fiyat: price,
                          tahminiSure: durationController.text.trim().isNotEmpty
                              ? durationController.text.trim()
                              : '30 dk',
                          ikon: selectedIcon,
                          isDefault: isDefault,
                        );

                        if (isEditing) {
                          controller.updateHizmet(item);
                        } else {
                          controller.addHizmet(item);
                        }
                        Navigator.of(ctx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.ustaPrimary,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        isEditing ? 'Hizmeti Güncelle' : 'Hizmeti Kaydet',
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ustaDashboardControllerProvider);
    final controller = ref.read(ustaDashboardControllerProvider.notifier);
    _syncControllers(state);

    // Başarı ve hata bildirimlerini dinle
    ref.listen<UstaDashboardState>(ustaDashboardControllerProvider,
        (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (next.successMessage != null &&
          next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      // Gelen acil çağrı modalı
      if (next.incomingCall != null &&
          next.incomingCall != previous?.incomingCall) {
        showDialog(
          context: context,
          barrierDismissible: false,
          useSafeArea: false,
          builder: (ctx) => IncomingCallDialog(cagri: next.incomingCall!),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Usta Kontrol Paneli',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: state.isOnline
                    ? const Color(0xFF15803D)
                    : const Color(0xFF334155),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                state.isOnline ? 'ONLINE' : 'OFFLINE',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        bottom: state.isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Colors.transparent,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.ustaPrimary),
                ),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: () => controller.loadDashboardData(),
          ),
          IconButton(
            icon: const Icon(Icons.person_rounded),
            tooltip: 'Profil',
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Çıkış Yap',
            onPressed: () async {
              await ref.read(authStateProvider.notifier).signOut();
              ref.read(phoneAuthControllerProvider.notifier).reset();
              if (context.mounted) {
                context.go('/auth');
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.loadDashboardData(),
        color: AppTheme.ustaPrimary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. ÇEVRİMİÇİ / ÇEVRİMDIŞI DOKUNMATİK CANLI STATÜ KARTI
              _buildTactileOnlineCard(state, controller),

              const SizedBox(height: 16),

              // 2. 4'LÜ PERFORMANS & KAZANÇ MATRİSİ
              _buildPerformanceGrid(state),

              const SizedBox(height: 20),

              // 3. HİZMET VE İLAN TARİFESİ YÖNETİMİ (Çoklu İş/Hizmet Ekleme)
              _buildServicesManagementSection(state, controller),

              const SizedBox(height: 20),

              // 4. AYRINTILI FİYATLANDIRMA & KİLOMETRE / YAKIT ÜCRETİ PANELİ
              _buildAdvancedPricingAndFuelCard(state, controller),

              const SizedBox(height: 24),

              // 5. GELEN ACİL ÇAĞRILAR & CANLI İŞ AKIŞI
              _buildLiveCallsSection(state, controller),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. Büyük Dokunmatik 'Müsaitim' / 'Meşgulüm' Statü Kartı
  Widget _buildTactileOnlineCard(
    UstaDashboardState state,
    UstaDashboardController controller,
  ) {
    final isOnline = state.isOnline;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => controller.toggleOnlineStatus(!isOnline),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isOnline
                ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isOnline ? const Color(0xFF10B981) : const Color(0xFF334155),
              width: isOnline ? 2.0 : 1.2,
            ),
            boxShadow: isOnline
                ? [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    const BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline
                      ? const Color(0xFF10B981)
                      : const Color(0xFF334155),
                  boxShadow: isOnline
                      ? [
                          BoxShadow(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.6),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  isOnline
                      ? Icons.bolt_rounded
                      : Icons.power_settings_new_rounded,
                  color: isOnline ? Colors.black : Colors.white60,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOnline ? 'MÜSAİTİM (ONLINE)' : 'MEŞGULÜM (OFFLINE)',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color:
                            isOnline ? const Color(0xFF34D399) : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isOnline
                          ? 'Çağrılara hazırsınız. ${state.ustaLocationAddress} konumunuz canlı yayında.'
                          : 'Şu an haritada gizlisiniz. Çağrı almaya başlamak için dokunun.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF94A3B8),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isOnline,
                activeThumbColor: const Color(0xFF10B981),
                activeTrackColor:
                    const Color(0xFF10B981).withValues(alpha: 0.3),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: const Color(0xFF334155),
                onChanged: (val) => controller.toggleOnlineStatus(val),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 2. Performans ve Finansal Gösterge Kartları (2x2 Grid)
  Widget _buildPerformanceGrid(UstaDashboardState state) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Bugünkü Kazanç',
                value: '${state.dailyEarnings.toStringAsFixed(0)} ₺',
                subtitle: '${state.dailyCompletedJobs} Çağrı Tamamlandı',
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF10B981),
                accentColor: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                title: 'Haftalık Hakediş',
                value: '${state.weeklyEarnings.toStringAsFixed(0)} ₺',
                subtitle: 'Provizyon Güvenceli',
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFF38BDF8),
                accentColor: const Color(0xFF38BDF8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Müşteri Puanı',
                value: '★ ${state.ortalamaPuan.toStringAsFixed(1)}',
                subtitle: '%99 Memnuniyet',
                icon: Icons.star_rounded,
                iconColor: Colors.amber,
                accentColor: Colors.amber,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                title: 'Çağrı Kabul Oranı',
                value: '%${state.kabulOrani}',
                subtitle: 'Hızlı Müdahale Rozeti',
                icon: Icons.verified_rounded,
                iconColor: AppTheme.ustaPrimary,
                accentColor: AppTheme.ustaPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 3. Hizmet ve İlan Tarifesi Yönetimi (Usta Birden Fazla İş Ekleyebilir)
  Widget _buildServicesManagementSection(
    UstaDashboardState state,
    UstaDashboardController controller,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.inventory_2_rounded,
                      size: 20, color: AppTheme.ustaPrimary),
                  SizedBox(width: 8),
                  Text(
                    'Hizmet & İlan Tarifem',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showHizmetDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.ustaPrimary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'Yeni Hizmet Ekle',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Müşterilerin harita panelinde göreceği hizmet ilanlarınız. Fiyat ve süreleri özelleştirebilirsiniz:',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          if (state.hizmetler.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Henüz özel hizmet eklemediniz. "+ Yeni Hizmet Ekle" ile tarifenizi oluşturun.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.hizmetler.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final hizmet = state.hizmetler[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hizmet.isDefault
                          ? AppTheme.ustaPrimary.withValues(alpha: 0.6)
                          : const Color(0xFF334155),
                      width: hizmet.isDefault ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(hizmet.ikon,
                              style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    hizmet.baslik,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (hizmet.isDefault)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.ustaPrimary
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Taban',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.ustaPrimary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              hizmet.aciklama,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '⏱️ ${hizmet.tahminiSure}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${hizmet.fiyat.toStringAsFixed(0)} ₺',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF34D399),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 16, color: Color(0xFF94A3B8)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Düzenle',
                                onPressed: () =>
                                    _showHizmetDialog(existingHizmet: hizmet),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 16, color: Colors.redAccent),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Sil',
                                onPressed: () =>
                                    controller.deleteHizmet(hizmet.id),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// 4. Gelişmiş Fiyatlandırma & Kilometre Başına Yakıt / Ulaşım Ayarları
  Widget _buildAdvancedPricingAndFuelCard(
    UstaDashboardState state,
    UstaDashboardController controller,
  ) {
    // Örnek 8 km hesaplama simülasyonu
    final sampleDistance = 8.0;
    final sampleTravel = state.calculateTravelFee(sampleDistance);
    final sampleTotal = state.servisUcreti + sampleTravel;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, size: 20, color: Color(0xFF38BDF8)),
              SizedBox(width: 8),
              Text(
                'Ayrıntılı Fiyatlandırma & Yakıt Tarifesi',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Uzak adrese giderken kilometre başına yakıt ve gece tarifesi ekleyerek hakedişinizi optimize edin:',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),

          // 1. Satır: Taban Servis & Km Başı Yakıt Ücreti
          Row(
            children: [
              Expanded(
                child: _TarifeInputField(
                  controller: _tabanFeeController,
                  label: 'Taban Servis Ücreti',
                  suffix: '₺',
                  hint: '750',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TarifeInputField(
                  controller: _kmFeeController,
                  label: 'Km Başı Yakıt / Ulaşım',
                  suffix: '₺/km',
                  hint: '18',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Satır: Ücretsiz Mesafe & Gece / Acil Ek Ücreti
          Row(
            children: [
              Expanded(
                child: _TarifeInputField(
                  controller: _freeKmController,
                  label: 'Ücretsiz Yarıçap (Tabana Dahil)',
                  suffix: 'km',
                  hint: '3',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TarifeInputField(
                  controller: _emergencyFeeController,
                  label: 'Gece / Acil Ek Ücreti',
                  suffix: '₺',
                  hint: '250',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Maksimum Hizmet Yarıçapı Slider'ı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Maksimum Çalışma Yarıçapı:',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8)),
              ),
              Text(
                '${_radiusKm.toStringAsFixed(0)} km',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF38BDF8)),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF38BDF8),
              inactiveTrackColor: const Color(0xFF0F172A),
              thumbColor: const Color(0xFF38BDF8),
              overlayColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _radiusKm,
              min: 5.0,
              max: 50.0,
              divisions: 9,
              onChanged: (val) => setState(() => _radiusKm = val),
            ),
          ),

          // Canlı Simülasyon Bilgi Kutusu
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calculate_outlined,
                    size: 20, color: Color(0xFF38BDF8)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Örnek 8 km çağrıda: ${_tabanFeeController.text} ₺ taban + ${sampleTravel.toStringAsFixed(0)} ₺ yol (${(sampleDistance - state.ucretsizMesafeKm).toStringAsFixed(0)} km x ${state.kmBasiYakitUcreti.toStringAsFixed(0)} ₺) = ${sampleTotal.toStringAsFixed(0)} ₺ Hakediş',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFCBD5E1)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tarifeyi Kaydet Butonu
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: state.isSavingFee
                  ? null
                  : () {
                      final taban =
                          double.tryParse(_tabanFeeController.text.trim()) ??
                              750.0;
                      final kmFee =
                          double.tryParse(_kmFeeController.text.trim()) ?? 18.0;
                      final freeKm =
                          double.tryParse(_freeKmController.text.trim()) ?? 3.0;
                      final emergency = double.tryParse(
                              _emergencyFeeController.text.trim()) ??
                          250.0;

                      controller.updateTarifeAyarlari(
                        tabanServis: taban,
                        kmBasiYakit: kmFee,
                        ucretsizMesafeKm: freeKm,
                        acilGeceUcreti: emergency,
                        calismaYaricapiKm: _radiusKm,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: state.isSavingFee
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Tarife & Yakıt Ayarlarını Kaydet',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Gelen Acil Çağrılar ve Canlı İş Akışı
  Widget _buildLiveCallsSection(
    UstaDashboardState state,
    UstaDashboardController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Gelen Acil Çağrılar',
              style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
            if (state.isOnline)
              InkWell(
                onTap: () => controller.simulateIncomingCall(),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.ustaPrimary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.ustaPrimary.withValues(alpha: 0.45)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_active_rounded,
                          size: 14, color: AppTheme.ustaPrimary),
                      SizedBox(width: 4),
                      Text(
                        'Çağrı Simüle Et',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.ustaPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (!state.isOnline)
          _buildOfflineNotice(controller)
        else
          _buildSampleCallsList(state),
      ],
    );
  }

  Widget _buildOfflineNotice(UstaDashboardController controller) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.visibility_off_rounded,
                size: 36, color: Color(0xFF64748B)),
            const SizedBox(height: 10),
            const Text(
              'Şu Anda Çevrimdışısınız',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 4),
            const Text(
              'Yakındaki müşterilerin çağrılarını alabilmek için yukarıdan müsaitlik durumunuzu "Müsaitim" yapın.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => controller.toggleOnlineStatus(true),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(180, 44),
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 16),
                label: const Text('Şimdi Çevrimiçi Ol',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleCallsList(UstaDashboardState state) {
    final controller = ref.read(ustaDashboardControllerProvider.notifier);

    // Mesafeye göre yakıtlı ücret hesaplamaları
    const sampleDistance1 = 1.2;
    final fee1 = state.calculateTotalQuote(
        basePrice: state.servisUcreti, distanceKm: sampleDistance1);
    final fee2 = state.calculateTotalQuote(basePrice: 950.0, distanceKm: 4.8);

    return Column(
      children: [
        _buildCallItem(
          title: 'Sigorta Panosu Sürekli Atıyor & Koku Var',
          customer: 'Kerem T.',
          address: 'Göztepe Mah. Bağdat Cad. No:114 D:6, Kadıköy',
          distance: '1.2 km',
          fee: '${fee1.toStringAsFixed(0)} ₺',
          note: 'Daire 6 • Sigorta kutusundan ses geliyor.',
          onAccept: () async {
            const callId = 'demo-cagri-sigorta';
            final demoCall = CagriModel(
              id: callId,
              musteriId: 'musteri-kerem-1',
              ustaId: controller.currentUserId ?? 'demo-usta',
              musteriLat: state.ustaLat + 0.0075,
              musteriLng: state.ustaLng + 0.0055,
              adresTarifi:
                  'Göztepe Mah. Bağdat Cad. No:114 D:6, Kadıköy (Daire 6 • Sigorta kutusundan ses geliyor)',
              durum: CagriDurumu.bekliyor,
              ustaHakedis: fee1,
              komisyonTutari: fee1 * 0.15,
              toplamTutar: fee1 * 1.15,
              createdAt: DateTime.now(),
              musteriFullName: 'Kerem T.',
              musteriPhone: '+90 532 555 10 20',
            );
            DemoCallRepository.save(demoCall);

            final success = await controller.acceptIncomingCall(callId);
            if (context.mounted && success) {
              context.push('/usta/active-job/$callId');
            }
          },
        ),
        const SizedBox(height: 10),
        _buildCallItem(
          title: 'Avize & Aydınlatma Montajı (2 Adet)',
          customer: 'Selin D.',
          address: 'Moda Sahil Sk. No:8 D:3, Kadıköy',
          distance: '4.8 km',
          fee: '${fee2.toStringAsFixed(0)} ₺',
          note: 'Tavan yüksek, merdiven ve dübel gerekebilir.',
          onAccept: () async {
            const callId = 'demo-cagri-avize';
            final demoCall = CagriModel(
              id: callId,
              musteriId: 'musteri-selin-2',
              ustaId: controller.currentUserId ?? 'demo-usta',
              musteriLat: state.ustaLat + 0.0140,
              musteriLng: state.ustaLng - 0.0080,
              adresTarifi:
                  'Moda Sahil Sk. No:8 D:3, Kadıköy (Tavan yüksek, merdiven ve dübel gerekebilir)',
              durum: CagriDurumu.bekliyor,
              ustaHakedis: fee2,
              komisyonTutari: fee2 * 0.15,
              toplamTutar: fee2 * 1.15,
              createdAt: DateTime.now(),
              musteriFullName: 'Selin D.',
              musteriPhone: '+90 533 444 80 90',
            );
            DemoCallRepository.save(demoCall);

            final success = await controller.acceptIncomingCall(callId);
            if (context.mounted && success) {
              context.push('/usta/active-job/$callId');
            }
          },
        ),
      ],
    );
  }

  Widget _buildCallItem({
    required String title,
    required String customer,
    required String address,
    required String distance,
    required String fee,
    required String note,
    required Future<void> Function() onAccept,
  }) {
    return _CallItemCard(
      title: title,
      customer: customer,
      address: address,
      distance: distance,
      fee: fee,
      note: note,
      onAccept: onAccept,
    );
  }
}

class _CallItemCard extends StatefulWidget {
  final String title;
  final String customer;
  final String address;
  final String distance;
  final String fee;
  final String note;
  final Future<void> Function() onAccept;

  const _CallItemCard({
    required this.title,
    required this.customer,
    required this.address,
    required this.distance,
    required this.fee,
    required this.note,
    required this.onAccept,
  });

  @override
  State<_CallItemCard> createState() => _CallItemCardState();
}

class _CallItemCardState extends State<_CallItemCard> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Text(
                  widget.distance,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF38BDF8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(widget.customer,
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF94A3B8))),
              const SizedBox(width: 10),
              const Icon(Icons.location_on_outlined,
                  size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '📝 ${widget.note}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tahmini Hakediş',
                      style:
                          TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                  Text(
                    widget.fee,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF34D399)),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        try {
                          await widget.onAccept();
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(110, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  backgroundColor: AppTheme.ustaPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Kabul Et',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color accentColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8)),
              ),
              Icon(icon, size: 18, color: iconColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: accentColor),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _TarifeInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;
  final String hint;

  const _TarifeInputField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            suffixText: suffix,
            suffixStyle: const TextStyle(
                color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
          ),
        ),
      ],
    );
  }
}
