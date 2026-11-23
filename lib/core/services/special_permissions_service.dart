import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ustaapp/core/theme/app_theme.dart';

class SpecialPermissionsService {
  SpecialPermissionsService._();
  static final SpecialPermissionsService instance = SpecialPermissionsService._();

  static const MethodChannel _channel = MethodChannel('com.example.ustaapp/call_screen');

  /// Android üzerindeki kritik izinlerin durumunu kontrol eder
  Future<Map<String, bool>> checkPermissions() async {
    if (kIsWeb || !Platform.isAndroid) {
      return {'overlay': true, 'battery': true};
    }
    try {
      final res = await _channel.invokeMethod<Map>('checkSpecialPermissions');
      if (res != null) {
        return {
          'overlay': res['overlay'] == true,
          'battery': res['battery'] == true,
        };
      }
    } catch (e) {
      debugPrint('[SpecialPermissionsService] İzin kontrol hatası: $e');
    }
    return {'overlay': false, 'battery': false};
  }

  /// 1. Pil optimizasyonu muafiyeti ister (Resmi Android sistem popup'ı açar)
  Future<bool> requestBatteryOptimization() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('requestBatteryOptimization');
      return res == true;
    } catch (e) {
      debugPrint('[SpecialPermissionsService] Pil optimizasyon isteği hatası: $e');
      return false;
    }
  }

  /// 2. Diğer uygulamaların üzerinde göster / Kayan pencere izni ister (Doğrudan anahtara götürür)
  Future<bool> requestOverlayPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('requestOverlayPermission');
      return res == true;
    } catch (e) {
      debugPrint('[SpecialPermissionsService] Kayan pencere isteği hatası: $e');
      return false;
    }
  }

  /// Eğer usta için kritik izinlerden biri eksikse modern bilgilendirme kartını açar
  Future<void> showPermissionSheetIfNeeded(BuildContext context) async {
    if (kIsWeb || !Platform.isAndroid) return;

    final perms = await checkPermissions();
    final hasOverlay = perms['overlay'] == true;
    final hasBattery = perms['battery'] == true;

    // Eğer her iki izin de verilmişse rahatsız etme
    if (hasOverlay && hasBattery) return;

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _SpecialPermissionsSheet(),
    );
  }
}

class _SpecialPermissionsSheet extends StatefulWidget {
  const _SpecialPermissionsSheet();

  @override
  State<_SpecialPermissionsSheet> createState() => _SpecialPermissionsSheetState();
}

class _SpecialPermissionsSheetState extends State<_SpecialPermissionsSheet> with WidgetsBindingObserver {
  bool _overlayGranted = false;
  bool _batteryGranted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  Future<void> _refreshPermissions() async {
    final perms = await SpecialPermissionsService.instance.checkPermissions();
    if (mounted) {
      setState(() {
        _overlayGranted = perms['overlay'] == true;
        _batteryGranted = perms['battery'] == true;
        _isLoading = false;
      });

      // İkisi de tamamlandıysa 1 saniye sonra otomatik kapat
      if (_overlayGranted && _batteryGranted) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allDone = _overlayGranted && _batteryGranted;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tutamaç
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Başlık
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.ustaPrimary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: AppTheme.ustaPrimary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kesintisiz Çağrı Alma İzinleri',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Ekran kapalıyken çağrıları kaçırmamak için:',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppTheme.ustaPrimary),
              ),
            )
          else ...[
            // 1. Pil Tasarrufu İzni Kartı
            _buildPermissionCard(
              title: '1. Arka Planda Çalışma (Pil Tasarrufu)',
              desc: 'Uygulama kapalıyken gelen çağrıların anında düşmesini sağlar.',
              icon: Icons.battery_charging_full_rounded,
              isGranted: _batteryGranted,
              buttonText: 'Hemen Onayla',
              onTap: () async {
                await SpecialPermissionsService.instance.requestBatteryOptimization();
                await Future.delayed(const Duration(milliseconds: 600));
                _refreshPermissions();
              },
            ),
            const SizedBox(height: 12),

            // 2. Kilit Ekranı & Kayan Pencere Kartı
            _buildPermissionCard(
              title: '2. Kilit Ekranında Tam Ekran Çağrı',
              desc: 'Telefon kilitliyken bile çağrının ekrana anında arama gibi çıkmasını sağlar.',
              icon: Icons.picture_in_picture_alt_rounded,
              isGranted: _overlayGranted,
              buttonText: 'Ayarları Aç',
              onTap: () async {
                await SpecialPermissionsService.instance.requestOverlayPermission();
                await Future.delayed(const Duration(milliseconds: 600));
                _refreshPermissions();
              },
            ),
            const SizedBox(height: 24),

            // Tamamlandı Bilgisi veya Kapat
            if (allDone)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Tüm İzinler Aktif! Çağrılar anında çalacak.',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            else
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white12,
                  foregroundColor: Colors.white70,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Şimdilik Geç'),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String desc,
    required IconData icon,
    required bool isGranted,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGranted ? const Color(0xFF10B981).withValues(alpha: 0.5) : Colors.white12,
          width: isGranted ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isGranted
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : AppTheme.ustaPrimary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGranted ? Icons.check_circle_rounded : icon,
              color: isGranted ? const Color(0xFF10B981) : AppTheme.ustaPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isGranted)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 18),
                SizedBox(width: 4),
                Text(
                  'Aktif',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ],
            )
          else
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.ustaPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                buttonText,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
