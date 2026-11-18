import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ustaapp/core/services/app_data_service.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/auth/controllers/auth_controller.dart';
import 'package:ustaapp/features/auth/models/user_role.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _memberData;
  List<CagriModel> _userCalls = [];
  List<Map<String, dynamic>> _userTransactions = [];
  bool _isLoading = false;
  StreamSubscription? _dataChangedSub;

  // Bildirim tercihleri (yerel toggle durumu)
  bool _smsNotifications = true;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authStateProvider);
    final phone = authState.phone ?? '5524342068';
    _memberData = {
      'name': authState.fullName ?? 'Ahmet Mehmet',
      'full_name': authState.fullName ?? 'Ahmet Mehmet',
      'phone': phone,
      'email': 'ahmet.mehmet@gmail.com',
      'address': 'Ece Mahallesi, Sandıklı / Afyonkarahisar',
      'address_title': 'Ev Adresim',
      'address_notes': 'Merkez, 2. Kat No: 4',
      'city_district': 'Sandıklı, Afyonkarahisar',
      'registered_at': 'Kasım 2026',
      'role': authState.role?.toDbValue() ?? 'musteri',
    };
    _loadProfileData(silent: true);
    _dataChangedSub = AppDataService.instance.onDataChanged.listen((_) {
      if (mounted) _loadProfileData(silent: true);
    });
  }

  @override
  void dispose() {
    _dataChangedSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProfileData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final authState = ref.read(authStateProvider);
      final phone = authState.phone ?? '';
      final members = await AppDataService.instance.getMembers();
      final normPhone = AppDataService.normalizePhone(phone);

      Map<String, dynamic>? matchedMember;
      for (final m in members) {
        final mPhone = AppDataService.normalizePhone((m['phone'] ?? '').toString());
        if (mPhone.isNotEmpty && mPhone == normPhone) {
          matchedMember = Map<String, dynamic>.from(m);
          break;
        }
      }

      matchedMember ??= {
        'name': authState.fullName ?? 'Ahmet Mehmet',
        'full_name': authState.fullName ?? 'Ahmet Mehmet',
        'phone': phone.isNotEmpty ? phone : '5524342068',
        'email': 'ahmet.mehmet@gmail.com',
        'address': 'Ece Mahallesi, Sandıklı / Afyonkarahisar',
        'address_title': 'Ev Adresim',
        'address_notes': 'Merkez, 2. Kat No: 4',
        'city_district': 'Sandıklı, Afyonkarahisar',
        'registered_at': 'Kasım 2026',
        'role': authState.role?.toDbValue() ?? 'musteri',
      };

      // Kullanıcının çağrıları ve finansal geçmişi (anında yerel önbellekten yükle)
      final calls = await AppDataService.instance.getCagrilar(forceRefresh: false);
      final transactions = await AppDataService.instance.getFinancialTransactions(forceRefresh: false);

      if (mounted) {
        setState(() {
          _memberData = matchedMember;
          _userCalls = calls;
          _userTransactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Profil yüklenirken hata: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMemberData(Map<String, dynamic> updated) async {
    final members = await AppDataService.instance.getMembers();
    final normPhone = AppDataService.normalizePhone((updated['phone'] ?? '').toString());

    final idx = members.indexWhere((m) {
      final p = AppDataService.normalizePhone((m['phone'] ?? '').toString());
      return p == normPhone;
    });

    if (idx >= 0) {
      members[idx] = {...members[idx], ...updated};
    } else {
      members.add(updated);
    }

    await AppDataService.instance.saveMembers(members);

    // Auth state'i de senkronize et
    final newRole = UserRole.fromDbValue(updated['role']?.toString() ?? 'musteri') ?? UserRole.musteri;
    ref.read(authStateProvider.notifier).setAuthenticatedSession(
      role: newRole,
      phone: updated['phone']?.toString() ?? '',
      fullName: (updated['full_name'] ?? updated['name'])?.toString() ?? '',
    );

    setState(() {
      _memberData = updated;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil bilgileriniz başarıyla güncellendi.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  // ===========================================================================
  // MODAL VE DİYALOGLAR (KİŞİSEL BİLGİ, ADRES, SİPARİŞ GEÇMİŞİ, KARTLAR)
  // ===========================================================================

  void _showEditProfileSheet() {
    final nameCtrl = TextEditingController(text: (_memberData?['full_name'] ?? _memberData?['name'] ?? '').toString());
    final emailCtrl = TextEditingController(text: (_memberData?['email'] ?? 'ahmet.mehmet@gmail.com').toString());
    final phoneCtrl = TextEditingController(text: (_memberData?['phone'] ?? '').toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Kişisel Bilgilerimi Düzenle',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Ad Soyad',
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.customerPrimary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-posta Adresi',
                  prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.customerPrimary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Telefon Numarası',
                  prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.customerPrimary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.customerPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  final updated = Map<String, dynamic>.from(_memberData ?? {});
                  updated['full_name'] = nameCtrl.text.trim();
                  updated['name'] = nameCtrl.text.trim();
                  updated['email'] = emailCtrl.text.trim();
                  updated['phone'] = phoneCtrl.text.trim();
                  _saveMemberData(updated);
                  Navigator.pop(ctx);
                },
                child: const Text('Değişiklikleri Kaydet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddressManagerSheet() {
    final titleCtrl = TextEditingController(text: (_memberData?['address_title'] ?? 'Ev Adresim').toString());
    final addrCtrl = TextEditingController(text: (_memberData?['address'] ?? 'Ece Mahallesi, Sandıklı').toString());
    final noteCtrl = TextEditingController(text: (_memberData?['address_notes'] ?? '').toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.location_on_rounded, color: AppTheme.customerPrimary, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Kayıtlı Hizmet Adreslerim',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Adres Başlığı (Örn: Evim, İş Yerim)',
                    prefixIcon: const Icon(Icons.bookmark_outline_rounded, color: AppTheme.customerPrimary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addrCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Açık Adres (İlçe, Mahalle, Cadde/Sokak)',
                    prefixIcon: const Icon(Icons.home_outlined, color: AppTheme.customerPrimary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: 'Bina / Kapı No / Tarif Notu (İsteğe Bağlı)',
                    prefixIcon: const Icon(Icons.notes_rounded, color: AppTheme.customerPrimary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.customerPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    final updated = Map<String, dynamic>.from(_memberData ?? {});
                    updated['address_title'] = titleCtrl.text.trim();
                    updated['address'] = addrCtrl.text.trim();
                    updated['address_notes'] = noteCtrl.text.trim();
                    _saveMemberData(updated);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Adresi Kaydet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOrderHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Geçmiş Çağrı & Siparişlerim',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(8)),
                    child: Text('${_userTransactions.length} Kayıt', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _userTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('Henüz tamamlanmış bir servis çağrınız bulunmuyor.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _userTransactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _userTransactions[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      (item['hizmet_baslik'] ?? 'Standart Servis').toString(),
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      '${item['toplam_tutar'] ?? 750} ₺',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF16A34A)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Usta: ${item['usta_ad'] ?? 'Kadir Usta'} • ${item['created_at'] ?? 'Yeni'}',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('✓ İyzico İle Tahsil Edildi & Garantili', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCardsAndPaymentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.credit_card_rounded, color: AppTheme.customerPrimary, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Kayıtlı Kartlarım & İyzico Güvencesi',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Temsili Kart Görseli
              Container(
                height: 140,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('İyzico Güvenli Havuz', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('Mastercard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                      ],
                    ),
                    const Text('••••  ••••  ••••  4242', style: TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.w700)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text((_memberData?['full_name'] ?? 'Ahmet Mehmet').toString().toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                        const Text('12/28', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBBF7D0))),
                child: const Row(
                  children: [
                    Icon(Icons.lock_rounded, size: 16, color: Color(0xFF166534)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Kart bilgileriniz 256-bit SSL ve PCI-DSS seviyesinde İyzico sunucularında güvenle saklanır.', style: TextStyle(fontSize: 11, color: Color(0xFF166534))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('Yeni Kart Tanımla'),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kart ekleme formu İyzico 3D Secure ekranında açılıyor...')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRoleSwitchDialog(bool isUsta) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isUsta ? 'Müşteri Moduna Geçilsin mi?' : 'Usta Moduna Geçilsin mi?'),
          content: Text(
            isUsta
                ? 'Müşteri görünümüne geçerek harita veya ilan listesinden usta çağırabilirsiniz.'
                : 'Usta paneline geçerek bölgenizdeki müşteri çağrılarını kabul edebilir ve gelir elde edebilirsiniz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isUsta ? AppTheme.customerPrimary : AppTheme.ustaPrimary,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                final targetRole = isUsta ? UserRole.musteri : UserRole.usta;
                ref.read(authStateProvider.notifier).setAuthenticatedSession(
                  role: targetRole,
                  phone: _memberData?['phone'] ?? '5524342068',
                  fullName: _memberData?['full_name'] ?? _memberData?['name'] ?? 'Ahmet Mehmet',
                );

                if (targetRole == UserRole.usta) {
                  context.go('/usta/orders');
                } else {
                  context.go('/customer/home');
                }
              },
              child: Text(isUsta ? 'Müşteri Paneline Geç' : 'Usta Paneline Geç'),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Oturumu Kapat'),
          content: const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(authStateProvider.notifier).signOut();
                ref.read(phoneAuthControllerProvider.notifier).reset();
                if (context.mounted) {
                  context.go('/auth');
                }
              },
              child: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // ANA BUILD METODU
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isUsta = authState.role == UserRole.usta;

    final fullName = (_memberData?['full_name'] ?? _memberData?['name'] ?? authState.fullName ?? 'Kullanıcı').toString();
    final phone = (_memberData?['phone'] ?? authState.phone ?? '5524342068').toString();
    final email = (_memberData?['email'] ?? 'ahmet.mehmet@gmail.com').toString();
    final address = (_memberData?['address'] ?? 'Ece Mahallesi, Sandıklı / Afyonkarahisar').toString();
    final addressTitle = (_memberData?['address_title'] ?? 'Ev Adresim').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Profil & Hesap Yönetimi',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(isUsta ? '/usta/orders' : '/customer/home');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, size: 24, color: AppTheme.customerPrimary),
            tooltip: 'Profili Düzenle',
            onPressed: _showEditProfileSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.customerPrimary))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. ÜST HERO PROFİL KARTI
                  _buildHeroProfileCard(
                    fullName: fullName,
                    phone: phone,
                    email: email,
                    isUsta: isUsta,
                  ),
                  const SizedBox(height: 14),

                  // 2. KULLANICI İSTATİSTİK ŞERİDİ
                  _buildQuickStatsBar(isUsta: isUsta),
                  const SizedBox(height: 18),

                  // 3. ROL DEĞİŞTİRME / USTA VEYA MÜŞTERİ PANELİNE GEÇİŞ KARTI
                  _buildRoleSwitchCard(isUsta: isUsta),
                  const SizedBox(height: 18),

                  // 4. KATEGORİ: HESAP VE ADRESLERİM
                  _buildSectionHeader('HESAP VE ADRESLERİM'),
                  _buildMenuContainer([
                    _buildMenuItem(
                      icon: Icons.person_rounded,
                      iconBg: const Color(0xFFEEF2FF),
                      iconColor: const Color(0xFF4F46E5),
                      title: 'Kişisel Bilgilerim',
                      subtitle: '$fullName • $email',
                      onTap: _showEditProfileSheet,
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildMenuItem(
                      icon: Icons.location_on_rounded,
                      iconBg: const Color(0xFFECFDF5),
                      iconColor: const Color(0xFF059669),
                      title: 'Kayıtlı Hizmet Adreslerim',
                      subtitle: '$addressTitle: $address',
                      onTap: _showAddressManagerSheet,
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildNotificationToggleItem(),
                  ]),
                  const SizedBox(height: 18),

                  // 5. KATEGORİ: İŞLEMLER VE ÖDEMELER
                  _buildSectionHeader('İŞLEM VE ÖDEME GEÇMİŞİ'),
                  _buildMenuContainer([
                    _buildMenuItem(
                      icon: Icons.receipt_long_rounded,
                      iconBg: const Color(0xFFFFF7ED),
                      iconColor: const Color(0xFFEA580C),
                      title: 'Geçmiş Çağrılarım ve Servisler',
                      subtitle: '${_userTransactions.length} adet tamamlanan işlem kaydı',
                      onTap: _showOrderHistorySheet,
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildMenuItem(
                      icon: Icons.credit_card_rounded,
                      iconBg: const Color(0xFFF0FDF4),
                      iconColor: const Color(0xFF16A34A),
                      title: 'Kayıtlı Kartlarım & İyzico Güvencesi',
                      subtitle: 'Mastercard •••• 4242 (3D Secure)',
                      onTap: _showCardsAndPaymentSheet,
                    ),
                  ]),
                  const SizedBox(height: 18),

                  // 6. KATEGORİ: YARDIM, DESTEK VE GÜVENLİK
                  _buildSectionHeader('DESTEK VE GÜVENLİK'),
                  _buildMenuContainer([
                    _buildMenuItem(
                      icon: Icons.headset_mic_rounded,
                      iconBg: const Color(0xFFF5F3FF),
                      iconColor: const Color(0xFF7C3AED),
                      title: '7/24 Canlı Destek & Müşteri Hizmetleri',
                      subtitle: 'Hızlı WhatsApp ve telefon destek hattı',
                      onTap: () async {
                        final uri = Uri.parse('tel:08503080000');
                        if (await canLaunchUrl(uri)) launchUrl(uri);
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildMenuItem(
                      icon: Icons.verified_user_rounded,
                      iconBg: const Color(0xFFECFDF5),
                      iconColor: const Color(0xFF10B981),
                      title: 'İyzico Güvenlik ve KVKK Gizlilik Politikası',
                      subtitle: 'Kart saklama ve kullanıcı koruma sözleşmesi',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tüm işlemler 256-Bit SSL ve İyzico güvencesi altındadır.')),
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // 7. OTURUMU KAPAT BUTONU
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFFECACA), width: 1.5),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _showLogoutConfirmDialog,
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Oturumu Kapat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                  const SizedBox(height: 20),

                  // 8. TELİF VE VERSİYON BİLGİSİ
                  const Center(
                    child: Column(
                      children: [
                        Text(
                          'Ustamburada Mobile • Sürüm 2.4.0',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Mapbox Navigation & İyzico Ödeme Güvencesi',
                          style: TextStyle(fontSize: 10.5, color: Color(0xFFCBD5E1)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ===========================================================================
  // WIDGET BİLEŞENLERİ
  // ===========================================================================

  Widget _buildHeroProfileCard({
    required String fullName,
    required String phone,
    required String email,
    required bool isUsta,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUsta
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF0F172A), const Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppTheme.customerPrimary,
                    child: Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Kullanıcı Detayları
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF38BDF8)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '+90 $phone',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),

          // Alt Rozetler ve Hızlı Düzenle Butonu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isUsta ? const Color(0x33FF6B00) : const Color(0x3338BDF8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isUsta ? AppTheme.ustaPrimary : const Color(0xFF38BDF8),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUsta ? Icons.handyman_rounded : Icons.person_rounded,
                      size: 13,
                      color: isUsta ? AppTheme.ustaPrimary : const Color(0xFF38BDF8),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isUsta ? 'Onaylı Usta Hesabı' : 'Doğrulanmış Müşteri',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isUsta ? AppTheme.ustaPrimary : const Color(0xFF38BDF8),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _showEditProfileSheet,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_rounded, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Düzenle',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
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

  Widget _buildQuickStatsBar({required bool isUsta}) {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            label: isUsta ? 'Tamamlanan İş' : 'Toplam Çağrım',
            value: isUsta ? '48 İş' : '${_userCalls.length > _userTransactions.length ? _userCalls.length : _userTransactions.length} Çağrı',
            icon: Icons.assignment_turned_in_rounded,
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatItem(
            label: 'Güvence',
            value: 'İyzico Aktif',
            icon: Icons.shield_rounded,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatItem(
            label: 'Memnuniyet',
            value: '5.0 ★',
            icon: Icons.star_rounded,
            color: const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSwitchCard({required bool isUsta}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUsta ? const Color(0xFFEFF6FF) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUsta ? const Color(0xFFBFDBFE) : const Color(0xFFFED7AA),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isUsta ? AppTheme.customerPrimary : AppTheme.ustaPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isUsta ? Icons.person_search_rounded : Icons.handyman_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUsta ? 'Müşteri Moduna Geç' : 'Usta Olarak Hizmet Ver',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9A3412),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isUsta
                      ? 'Harita ve usta ilanlarını görmek için geçiş yapın.'
                      : 'Kendi hizmetlerinizi ekleyin ve çağrılardan kazanın.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFC2410C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isUsta ? AppTheme.customerPrimary : AppTheme.ustaPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _showRoleSwitchDialog(isUsta),
            child: const Text('Geçiş Yap', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildMenuContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationToggleItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFD97706), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SMS ve Çağrı Bildirimleri',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 2),
                Text(
                  'Usta yola çıktığında anlık SMS bildir',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Switch(
            value: _smsNotifications,
            activeColor: AppTheme.customerPrimary,
            onChanged: (val) {
              setState(() => _smsNotifications = val);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(val ? 'SMS bildirimleri etkinleştirildi.' : 'SMS bildirimleri kapatıldı.'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
