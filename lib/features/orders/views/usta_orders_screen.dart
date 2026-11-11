import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/auth/controllers/auth_controller.dart';
import 'package:ustaapp/features/orders/controllers/usta_dashboard_controller.dart';
import 'package:ustaapp/features/orders/views/widgets/incoming_call_dialog.dart';

class UstaOrdersScreen extends ConsumerStatefulWidget {
  const UstaOrdersScreen({super.key});

  @override
  ConsumerState<UstaOrdersScreen> createState() => _UstaOrdersScreenState();
}

class _UstaOrdersScreenState extends ConsumerState<UstaOrdersScreen> {
  late final TextEditingController _feeController;

  @override
  void initState() {
    super.initState();
    _feeController = TextEditingController();
  }

  @override
  void dispose() {
    _feeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ustaDashboardControllerProvider);
    final controller = ref.read(ustaDashboardControllerProvider.notifier);

    // Başlangıçta ücret alanını senkronize et
    if (_feeController.text.isEmpty && !state.isLoading) {
      _feeController.text = state.servisUcreti.toStringAsFixed(0);
    }

    // Başarı ve hata bildirimlerini dinle
    ref.listen<UstaDashboardState>(ustaDashboardControllerProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (next.successMessage != null && next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      // Gelen acil çağrı modalı
      if (next.incomingCall != null && next.incomingCall != previous?.incomingCall) {
        showDialog(
          context: context,
          barrierDismissible: false,
          useSafeArea: false,
          builder: (ctx) => IncomingCallDialog(cagri: next.incomingCall!),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.ustaDarkBackground,
      appBar: AppBar(
        title: const Text('Usta Kontrol Paneli'),
        backgroundColor: AppTheme.ustaDarkBackground,
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
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.ustaPrimary),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => controller.loadDashboardData(),
              color: AppTheme.ustaPrimary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. BÜYÜK DOKUNMATİK ÇEVRİMİÇİ / ÇEVRİMDIŞI TOGGLE KARTI
                    _buildBigTactileOnlineToggle(state, controller),

                    const SizedBox(height: 20),

                    // 2. GÜNLÜK TAMAMLANAN İŞ VE KAZANÇ ÖZET KARTI
                    _buildDailySummaryCard(state),

                    const SizedBox(height: 20),

                    // 3. TABAN SERVİS ÜCRETİ DÜZENLEME ALANI (300 - 5.000 TL)
                    _buildServiceFeeCard(state, controller),

                    const SizedBox(height: 24),

                    // 4. BEKLEYEN TALEPLER BAŞLIĞI & AKIŞI
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'Gelen Acil Çağrılar',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.ustaTextLight,
                            ),
                          ),
                        ),
                        if (state.isOnline)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => controller.simulateIncomingCall(),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.ustaSecondary.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.ustaSecondary.withValues(alpha: 0.45),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.notifications_active_rounded,
                                        size: 13,
                                        color: AppTheme.ustaSecondary,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Çağrı Simüle Et',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.ustaSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    SizedBox(
                                      width: 8,
                                      height: 8,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Canlı Takip Aktif',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.greenAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Çağrı listesi (Duruma göre yönlendirici)
                    if (!state.isOnline)
                      _buildOfflineNotice()
                    else
                      _buildSampleCallsList(),
                  ],
                ),
              ),
            ),
    );
  }

  /// 1. Büyük Dokunmatik 'Müsaitim (Online)' / 'Meşgulüm (Offline)' Butonu
  Widget _buildBigTactileOnlineToggle(
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
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: isOnline ? const Color(0xFF14532D).withOpacity(0.4) : AppTheme.ustaSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOnline ? Colors.greenAccent : AppTheme.ustaSurfaceBorder,
              width: isOnline ? 2.5 : 1.5,
            ),
            boxShadow: isOnline
                ? [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.2),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Canlı Işık Göstergesi
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? Colors.greenAccent : const Color(0xFF3F3F46),
                  boxShadow: isOnline
                      ? [
                          BoxShadow(
                            color: Colors.greenAccent.withOpacity(0.6),
                            blurRadius: 16,
                            spreadRadius: 4,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  isOnline ? Icons.bolt_rounded : Icons.power_settings_new_rounded,
                  color: isOnline ? Colors.black87 : Colors.white60,
                  size: 32,
                ),
              ),
              const SizedBox(width: 18),

              // Metin Bilgileri
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOnline ? 'MÜSAİTİM (ONLINE)' : 'MEŞGULÜM (OFFLINE)',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isOnline ? Colors.greenAccent : AppTheme.ustaTextLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOnline
                          ? 'Müşteri çağrılarına açıksınız. Konumunuz canlı paylaşılıyor.'
                          : 'Şu anda çağrı almıyorsunuz. Başlamak için dokunun.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.ustaTextMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Switch Kontrolü
              Switch(
                value: isOnline,
                activeColor: Colors.greenAccent,
                activeTrackColor: Colors.greenAccent.withOpacity(0.3),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: const Color(0xFF3F3F46),
                onChanged: (val) => controller.toggleOnlineStatus(val),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 2. Günlük Tamamlanan İş Sayısı ve Toplam Kazanç Özet Kartı
  Widget _buildDailySummaryCard(UstaDashboardState state) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.ustaSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.ustaSurfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.ustaSecondary),
              const SizedBox(width: 8),
              const Text(
                'Bugünün Performansı',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ustaTextMuted,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.ustaPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Bugün',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.ustaSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Tamamlanan İş Sayısı
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.ustaDarkBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tamamlanan İş',
                        style: TextStyle(fontSize: 12, color: AppTheme.ustaTextMuted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${state.dailyCompletedJobs} Çağrı',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ustaTextLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Toplam Kazanç
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.ustaDarkBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Toplam Kazanç',
                        style: TextStyle(fontSize: 12, color: AppTheme.ustaTextMuted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${state.dailyEarnings.toStringAsFixed(0)} ₺',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 3. Servis Taban Ücreti Güncelleme Kartı (Validasyon: 300 - 5.000 TL)
  Widget _buildServiceFeeCard(
    UstaDashboardState state,
    UstaDashboardController controller,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.ustaSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.ustaSurfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined, color: AppTheme.ustaSecondary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Servis Taban Ücretiniz',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.ustaTextLight,
                ),
              ),
              const Spacer(),
              Text(
                'Şu an: ${state.servisUcreti.toStringAsFixed(0)} ₺',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ustaSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Müşterilerin haritada göreceği başlangıç servis ücreti (300 ₺ ile 5.000 ₺ arası).',
            style: TextStyle(fontSize: 12, color: AppTheme.ustaTextMuted),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              // Ücret Giriş TextField
              Expanded(
                child: TextField(
                  controller: _feeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.ustaTextLight,
                  ),
                  decoration: InputDecoration(
                    suffixText: '₺',
                    suffixStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.ustaSecondary,
                    ),
                    hintText: 'Örn: 1500',
                    filled: true,
                    fillColor: AppTheme.ustaDarkBackground,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.ustaSurfaceBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Ücreti Kaydet Butonu
              ElevatedButton(
                onPressed: state.isSavingFee
                    ? null
                    : () {
                        final val = double.tryParse(_feeController.text.trim());
                        if (val == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lütfen geçerli bir sayı giriniz.')),
                          );
                          return;
                        }
                        controller.updateServisUcreti(val);
                      },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(120, 50),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: AppTheme.ustaPrimary,
                ),
                child: state.isSavingFee
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Ücreti Kaydet',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Çevrimdışı İkazı
  Widget _buildOfflineNotice() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.ustaSurface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.ustaSurfaceBorder),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.visibility_off_rounded, size: 40, color: AppTheme.ustaTextMuted),
            SizedBox(height: 12),
            Text(
              'Şu Anda Çevrimdışısınız',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.ustaTextLight,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Yakındaki acil çağrıları görebilmek ve haritada listelenmek için lütfen yukarıdan müsaitlik durumunuzu "Müsaitim" yapın.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppTheme.ustaTextMuted),
            ),
          ],
        ),
      ),
    );
  }

  /// Örnek Çağrı Listesi Bileşeni
  Widget _buildSampleCallsList() {
    return Column(
      children: [
        _buildCallItem(
          title: 'Elektrik Sigortası Sürekli Atıyor',
          customer: 'Kerem T.',
          address: 'Göztepe Mah. Bağdat Cad. No:114, Kadıköy',
          distance: '950 metre',
          fee: '750 ₺',
        ),
        const SizedBox(height: 12),
        _buildCallItem(
          title: 'Prizden Koku ve Kıvılcım Geldi',
          customer: 'Selin D.',
          address: 'Moda Sahil Sk. No:8, Kadıköy',
          distance: '1.4 km',
          fee: '600 ₺',
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
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.ustaSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.ustaSurfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.ustaTextLight,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.ustaPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  distance,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.ustaSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: AppTheme.ustaTextMuted),
              const SizedBox(width: 4),
              Text(customer, style: const TextStyle(fontSize: 13, color: AppTheme.ustaTextMuted)),
              const SizedBox(width: 12),
              const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.ustaTextMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppTheme.ustaTextMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hakediş: $fee',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.greenAccent,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Çağrı kabul edildi! Müşteri haritasına rota çiziliyor...'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(120, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: AppTheme.ustaPrimary,
                ),
                child: const Text('Kabul Et'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
