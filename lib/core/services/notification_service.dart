import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ustaapp/core/router/app_router.dart';
import 'package:ustaapp/core/services/app_data_service.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';
import '../models/app_notification_model.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final ValueNotifier<List<AppNotificationModel>> notificationsNotifier =
      ValueNotifier<List<AppNotificationModel>>([]);

  bool _initialized = false;
  static const String _prefsKey = 'ustam_saved_notifications';

  static const String channelUrgentId = 'ustam_urgent_arrival_v4';
  static const String channelUrgentName = '🚨 Usta Kapıda & Acil Bildirimler';
  static const String channelUrgentDesc =
      'Ustanız adrese ulaştığında veya acil durumlarda sesli ve kilit ekranı uyarısı verir.';

  static const String channelIncomingCallId = 'ustam_incoming_call_v5';
  static const String channelIncomingCallName = '🔔 Gelen Usta Çağrıları';
  static const String channelIncomingCallDesc =
      'Müşterilerden yeni bir acil servis veya arıza çağrısı geldiğinde özel zil sesi ile çalar.';

  static const String channelBroadcastId = 'ustam_broadcasts';
  static const String channelBroadcastName = '📢 UstaGelio Duyurular & Güncellemeler';
  static const String channelBroadcastDesc =
      'Yönetim paneli duyuruları, yeni özellikler ve sistem güncellemeleri.';

  int get unreadCount =>
      notificationsNotifier.value.where((n) => !n.isRead).length;

  Future<void> initialize({bool isBackground = false}) async {
    if (_initialized && !isBackground) return;

    await _loadSavedNotifications();

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          debugPrint('[NotificationService] Bildirime tıklandı: ${details.payload}, actionId: ${details.actionId}');
          if (details.actionId == 'reject_call') {
            _handleRejectAction(details.payload);
          } else {
            _handleNotificationPayload(details.payload);
          }
        },
      );

      if (Platform.isAndroid) {
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        // 1. Android 13+ Bildirim ve Alarm İzinleri İste (Sadece UI izolatında, Activity varsa çağrılır)
        if (!isBackground) {
          try {
            await androidImplementation?.requestNotificationsPermission();
            await androidImplementation?.requestExactAlarmsPermission();
          } catch (permErr) {
            debugPrint('[NotificationService] İzin isteme uyarısı: $permErr');
          }
        }

        // 2. Acil Usta Varış Bildirim Kanalı (Kilit ekranında uyandırır & yüksek öncelikli ses)
        final urgentVibration = Int64List.fromList([0, 1000, 300, 1000, 300, 1500]);
        final AndroidNotificationChannel urgentChannel = AndroidNotificationChannel(
          channelUrgentId,
          channelUrgentName,
          description: channelUrgentDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: urgentVibration,
          showBadge: true,
        );

        // 3. Gelen Usta Çağrısı Özel Zil Sesi Kanalı
        final AndroidNotificationChannel callChannel = AndroidNotificationChannel(
          channelIncomingCallId,
          channelIncomingCallName,
          description: channelIncomingCallDesc,
          importance: Importance.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('cagri_sesi'),
          enableVibration: true,
          vibrationPattern: urgentVibration,
          showBadge: true,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
        );

        // 4. Genel Duyuru ve Güncelleme Kanalı
        final AndroidNotificationChannel broadcastChannel = AndroidNotificationChannel(
          channelBroadcastId,
          channelBroadcastName,
          description: channelBroadcastDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );

        await androidImplementation?.createNotificationChannel(urgentChannel);
        await androidImplementation?.createNotificationChannel(callChannel);
        await androidImplementation?.createNotificationChannel(broadcastChannel);
      }

      _initialized = true;
      debugPrint('[NotificationService] Yerel bildirim servisi başarıyla başlatıldı (isBackground=$isBackground).');
    } catch (e) {
      debugPrint('[NotificationService] Başlatma hatası: $e');
    }
  }

  /// 🚨 USTA ADRESE ULAŞTIĞINDA ÇAĞRILIR (Kilitli ekranda sesli ve öncelikli)
  Future<void> showUstaArrived({
    required String ustaName,
    required String cagriId,
    String? address,
  }) async {
    final title = '🚨 USTANIZ KAPIDA!';
    final body = '$ustaName adresinize ulaştı! Lütfen kapıyı açınız, usta kapıda beklemesin.';

    // Listeye kaydet
    final notif = AppNotificationModel(
      id: 'arrived_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: body,
      type: 'arrived',
      target: 'musteriler',
      isUrgent: true,
      createdAt: DateTime.now(),
      data: {'cagri_id': cagriId, 'usta_name': ustaName, 'address': address},
    );
    await addNotification(notif);

    // Titreşim ve Sistem sesi
    try {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}

    if (kIsWeb) return;

    try {
      final urgentVibration = Int64List.fromList([0, 1000, 300, 1000, 300, 1500]);
      final androidDetails = AndroidNotificationDetails(
        channelUrgentId,
        channelUrgentName,
        channelDescription: channelUrgentDesc,
        color: const Color(0xFFF97316),
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: urgentVibration,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public, // Kilit ekranında tam görünürlük
        category: AndroidNotificationCategory.alarm,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'UstaGelio Adrese Varış',
        ),
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );

      final notifId = DateTime.now().millisecondsSinceEpoch % 100000;
      await _notificationsPlugin.show(
        id: notifId,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: jsonEncode(notif.toJson()),
      );
    } catch (e) {
      debugPrint('[NotificationService] Usta bildirim hatası: $e');
    }
  }

  /// 🔔 YENİ MÜŞTERİ ÇAĞRISI GELDİĞİNDE ÖZEL ZİL SESİYLE ÇAĞRILIR
  Future<void> showIncomingCallNotification({
    required String cagriId,
    required String customerName,
    required String serviceTitle,
    required double price,
    String? address,
  }) async {
    // 1. Hizmet başlığını profesyonelce temizle
    String cleanService = serviceTitle
        .replaceAll(RegExp(r'📋\s*Seçilen Hizmet:\s*', caseSensitive: false), '')
        .trim();
    cleanService = cleanService.replaceAll(RegExp(r'\(\s*\d+\s*₺?\s*\)'), '').trim();
    if (cleanService.isEmpty) cleanService = 'Acil Usta Hizmeti';

    final priceStr = price > 0 ? '${price.toStringAsFixed(0)} ₺' : '';
    final title = '⚡ Yeni Çağrı: $cleanService';

    String cleanAddr = (address != null && address.trim().isNotEmpty) ? address.trim() : '';
    if (cleanAddr.startsWith('📍')) cleanAddr = cleanAddr.substring(1).trim();

    final body = cleanAddr.isNotEmpty
        ? 'Müşteri: $customerName • $priceStr\n📍 $cleanAddr'
        : 'Müşteri: $customerName • $priceStr';

    final notif = AppNotificationModel(
      id: 'call_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: body,
      type: 'call',
      target: 'ustalar',
      isUrgent: true,
      createdAt: DateTime.now(),
      data: {'cagri_id': cagriId, 'customer_name': customerName, 'price': price, 'address': address},
    );
    await addNotification(notif);

    if (kIsWeb) return;

    if (Platform.isAndroid) {
      try {
        const MethodChannel('com.example.ustaapp/call_screen')
            .invokeMethod('wakeScreenAndUnlock', {'cagri_id': cagriId});
      } catch (_) {}
    }

    try {
      final urgentVibration = Int64List.fromList([0, 1000, 300, 1000, 300, 1500, 300, 2000]);
      final androidDetails = AndroidNotificationDetails(
        channelIncomingCallId,
        channelIncomingCallName,
        channelDescription: channelIncomingCallDesc,
        color: const Color(0xFFF97316),
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('cagri_sesi'),
        enableVibration: true,
        vibrationPattern: urgentVibration,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.call,
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
        ongoing: true,
        autoCancel: false,
        ticker: '🚨 Yeni Usta Çağrısı: $cleanService',
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            'accept_call',
            'Kabul Et',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'reject_call',
            'Reddet',
            cancelNotification: true,
          ),
        ],
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: priceStr.isNotEmpty ? 'Kazanç: $priceStr' : 'Yeni İş Fırsatı',
        ),
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          sound: 'cagri_sesi.mp3',
          presentBadge: true,
          interruptionLevel: InterruptionLevel.critical,
        ),
      );

      final notifId = cagriId.hashCode.abs() % 100000;
      await _notificationsPlugin.show(
        id: notifId,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: jsonEncode(notif.toJson()),
      );

      // Sunucuya bildirimin başarıyla basıldığını ilet
      try {
        final prefs = await SharedPreferences.getInstance();
        final customHost = prefs.getString('app_custom_sync_host');
        final host = (customHost != null && customHost.isNotEmpty)
            ? customHost.trim()
            : (Platform.isAndroid ? '192.168.1.101' : 'localhost');
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 2);
        final req = await client.getUrl(Uri.parse('http://$host:8090/api/debug_log?msg=NOTIF_SHOW_OK_$cagriId'));
        final res = await req.close();
        await res.drain();
        client.close();
      } catch (_) {}
    } catch (e) {
      debugPrint('[NotificationService] Gelen çağrı bildirim hatası: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        final customHost = prefs.getString('app_custom_sync_host');
        final host = (customHost != null && customHost.isNotEmpty)
            ? customHost.trim()
            : (Platform.isAndroid ? '192.168.1.101' : 'localhost');
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 2);
        final req = await client.getUrl(Uri.parse('http://$host:8090/api/debug_log?msg=NOTIF_SHOW_ERR_${Uri.encodeComponent(e.toString())}'));
        final res = await req.close();
        await res.drain();
        client.close();
      } catch (_) {}
    }
  }

  /// Belirli bir çağrı bildirimini iptal etme / susturma
  Future<void> cancelCallNotification(String cagriId) async {
    if (kIsWeb) return;
    try {
      final notifId = cagriId.hashCode.abs() % 100000;
      await _notificationsPlugin.cancel(id: notifId);
    } catch (_) {}
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('stop_bg_sound');
      }
    } catch (_) {}
    try {
      const MethodChannel('com.example.ustaapp/call_screen')
          .invokeMethod('stopRinging');
    } catch (_) {}
  }

  /// 📢 ADMİN VEYA SİSTEM DUYURUSU/GÜNCELLEMESİ GELDİĞİNDE ÇAĞRILIR
  Future<void> showBroadcastNotification(AppNotificationModel notif) async {
    await addNotification(notif);

    try {
      if (notif.isUrgent) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      } else {
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);
      }
    } catch (_) {}

    if (kIsWeb) return;

    try {
      final channelId = notif.isUrgent ? channelUrgentId : channelBroadcastId;
      final channelName = notif.isUrgent ? channelUrgentName : channelBroadcastName;
      final channelDesc = notif.isUrgent ? channelUrgentDesc : channelBroadcastDesc;

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        color: const Color(0xFFF97316),
        importance: notif.isUrgent ? Importance.max : Importance.high,
        priority: notif.isUrgent ? Priority.high : Priority.defaultPriority,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        category: notif.isUrgent
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.reminder,
        styleInformation: BigTextStyleInformation(
          notif.message,
          contentTitle: notif.title,
          summaryText: _getNotificationCategorySummary(notif.type),
        ),
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
          interruptionLevel: notif.isUrgent
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
        ),
      );

      final notifId = notif.id.hashCode.abs() % 100000;
      await _notificationsPlugin.show(
        id: notifId,
        title: notif.title,
        body: notif.message,
        notificationDetails: notificationDetails,
        payload: jsonEncode(notif.toJson()),
      );
    } catch (e) {
      debugPrint('[NotificationService] Broadcast bildirim hatası: $e');
    }
  }

  String _getNotificationCategorySummary(String type) {
    switch (type) {
      case 'arrived':
        return 'Usta Varışı';
      case 'update':
        return 'Sistem Güncellemesi';
      case 'feature':
        return 'Yeni Geliştirme';
      case 'warning':
        return 'Önemli Uyarı';
      case 'pricing':
        return 'Tarife Düzenlemesi';
      default:
        return 'UstaGelio Duyuru';
    }
  }

  Future<void> addNotification(AppNotificationModel notif) async {
    final List<AppNotificationModel> list = [];
    final dynamic rawList = notificationsNotifier.value;
    if (rawList is Iterable) {
      for (final dynamic item in rawList) {
        if (item is AppNotificationModel) {
          list.add(item);
        } else if (item is Map) {
          try {
            list.add(AppNotificationModel.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
      }
    }
    // Duplicate ID kontrolü
    if (list.any((item) => item.id == notif.id)) {
      return;
    }
    list.insert(0, notif);
    notificationsNotifier.value = list;
    await _saveNotificationsToPrefs();
  }

  Future<void> markAsRead(String id) async {
    final list = List<AppNotificationModel>.from(notificationsNotifier.value);
    final idx = list.indexWhere((n) => n.id == id);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(isRead: true);
      notificationsNotifier.value = list;
      await _saveNotificationsToPrefs();
    }
  }

  Future<void> markAllAsRead() async {
    final list = notificationsNotifier.value
        .map((n) => n.copyWith(isRead: true))
        .toList();
    notificationsNotifier.value = list;
    await _saveNotificationsToPrefs();
  }

  Future<void> clearAll() async {
    notificationsNotifier.value = [];
    await _saveNotificationsToPrefs();
  }

  Future<void> _loadSavedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final List<AppNotificationModel> list = [];
          for (final item in decoded) {
            if (item is Map) {
              try {
                list.add(AppNotificationModel.fromJson(Map<String, dynamic>.from(item)));
              } catch (_) {}
            }
          }
          notificationsNotifier.value = list;
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Bildirimleri yükleme hatası: $e');
    }
  }

  Future<void> _saveNotificationsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = notificationsNotifier.value.map((n) => n.toJson()).toList();
      await prefs.setString(_prefsKey, jsonEncode(data));
    } catch (e) {
      debugPrint('[NotificationService] Bildirimleri kaydetme hatası: $e');
    }
  }

  void _handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final type = map['type']?.toString();
      final data = map['data'] as Map<String, dynamic>?;
      final cagriId = data?['cagri_id']?.toString() ?? map['cagri_id']?.toString();
      if ((type == 'call' || cagriId != null) && cagriId != null && cagriId.isNotEmpty) {
        if (globalGoRouter != null) {
          globalGoRouter!.push('/usta/incoming-call/$cagriId');
        } else {
          final ctx = rootNavigatorKey.currentContext;
          if (ctx != null) {
            GoRouter.of(ctx).push('/usta/incoming-call/$cagriId');
          }
        }
      }
    } catch (_) {}
  }

  void _handleRejectAction(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final data = map['data'] as Map<String, dynamic>?;
      final cagriId = data?['cagri_id']?.toString() ?? map['cagri_id']?.toString();
      if (cagriId != null && cagriId.isNotEmpty) {
        cancelCallNotification(cagriId);
        AppDataService.instance.updateCagriStatus(cagriId, CagriDurumu.iptal);
      }
    } catch (_) {}
  }
}
