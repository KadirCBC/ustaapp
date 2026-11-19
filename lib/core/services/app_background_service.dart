import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/app_notification_model.dart';
import 'notification_service.dart';

class AppBackgroundService {
  AppBackgroundService._();
  static final AppBackgroundService instance = AppBackgroundService._();

  static const String serviceChannelId = 'ustam_bg_service_channel';
  static const String serviceChannelName = 'UstamBurada Arka Plan Servisi';

  Future<void> initialize() async {
    if (kIsWeb) return;

    try {
      final service = FlutterBackgroundService();

      if (Platform.isAndroid) {
        final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          serviceChannelId,
          serviceChannelName,
          description: 'Uygulama kapalıyken usta varış ve anlık bildirimleri dinler.',
          importance: Importance.low,
          showBadge: false,
        );

        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onBackgroundServiceStart,
          autoStart: true,
          isForegroundMode: true,
          notificationChannelId: serviceChannelId,
          initialNotificationTitle: 'UstamBurada',
          initialNotificationContent: 'Canlı bildirim ve servis takibi devrede',
          foregroundServiceTypes: [
            AndroidForegroundType.dataSync,
            AndroidForegroundType.remoteMessaging,
          ],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: true,
          onForeground: onBackgroundServiceStart,
          onBackground: onIosBackground,
        ),
      );

      final isRunning = await service.isRunning();
      if (!isRunning) {
        await service.startService();
      }
      debugPrint('[AppBackgroundService] Arka plan servisi yapılandırıldı ve başlatıldı.');
    } catch (e) {
      debugPrint('[AppBackgroundService] Başlatma hatası: $e');
    }
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  // Bildirim servisini arka plan izolatında da hazırla
  await NotificationService.instance.initialize();

  debugPrint('[BackgroundService] Arka plan dinleyici izolatı aktif edildi.');

  // Kalıcı dinleme döngüsü (WebSocket)
  _startPersistentWebSocketListener();
}

void _startPersistentWebSocketListener() async {
  final handledArrivalIds = <String>{};

  while (true) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customHost = prefs.getString('app_custom_sync_host');
      final host = (customHost != null && customHost.isNotEmpty)
          ? customHost.trim()
          : (Platform.isAndroid ? '192.168.1.101' : 'localhost');

      final wsUrl = 'ws://$host:8090/ws';
      debugPrint('[BackgroundService] WebSocket bağlantısı kuruluyor: $wsUrl');

      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      await for (final rawMessage in channel.stream) {
        try {
          final msg = jsonDecode(rawMessage.toString()) as Map<String, dynamic>;
          final event = msg['event']?.toString() ?? '';
          final data = msg['data'];

          // 1. Usta Adrese Vardı Bildirimi (🚨 Kilitli ekranı uyandırır)
          if (event == 'usta_arrived' && data is Map) {
            final arrivalData = Map<String, dynamic>.from(data);
            final cid = arrivalData['cagri_id']?.toString() ?? '';
            if (cid.isNotEmpty && !handledArrivalIds.contains(cid)) {
              handledArrivalIds.add(cid);

              // Aktif kullanıcı rolünü kontrol et
              final sessionRaw = prefs.getString('app_active_session');
              final role = sessionRaw != null
                  ? (jsonDecode(sessionRaw)['role']?.toString().toLowerCase())
                  : null;

              if (role != 'usta') {
                final ustaName = arrivalData['usta_name']?.toString() ?? 'Ustanız';
                await NotificationService.instance.showUstaArrived(
                  ustaName: ustaName,
                  cagriId: cid,
                  address: arrivalData['address']?.toString(),
                );
              }
            }
          } else if (event == 'cagri_updated' && data is Map) {
            final cagriMap = Map<String, dynamic>.from(data);
            final id = cagriMap['id']?.toString() ?? '';
            final isAdreste = cagriMap['durum'] == 'adreste' ||
                cagriMap['usta_arrived'] == true;

            if (isAdreste && id.isNotEmpty && !handledArrivalIds.contains(id)) {
              handledArrivalIds.add(id);

              final sessionRaw = prefs.getString('app_active_session');
              final role = sessionRaw != null
                  ? (jsonDecode(sessionRaw)['role']?.toString().toLowerCase())
                  : null;

              if (role != 'usta') {
                final ustaName =
                    cagriMap['usta_name'] ?? cagriMap['ustaName'] ?? 'Ustanız';
                await NotificationService.instance.showUstaArrived(
                  ustaName: ustaName.toString(),
                  cagriId: id,
                  address: cagriMap['address']?.toString(),
                );
              }
            }
          } else if (event == 'system_notification' && data is Map) {
            // 2. Admin Canlı Push Bildirimi (📢 Sistem duyurusu / güncelleme)
            final notifMap = Map<String, dynamic>.from(data);
            final notif = AppNotificationModel.fromJson(notifMap);

            final sessionRaw = prefs.getString('app_active_session');
            Map<String, dynamic>? session;
            if (sessionRaw != null) {
              try {
                session = Map<String, dynamic>.from(jsonDecode(sessionRaw) as Map);
              } catch (_) {}
            }

            final currentRole = session?['role']?.toString().toLowerCase();
            final currentPhone = session?['phone']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';

            bool isTargeted = false;
            if (notif.target == 'all') {
              isTargeted = true;
            } else if (notif.target == 'ustalar' && currentRole == 'usta') {
              isTargeted = true;
            } else if (notif.target == 'musteriler' && currentRole != 'usta') {
              isTargeted = true;
            } else if (notif.target == 'user' && notif.targetPhone != null) {
              final normTarget = notif.targetPhone!.replaceAll(RegExp(r'[^0-9]'), '');
              if (normTarget.isNotEmpty && normTarget == currentPhone) {
                isTargeted = true;
              }
            }

            if (isTargeted) {
              await NotificationService.instance.showBroadcastNotification(notif);
            }
          }
        } catch (e) {
          debugPrint('[BackgroundService] Mesaj işleme hatası: $e');
        }
      }
    } catch (e) {
      debugPrint('[BackgroundService] WS bağlantı koptu, 5 sn sonra yeniden denenecek: $e');
    }

    // Bağlantı koptuğunda 5 saniye bekle ve tekrar bağlan
    await Future.delayed(const Duration(seconds: 5));
  }
}
