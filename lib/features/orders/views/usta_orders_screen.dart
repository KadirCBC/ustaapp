import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ustaapp/core/models/app_notification_model.dart';
import 'package:ustaapp/core/services/app_data_service.dart';
import 'package:ustaapp/core/services/location_lookup_service.dart';
import 'package:ustaapp/core/services/notification_service.dart';
import 'package:ustaapp/core/services/special_permissions_service.dart';
import 'package:ustaapp/core/services/supabase_service.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/core/widgets/notification_sheet.dart';
import 'package:ustaapp/features/auth/controllers/auth_controller.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';
import 'package:ustaapp/features/orders/controllers/usta_dashboard_controller.dart';
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
  double? _lastLoadedTaban;
  double? _lastLoadedKm;
  double? _lastLoadedFreeKm;
  double? _lastLoadedEmergency;
  double? _lastLoadedRadius;

  late final FocusNode _tabanFocusNode;
  late final FocusNode _kmFocusNode;
  late final FocusNode _freeKmFocusNode;
  late final FocusNode _emergencyFocusNode;

  // Çalışma Saatleri ve Nöbet Modu Durumu
  String _workStartHour = '08:30';
  String _workEndHour = '20:00';
  bool _isOnDutyNight = true;
  bool _worksWeekend = true;

  @override
  void initState() {
    super.initState();
    _tabanFocusNode = FocusNode();
    _kmFocusNode = FocusNode();
    _freeKmFocusNode = FocusNode();
    _emergencyFocusNode = FocusNode();

    _tabanFeeController = TextEditingController();
    _kmFeeController = TextEditingController();
    _freeKmController = TextEditingController();
    _emergencyFeeController = TextEditingController();

    _tabanFeeController.addListener(() {
      if (mounted) setState(() {});
    });
    _kmFeeController.addListener(() {
      if (mounted) setState(() {});
    });
    _freeKmController.addListener(() {
      if (mounted) setState(() {});
    });
    _emergencyFeeController.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ustaDashboardControllerProvider.notifier).loadDashboardData(forceRefresh: true);
      SpecialPermissionsService.instance.showPermissionSheetIfNeeded(context);
    });
  }

  void _syncControllers(UstaDashboardState state) {
    // Eğer kullanıcı alanlardan birine odaklanmışsa veya yazıyorsa imleci ve metni ezme
    final bool isUserTyping = _tabanFocusNode.hasFocus ||
        _kmFocusNode.hasFocus ||
        _freeKmFocusNode.hasFocus ||
        _emergencyFocusNode.hasFocus;

    if (isUserTyping) return;

    if (!_initializedControllers ||
        _lastLoadedTaban != state.servisUcreti ||
        _lastLoadedKm != state.kmBasiYakitUcreti ||
        _lastLoadedFreeKm != state.ucretsizMesafeKm ||
        _lastLoadedEmergency != state.acilGeceUcreti ||
        _lastLoadedRadius != state.calismaYaricapiKm) {
      _lastLoadedTaban = state.servisUcreti;
      _lastLoadedKm = state.kmBasiYakitUcreti;
      _lastLoadedFreeKm = state.ucretsizMesafeKm;
      _lastLoadedEmergency = state.acilGeceUcreti;
      _lastLoadedRadius = state.calismaYaricapiKm;

      if (state.hasCustomTarife && state.servisUcreti > 0) {
        _tabanFeeController.text = state.servisUcreti.toStringAsFixed(0);
        _kmFeeController.text = state.kmBasiYakitUcreti > 0 ? state.kmBasiYakitUcreti.toStringAsFixed(0) : '';
        _freeKmController.text = state.ucretsizMesafeKm > 0 ? state.ucretsizMesafeKm.toStringAsFixed(0) : '';
        _emergencyFeeController.text = state.acilGeceUcreti > 0 ? state.acilGeceUcreti.toStringAsFixed(0) : '';
      } else {
        _tabanFeeController.text = '';
        _kmFeeController.text = '';
        _freeKmController.text = '';
        _emergencyFeeController.text = '';
      }
      _radiusKm = state.calismaYaricapiKm > 0 ? state.calismaYaricapiKm : 20.0;
      _initializedControllers = true;
    }
  }

  @override
  void dispose() {
    _tabanFocusNode.dispose();
    _kmFocusNode.dispose();
    _freeKmFocusNode.dispose();
    _emergencyFocusNode.dispose();

    _tabanFeeController.dispose();
    _kmFeeController.dispose();
    _freeKmController.dispose();
    _emergencyFeeController.dispose();
    super.dispose();
  }

  void _showHizmetDialog({UstaHizmetIlan? existingHizmet}) {
    final isEditing = existingHizmet != null;
    final currentUstaState = ref.read(ustaDashboardControllerProvider);
    final titleController =
        TextEditingController(text: existingHizmet?.baslik ?? '');
    final descController =
        TextEditingController(text: existingHizmet?.aciklama ?? '');
    final locationController = TextEditingController(
      text: existingHizmet?.konum ?? currentUstaState.ustaLocationAddress,
    );
    final priceController = TextEditingController(
      text:
          existingHizmet != null ? existingHizmet.fiyat.toStringAsFixed(0) : '',
    );
    final durationController = TextEditingController(
      text: existingHizmet?.tahminiSure ?? '30 dk',
    );
    String selectedIcon = existingHizmet?.ikon ?? '⚡';
    bool isDefault = existingHizmet?.isDefault ?? false;

    final categoryList = AppDataService.defaultAppCategories
        .map((c) => (c['name'] ?? c['title'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();

    String selectedCategory = existingHizmet?.kategori ??
        (categoryList.isNotEmpty ? categoryList.first : 'Elektrik');
    if (!categoryList.contains(selectedCategory)) {
      selectedCategory = categoryList.first;
    }

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
      backgroundColor: Colors.white,
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
                          color: const Color(0xFFE2E8F0),
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
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded,
                              color: Color(0xFF64748B)),
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
                          color: Color(0xFF334155)),
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
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.ustaPrimary
                                      : const Color(0xFFE2E8F0),
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

                    // Hizmet Kategorisi Seçimi
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      icon: const Icon(Icons.arrow_drop_down_rounded,
                          color: Color(0xFF64748B), size: 28),
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Hizmet Kategorisi / Meslek Alanı',
                        labelStyle: const TextStyle(color: Color(0xFF64748B)),
                        prefixIcon: const Icon(Icons.category_rounded,
                            color: AppTheme.ustaPrimary, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppTheme.ustaPrimary, width: 2),
                        ),
                      ),
                      items: categoryList.map((catName) {
                        return DropdownMenuItem<String>(
                          value: catName,
                          child: Text(
                            catName,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Hizmet Başlığı
                    TextField(
                      controller: titleController,
                      style:
                          const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
                      decoration: InputDecoration(
                        labelText: 'Hizmet / İş Başlığı',
                        labelStyle: const TextStyle(color: Color(0xFF64748B)),
                        hintText: 'Örn: Avize & Aydınlatma Montajı',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppTheme.ustaPrimary, width: 2),
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
                                color: Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'Hizmet Ücreti (₺)',
                              labelStyle:
                                  const TextStyle(color: Color(0xFF64748B)),
                              suffixText: '₺',
                              suffixStyle: const TextStyle(
                                  color: AppTheme.ustaPrimary,
                                  fontWeight: FontWeight.bold),
                              hintText: '500',
                              hintStyle:
                                  const TextStyle(color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: AppTheme.ustaPrimary, width: 2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: durationController,
                            style: const TextStyle(
                                color: Color(0xFF0F172A), fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Tahmini Süre',
                              labelStyle:
                                  const TextStyle(color: Color(0xFF64748B)),
                              hintText: '30-45 dk',
                              hintStyle:
                                  const TextStyle(color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: AppTheme.ustaPrimary, width: 2),
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
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Hizmet Açıklaması & Kapsamı',
                        labelStyle: const TextStyle(color: Color(0xFF64748B)),
                        hintText:
                            'Örn: Tavana sağlam dübelleme ve dimmer bağlantısı dahil.',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppTheme.ustaPrimary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Hizmet Bölgesi / İlçe / Konum Girişi
                    TextField(
                      controller: locationController,
                      style:
                          const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
                      decoration: InputDecoration(
                        labelText: 'Hizmet Bölgesi / Şehir, İlçe veya Mahalle',
                        labelStyle: const TextStyle(color: Color(0xFF64748B)),
                        hintText: 'Örn: Sandıklı, Afyonkarahisar veya Ece Mah.',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.location_on_rounded,
                            color: AppTheme.ustaPrimary),
                        suffixIcon: IconButton(
                          tooltip: 'Mevcut Çalışma Konumumu Kullan',
                          icon: const Icon(Icons.my_location_rounded,
                              color: AppTheme.ustaPrimary, size: 20),
                          onPressed: () {
                            setModalState(() {
                              locationController.text =
                                  currentUstaState.ustaLocationAddress;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppTheme.ustaPrimary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (currentUstaState.ustaLocationAddress.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ActionChip(
                          avatar: const Icon(Icons.my_location_rounded, size: 14, color: AppTheme.ustaPrimary),
                          label: Text(
                            'Mevcut Adresimi Kullan: ${currentUstaState.ustaLocationAddress}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                          ),
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          onPressed: () => setModalState(
                            () => locationController.text = currentUstaState.ustaLocationAddress,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Taban Paket mi? Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Varsayılan Taban Paket Olarak İşaretle',
                        style: TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      value: isDefault,
                      activeThumbColor: AppTheme.ustaPrimary,
                      onChanged: (val) => setModalState(() => isDefault = val),
                    ),
                    const SizedBox(height: 12),

                    // Kaydet Butonu
                    ElevatedButton(
                      onPressed: () async {
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

                        final locationText =
                            locationController.text.trim().isNotEmpty
                                ? locationController.text.trim()
                                : currentUstaState.ustaLocationAddress;

                        double resolvedLat = currentUstaState.ustaLat;
                        double resolvedLng = currentUstaState.ustaLng;
                        final syncMatch =
                            LocationLookupService.resolveSync(locationText);
                        if (syncMatch != null) {
                          resolvedLat = syncMatch.lat;
                          resolvedLng = syncMatch.lng;
                        } else {
                          final match =
                              await LocationLookupService.resolveBestMatch(
                                  locationText);
                          if (match != null) {
                            resolvedLat = match.lat;
                            resolvedLng = match.lng;
                          }
                        }

                        final controller =
                            ref.read(ustaDashboardControllerProvider.notifier);
                        final item = UstaHizmetIlan(
                          id: isEditing
                              ? existingHizmet.id
                              : 'ILN-${DateTime.now().millisecondsSinceEpoch % 9000 + 1000}',
                          baslik: title,
                          kategori: selectedCategory,
                          aciklama: descController.text.trim(),
                          fiyat: price,
                          tahminiSure: durationController.text.trim().isNotEmpty
                              ? durationController.text.trim()
                              : '30 dk',
                          ikon: selectedIcon,
                          isDefault: isDefault,
                          konum: locationText,
                          lat: resolvedLat,
                          lng: resolvedLng,
                        );

                        if (isEditing) {
                          await controller.updateHizmet(item);
                        } else {
                          await controller.addHizmet(item);
                        }
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        titleSpacing: 0,
        toolbarHeight: 64,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/ustagelio_logo.png',
              height: 30,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/images/app_logo.png',
                height: 30,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.handyman_rounded,
                  size: 24,
                  color: AppTheme.ustaPrimary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Usta Paneli',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    letterSpacing: -0.1,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: state.isOnline
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: state.isOnline
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: state.isOnline
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        state.isOnline ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: state.isOnline
                              ? const Color(0xFF15803D)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Color(0xFF334155)),
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
            : const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(height: 1, color: Color(0xFFE2E8F0)),
              ),
        actions: [
          // Bildirimler Butonu (Sayaç / Dot ile)
          ValueListenableBuilder<List<AppNotificationModel>>(
            valueListenable: NotificationService.instance.notificationsNotifier,
            builder: (context, notifs, _) {
              final unread = notifs.any((n) => !n.isRead);
              return InkWell(
                onTap: () => NotificationSheet.show(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_none_rounded,
                        size: 21,
                        color: Color(0xFF334155),
                      ),
                      if (unread)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.loadDashboardData(forceRefresh: true),
        color: AppTheme.ustaPrimary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. ÇEVRİMİÇİ / ÇEVRİMDIŞI DOKUNMATİK CANLI STATÜ KARTI
              _buildTactileOnlineCard(state, controller),

              const SizedBox(height: 14),

              // 1.1 ÇALIŞMA SAATLERİ & NÖBETÇİ MODU KARTI
              _buildWorkingHoursAndDutyCard(),

              const SizedBox(height: 14),

              // 1.2 USTA CÜZDANI & HAKEDİŞ HIZLI ERİŞİM BANNERI
              _buildWalletBannerCard(state),

              const SizedBox(height: 14),

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
      bottomNavigationBar: _buildUstaBottomNav(),
    );
  }

  void _showExploreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.explore_rounded, color: Color(0xFF2563EB), size: 22),
                SizedBox(width: 8),
                Text(
                  'Harita & Liste Keşfi',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Usta olarak bölgenizdeki diğer ustaları, toptancı & tedarikçileri ve müşteri ilanlarını inceleyin:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                context.push('/customer/map');
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.map_rounded, color: Color(0xFF2563EB), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Canlı Müşteri & Usta Haritası',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E40AF)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Harita üzerindeki tüm ustaları, dükkanları ve malzeme tedarikçilerini görün',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF3B82F6)),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                context.push('/customer/home');
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.grid_view_rounded, color: Color(0xFF16A34A), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tüm Hizmetler & İlan Listesi',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF166534)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '28 farklı meslek kategorisini, müşteri ilanlarını ve fiyat tarifelerini listeleyin',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF15803D)),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF16A34A)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Çıkış Yapılsın mı?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('Oturumunuz kapatılacaktır. Tekrar giriş yapmak istediğinizde telefon numaranızla giriş yapabilirsiniz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authStateProvider.notifier).signOut();
              ref.read(phoneAuthControllerProvider.notifier).reset();
              if (context.mounted) {
                context.go('/auth');
              }
            },
            child: const Text('Çıkış Yap', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildUstaBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: const Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.dashboard_rounded,
                label: 'Usta Paneli',
                isSelected: true,
                onTap: () {},
              ),
              _buildNavItem(
                icon: Icons.map_rounded,
                label: 'Harita',
                isSelected: false,
                onTap: () => context.push('/customer/map'),
              ),
              _buildNavItem(
                icon: Icons.grid_view_rounded,
                label: 'İlanlar & Liste',
                isSelected: false,
                onTap: () => context.push('/customer/home'),
              ),
              _buildNavItem(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Cüzdanım',
                isSelected: false,
                onTap: () => context.push('/usta/wallet'),
              ),
              _buildNavItem(
                icon: Icons.person_rounded,
                label: 'Profil',
                isSelected: false,
                onTap: () => context.push('/profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? badge,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: AppTheme.ustaPrimary.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: isSelected ? 14 : 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.ustaPrimary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icon,
                        size: 22,
                        color: isSelected
                            ? AppTheme.ustaPrimary
                            : const Color(0xFF64748B),
                      ),
                    ),
                    if (badge != null)
                      Positioned(
                        top: -2,
                        right: isSelected ? 4 : 0,
                        child: badge,
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    color: isSelected
                        ? AppTheme.ustaPrimary
                        : const Color(0xFF64748B),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 4.5 : 0,
                  height: 4.5,
                  decoration: const BoxDecoration(
                    color: AppTheme.ustaPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOnline
                  ? const Color(0xFF22C55E).withValues(alpha: 0.6)
                  : const Color(0xFFE2E8F0),
              width: isOnline ? 1.6 : 1.0,
            ),
            boxShadow: isOnline
                ? [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFF1F5F9),
                  border: Border.all(
                    color: isOnline
                        ? const Color(0xFF86EFAC)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Icon(
                  isOnline
                      ? Icons.bolt_rounded
                      : Icons.power_settings_new_rounded,
                  color: isOnline
                      ? const Color(0xFF15803D)
                      : const Color(0xFF64748B),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOnline ? 'MÜSAİTİM (ONLINE)' : 'MEŞGULÜM (OFFLINE)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: isOnline
                            ? const Color(0xFF15803D)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isOnline
                          ? 'Çağrılara hazırsınız. ${state.ustaLocationAddress} konumunuz canlı yayında.'
                          : 'Şu an haritada gizlisiniz. Çağrı almaya başlamak için dokunun.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () =>
                          _showUstaLocationChangeDialog(state, controller),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 14, color: AppTheme.ustaPrimary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                state.ustaLocationAddress,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Değiştir',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.ustaPrimary,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_right_rounded,
                                size: 14, color: AppTheme.ustaPrimary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isOnline,
                activeThumbColor: const Color(0xFF16A34A),
                activeTrackColor: const Color(0xFFBBF7D0),
                inactiveThumbColor: const Color(0xFF94A3B8),
                inactiveTrackColor: const Color(0xFFE2E8F0),
                onChanged: (val) => controller.toggleOnlineStatus(val),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showUstaLocationChangeDialog(
    UstaDashboardState state,
    UstaDashboardController controller,
  ) async {
    final textController =
        TextEditingController(text: state.ustaLocationAddress);
    List<LocationSuggestion> liveSuggestions = [];

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const SizedBox(height: 16),
                    const Text(
                      'Çalışma Bölgenizi / Konumunuzu Belirleyin',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Müşteri çağrıları ve iş bildirimleri bu konuma göre eşleşir.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),

                    // 1. Canlı GPS Konumumu Kullan Butonu
                    InkWell(
                      onTap: () => Navigator.of(ctx).pop('__USE_GPS__'),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.ustaPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFED7AA)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.my_location_rounded, color: AppTheme.ustaPrimary, size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mevcut Canlı Konumumu Kullan (GPS)',
                                    style: TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Cihaz uydusundan anlık konumunuzu alır ve haritaya yayınlar',
                                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.ustaPrimary, size: 14),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'veya adres arayın',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ),
                        Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                      ],
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: textController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5),
                      onChanged: (val) async {
                        if (val.trim().length >= 2) {
                          final results = await LocationLookupService.searchAddress(val.trim());
                          if (ctx.mounted) {
                            setSheetState(() => liveSuggestions = results);
                          }
                        } else {
                          if (liveSuggestions.isNotEmpty && ctx.mounted) {
                            setSheetState(() => liveSuggestions = []);
                          }
                        }
                      },
                      onSubmitted: (val) => Navigator.of(ctx).pop(val.trim()),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.ustaPrimary),
                        hintText: 'Şehir, İlçe veya Mahalle ara...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.ustaPrimary, width: 2),
                        ),
                      ),
                    ),
                    if (liveSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: liveSuggestions.length,
                          separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 1),
                          itemBuilder: (context, index) {
                            final sug = liveSuggestions[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.place_rounded, size: 18, color: AppTheme.ustaPrimary),
                              title: Text(
                                sug.shortLabel,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                              subtitle: Text(
                                sug.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                              onTap: () => Navigator.of(ctx).pop(sug.label),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.of(ctx).pop(textController.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.ustaPrimary,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Konumu Güncelle',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null && selected.isNotEmpty) {
      if (selected == '__USE_GPS__') {
        final success = await controller.useCurrentGpsLocation();
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GPS konumu alınamadı. Lütfen konum izinlerini kontrol edin.')),
          );
        }
      } else {
        await controller.setUstaLocation(address: selected);
      }
    }
  }

  /// 1.1 Çalışma Saatleri & Nöbet Modu Kartı (Taşmasız, Tam Responsive & Etkileşimli)
  Widget _buildWorkingHoursAndDutyCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.schedule_rounded, color: Color(0xFF0F172A), size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Çalışma Saatleri & Nöbet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Mesai ve acil gece nöbeti',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                decoration: BoxDecoration(
                  color: _isOnDutyNight
                      ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                      : const Color(0xFF64748B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 13,
                      color: _isOnDutyNight ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _isOnDutyNight ? 'Nöbetçi' : 'Standart',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: _isOnDutyNight ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 15, color: Color(0xFF0284C7)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '$_workStartHour - $_workEndHour ${_worksWeekend ? '(Hergün)' : '(Hafta İçi)'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                ),
                onPressed: _showWorkingHoursDialog,
                child: const Text('Düzenle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showWorkingHoursDialog() {
    String tempStart = _workStartHour;
    String tempEnd = _workEndHour;
    bool tempDuty = _isOnDutyNight;
    bool tempWeekend = _worksWeekend;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.schedule_rounded, color: Color(0xFFEA580C), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Çalışma Saatleri & Nöbet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GÜNLÜK MESAİ ARALIĞI',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: tempStart,
                            dropdownColor: Colors.white,
                            style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 13),
                            items: ['07:00', '08:00', '08:30', '09:00', '10:00']
                                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => tempStart = val);
                            },
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('-', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: tempEnd,
                            dropdownColor: Colors.white,
                            style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 13),
                            items: ['17:00', '18:00', '19:00', '20:00', '21:00', '22:00', '23:00']
                                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => tempEnd = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'ÖZEL ÇALIŞMA TERCİHLERİ',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Acil Gece Nöbetçisi Ol',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text(
                          '20:00 sonrası acil çağrılarda ek tarife uygulanır',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        ),
                        value: tempDuty,
                        activeColor: const Color(0xFFEA580C),
                        onChanged: (val) => setDialogState(() => tempDuty = val),
                      ),
                      const Divider(color: Color(0xFFE2E8F0), height: 1),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Hafta Sonu Hizmet Ver',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text(
                          'Cumartesi ve Pazar günleri haritada listelenir',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        ),
                        value: tempWeekend,
                        activeColor: const Color(0xFFEA580C),
                        onChanged: (val) => setDialogState(() => tempWeekend = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.ustaPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () {
                setState(() {
                  _workStartHour = tempStart;
                  _workEndHour = tempEnd;
                  _isOnDutyNight = tempDuty;
                  _worksWeekend = tempWeekend;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Çalışma saatleri ve nöbet ayarlarınız güncellendi!'),
                    backgroundColor: Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// 1.1 Usta Cüzdanı & Hakediş Hızlı Erişim Kartı
  Widget _buildWalletBannerCard(UstaDashboardState state) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppTheme.ustaPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.ustaPrimary.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: AppTheme.ustaPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'Usta Cüzdanı & Hakediş',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 5),
                    Icon(Icons.shield_rounded, color: Color(0xFF4ADE80), size: 13),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Aktif Hakediş: ${state.weeklyEarnings.toStringAsFixed(0)} ₺ • İyzico Korumalı',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => context.push('/usta/wallet'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.ustaPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cüzdan',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 3),
                Icon(Icons.arrow_forward_ios_rounded, size: 9),
              ],
            ),
          ),
        ],
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
                subtitle: '${state.dailyCompletedJobs} İş • 7 Gün Blokeli',
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF16A34A),
                accentColor: const Color(0xFF15803D),
                onTap: () => context.push('/usta/wallet'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                title: 'Haftalık Hakediş',
                value: '${state.weeklyEarnings.toStringAsFixed(0)} ₺',
                subtitle: '7 Gün Provizyon Korumalı',
                icon: Icons.trending_up_rounded,
                iconColor: AppTheme.ustaPrimary,
                accentColor: AppTheme.ustaPrimary,
                onTap: () => context.push('/usta/wallet'),
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
                iconColor: const Color(0xFFD97706),
                accentColor: const Color(0xFF0F172A),
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
                accentColor: const Color(0xFF0F172A),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_rounded,
                        size: 20, color: AppTheme.ustaPrimary),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Hizmet & İlan Tarifem',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text(
                  'Yeni Hizmet Ekle',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Müşterilerin harita panelinde göreceği hizmet ilanlarınız. Fiyat ve süreleri özelleştirebilirsiniz:',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          if (state.hizmetler.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text(
                  'Henüz özel hizmet eklemediniz. "+ Yeni Hizmet Ekle" ile tarifenizi oluşturun.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hizmet.isDefault
                          ? AppTheme.ustaPrimary.withValues(alpha: 0.5)
                          : const Color(0xFFE2E8F0),
                      width: hizmet.isDefault ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                if (hizmet.kategori != null &&
                                    hizmet.kategori!.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      hizmet.kategori!,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF475569),
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
                                          .withValues(alpha: 0.12),
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
                                  fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            if (hizmet.konum != null &&
                                hizmet.konum!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded,
                                      size: 12, color: AppTheme.ustaPrimary),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      hizmet.konum!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.ustaPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
                              color: AppTheme.ustaPrimary,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 16, color: Color(0xFF64748B)),
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
    final tabanVal = double.tryParse(_tabanFeeController.text.trim()) ?? state.servisUcreti;
    final kmVal = double.tryParse(_kmFeeController.text.trim()) ?? state.kmBasiYakitUcreti;
    final freeKmVal = double.tryParse(_freeKmController.text.trim()) ?? state.ucretsizMesafeKm;
    final emergencyVal = double.tryParse(_emergencyFeeController.text.trim()) ?? state.acilGeceUcreti;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, size: 20, color: AppTheme.ustaPrimary),
              SizedBox(width: 8),
              Text(
                'Ayrıntılı Fiyatlandırma & Yakıt Tarifesi',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Uzak adrese giderken kilometre başına yakıt ve gece tarifesi ekleyerek hakedişinizi optimize edin:',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          // 1. Satır: Taban Servis & Km Başı Yakıt Ücreti
          Row(
            children: [
              Expanded(
                child: _TarifeInputField(
                  controller: _tabanFeeController,
                  focusNode: _tabanFocusNode,
                  label: 'Taban Servis Ücreti',
                  suffix: '₺',
                  hint: 'Örn: 750',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TarifeInputField(
                  controller: _kmFeeController,
                  focusNode: _kmFocusNode,
                  label: 'Km Başı Yakıt / Ulaşım',
                  suffix: '₺/km',
                  hint: 'Örn: 15',
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
                  focusNode: _freeKmFocusNode,
                  label: 'Ücretsiz Yarıçap (Tabana Dahil)',
                  suffix: 'km',
                  hint: 'Örn: 3',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TarifeInputField(
                  controller: _emergencyFeeController,
                  focusNode: _emergencyFocusNode,
                  label: 'Gece / Acil Ek Ücreti',
                  suffix: '₺',
                  hint: 'Örn: 200',
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
                    color: Color(0xFF334155)),
              ),
              Text(
                '${_radiusKm.toStringAsFixed(0)} km',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.ustaPrimary),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.ustaPrimary,
              inactiveTrackColor: const Color(0xFFE2E8F0),
              thumbColor: AppTheme.ustaPrimary,
              overlayColor: AppTheme.ustaPrimary.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _radiusKm,
              min: 5.0,
              max: 50.0,
              divisions: 9,
              onChanged: (val) => setState(() => _radiusKm = val),
            ),
          ),

          // Canlı Tarife Formülü Bilgi Kutusu
          Builder(
            builder: (context) {
              final isFormEmpty = _tabanFeeController.text.trim().isEmpty && !state.hasCustomTarife;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_outlined,
                        size: 20, color: AppTheme.ustaPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isFormEmpty
                            ? 'Henüz tarife belirlemediniz. Lütfen ücretlerinizi girip kaydedin.'
                            : 'Aktif Tarife: ${tabanVal > 0 ? tabanVal.toStringAsFixed(0) : "0"} ₺ taban (${freeKmVal.toStringAsFixed(0)} km dahil) • Ek her km için +${kmVal.toStringAsFixed(0)} ₺/km • Acil/Gece: +${emergencyVal.toStringAsFixed(0)} ₺ • Menzil: ${_radiusKm.toStringAsFixed(0)} km',
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9A3412)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Tarifeyi Kaydet Butonu
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: state.isSavingFee
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 18, color: Colors.white),
              onPressed: state.isSavingFee
                  ? null
                  : () async {
                      final tabanText = _tabanFeeController.text.trim();
                      if (tabanText.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Lütfen taban servis ücretini girin.'),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      final taban = double.tryParse(tabanText) ?? 0.0;
                      final kmFee = double.tryParse(_kmFeeController.text.trim()) ?? 0.0;
                      final freeKm = double.tryParse(_freeKmController.text.trim()) ?? 0.0;
                      final emergency = double.tryParse(_emergencyFeeController.text.trim()) ?? 0.0;

                      final success = await controller.updateTarifeAyarlari(
                        tabanServis: taban,
                        kmBasiYakit: kmFee,
                        ucretsizMesafeKm: freeKm,
                        acilGeceUcreti: emergency,
                        calismaYaricapiKm: _radiusKm,
                      );
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.white),
                                SizedBox(width: 8),
                                Expanded(child: Text('Tarife ve yakıt ayarlarınız kalıcı olarak kaydedildi!')),
                              ],
                            ),
                            backgroundColor: Color(0xFF15803D),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.ustaPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              label: Text(
                state.isSavingFee
                    ? 'Kaydediliyor...'
                    : 'Tarife & Yakıt Ayarlarını Kaydet',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                  color: Color(0xFF0F172A)),
            ),
            if (state.isOnline)
              InkWell(
                onTap: () => controller.simulateIncomingCall(),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.ustaPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.ustaPrimary.withValues(alpha: 0.3)),
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
          _buildLiveCallsList(state),
      ],
    );
  }

  Widget _buildOfflineNotice(UstaDashboardController controller) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                  color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Yakındaki müşterilerin çağrılarını alabilmek için yukarıdan müsaitlik durumunuzu "Müsaitim" yapın.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => controller.toggleOnlineStatus(true),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(180, 44),
                  foregroundColor: const Color(0xFF16A34A),
                  side: const BorderSide(color: Color(0xFF16A34A)),
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

  Widget _buildLiveCallsList(UstaDashboardState state) {
    final controller = ref.read(ustaDashboardControllerProvider.notifier);

    if (state.pendingCalls.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.radar_rounded, size: 36, color: AppTheme.ustaPrimary),
              SizedBox(height: 10),
              Text(
                'Bekleyen Yeni Çağrı Bulunmuyor',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Bölgenizdeki müşterilerden arıza veya hizmet talebi geldiğinde çağrılar anında burada listelenir.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: state.pendingCalls.map((call) {
        final meters = call.distanceInMetersFrom(state.ustaLat, state.ustaLng);
        final distanceText = meters < 1000
            ? '${meters.round()} m'
            : '${(meters / 1000).toStringAsFixed(1)} km';

        final rawAdres = call.adresTarifi ?? 'Acil Servis Talebi';
        final title = rawAdres.contains('•')
            ? rawAdres.split('•').first.trim()
            : (rawAdres.isNotEmpty ? rawAdres : 'Acil Hizmet Talebi');
        final address =
            rawAdres.contains('•') ? rawAdres.split('•').last.trim() : rawAdres;
        final fee = call.ustaHakedis ?? state.servisUcreti;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildCallItem(
            title: title,
            customer: call.musteriFullName?.isNotEmpty == true
                ? call.musteriFullName!
                : 'Müşteri',
            address: address,
            distance: distanceText,
            fee: '${fee.toStringAsFixed(0)} ₺',
            note: rawAdres,
            onAccept: () async {
              final success = await controller.acceptIncomingCall(call.id);
              if (mounted && success) {
                context.push('/usta/active-job/${call.id}');
              }
            },
          ),
        );
      }).toList(),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                      color: Color(0xFF0F172A)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  widget.distance,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.ustaPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(widget.customer,
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF64748B))),
              const SizedBox(width: 10),
              const Icon(Icons.location_on_outlined,
                  size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              '📝 ${widget.note}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
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
                          TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  Text(
                    widget.fee,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.ustaPrimary),
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
  final VoidCallback? onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
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
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B)),
                  ),
                  Icon(icon, size: 20, color: iconColor),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: accentColor),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ),
                  if (onTap != null)
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: Color(0xFFCBD5E1),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarifeInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String suffix;
  final String hint;

  const _TarifeInputField({
    required this.controller,
    this.focusNode,
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
              color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            suffixText: suffix,
            suffixStyle: const TextStyle(
                color: AppTheme.ustaPrimary, fontWeight: FontWeight.bold),
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.ustaPrimary, width: 2.0),
            ),
          ),
        ),
      ],
    );
  }
}
