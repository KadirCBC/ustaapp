import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ustaapp/core/models/app_notification_model.dart';
import 'package:ustaapp/core/services/location_lookup_service.dart';
import 'package:ustaapp/core/services/notification_service.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final appDataServiceProvider = Provider<AppDataService>((ref) {
  return AppDataService.instance;
});

/// Mobil Uygulama ve Admin Paneli Arasındaki Ortak Merkezi Veri Servisi (Single Source of Truth)
/// Admin panelden eklenen, silinen veya düzenlenen her usta, ilan, kategori ve harita pini
/// anında bu servis üzerinden yerel kalıcı hafızaya (SharedPreferences) kaydedilir ve
/// mobil uygulamadaki harita, kategori çubukları ve usta ekranları tarafından canlı kullanılır.
class AppDataService {
  static final AppDataService _instance = AppDataService._internal();
  factory AppDataService() => _instance;
  static AppDataService get instance => _instance;

  static const String _kUstalarKey = 'app_shared_ustalar';
  static const String _kCategoriesKey = 'app_shared_categories';
  static const String _kJobsKey = 'app_shared_jobs';
  static const String _kTedarikcilerKey = 'app_shared_tedarikciler';
  static const String _kMapPinsKey = 'app_shared_map_pins';
  static const String _kMembersKey = 'app_shared_members';
  static const String _kPendingUstalarKey = 'app_shared_pending_ustalar';
  static const String _kFinancialTransactionsKey = 'app_shared_financial_transactions';
  static const String _kActiveSessionKey = 'app_active_session';
  static const String _kRegisteredUsersKey = 'app_registered_users';

  static const int _kSyncPort = 8090;

  final StreamController<void> _changesStreamController = StreamController<void>.broadcast();
  Stream<void> get onDataChanged => _changesStreamController.stream;

  StreamSubscription? _wsSubscription;
  bool _isConnectingWs = false;
  Timer? _reconnectTimer;
  bool _isSyncInitialized = false;
  final Set<String> _notifiedArrivalCagriIds = {};

  static String? _manualSyncHost;
  static const String _kCustomHostKey = 'app_custom_sync_host';

  static void setManualSyncHost(String host) {
    _manualSyncHost = host.trim();
    SharedPreferences.getInstance().then((p) => p.setString(_kCustomHostKey, host.trim()));
  }

  static String get activeSyncHost => _manualSyncHost ?? (defaultTargetPlatform == TargetPlatform.android ? '192.168.1.101' : 'localhost');

  String get _syncHost {
    if (_manualSyncHost != null && _manualSyncHost!.isNotEmpty) {
      return _manualSyncHost!;
    }
    if (kIsWeb) {
      final host = Uri.base.host;
      return (host.isNotEmpty && host != '0.0.0.0') ? host : 'localhost';
    }
    // Fiziksel telefonlar aynı Wi-Fi ağındaki ana makineye (192.168.1.101) bağlanır
    if (defaultTargetPlatform == TargetPlatform.android) {
      return '192.168.1.101';
    }
    return '127.0.0.1';
  }

  String get _syncBaseUrl => 'http://$_syncHost:$_kSyncPort';
  String get _syncWsUrl => 'ws://$_syncHost:$_kSyncPort/ws';

  AppDataService._internal() {
    initRealtimeSync();
  }

  void initRealtimeSync() {
    if (_isSyncInitialized) return;
    _isSyncInitialized = true;
    SharedPreferences.getInstance().then((p) {
      final savedHost = p.getString(_kCustomHostKey);
      if (savedHost != null && savedHost.isNotEmpty) {
        _manualSyncHost = savedHost;
      }
      _connectWebSocket();
      _fetchServerData();
    }).catchError((_) {
      _connectWebSocket();
      _fetchServerData();
    });
  }

  void _connectWebSocket() {
    if (_isConnectingWs) return;
    _isConnectingWs = true;

    try {
      final uri = Uri.parse(_syncWsUrl);
      final channel = WebSocketChannel.connect(uri);

      _wsSubscription?.cancel();
      _wsSubscription = channel.stream.listen(
        (message) {
          _isConnectingWs = false;
          _handleWsMessage(message);
        },
        onError: (err) {
          _isConnectingWs = false;
          _scheduleReconnect();
        },
        onDone: () {
          _isConnectingWs = false;
          _scheduleReconnect();
        },
      );
    } catch (_) {
      _isConnectingWs = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _connectWebSocket();
    });
  }

  Future<void> _fetchServerData() async {
    try {
      final res = await http.get(Uri.parse('$_syncBaseUrl/api/data')).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data['initialized'] == true) {
          _handleWsMessage(jsonEncode({'event': 'initial_data', 'data': data}));
        }
      }
    } catch (_) {
      if (!kIsWeb) {
        try {
          final res = await http.get(Uri.parse('http://10.0.2.2:$_kSyncPort/api/data')).timeout(const Duration(seconds: 2));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            if (data is Map<String, dynamic> && data['initialized'] == true) {
              _handleWsMessage(jsonEncode({'event': 'initial_data', 'data': data}));
            }
          }
        } catch (_) {}
      }
    }
  }

  void _handleWsMessage(dynamic raw) {
    try {
      final Map<String, dynamic> msg = jsonDecode(raw.toString());
      final String event = msg['event'] ?? '';
      final dynamic data = msg['data'];

      if (event == 'initial_data' && data is Map<String, dynamic>) {
        if (data['initialized'] == true) {
          if (data['ustalar'] is List) {
            _cachedUstalar = (data['ustalar'] as List)
                .map((item) => NearbyUstaModel.fromJson(Map<String, dynamic>.from(item)))
                .toList();
            _persistUstalarToPrefs(_cachedUstalar!);
          }
          if (data['jobs'] is List) {
            _cachedJobs = List<Map<String, dynamic>>.from(data['jobs']);
            _persistJobsToPrefs(_cachedJobs!);
          }
          if (data['categories'] is List && (data['categories'] as List).length >= 20) {
            _cachedCategories = List<Map<String, dynamic>>.from(data['categories']);
          }
          if (data['map_pins'] is List) {
            _cachedPins = List<Map<String, dynamic>>.from(data['map_pins']);
          }
          if (data['members'] is List) {
            _cachedMembers = List<Map<String, dynamic>>.from(data['members']);
          }
          if (data['pending_ustalar'] is List) {
            _cachedPending = List<Map<String, dynamic>>.from(data['pending_ustalar']);
          }
          if (data['tedarikciler'] is List) {
            _cachedTedarikciler = List<Map<String, dynamic>>.from(data['tedarikciler']);
          }
          if (data['financial_transactions'] is List) {
            _cachedFinancialTransactions = List<Map<String, dynamic>>.from(data['financial_transactions']);
            _persistFinancialTransactionsToPrefs(_cachedFinancialTransactions!);
          }
          if (data['cagrilar'] is List) {
            _cachedCagrilar = List<Map<String, dynamic>>.from(data['cagrilar']);
            _syncCallsToDemoRepo(_cachedCagrilar!);
          }
          _changesStreamController.add(null);
        }
      } else if (event == 'ustalar_updated') {
        if (data is List) {
          _cachedUstalar = data
              .map((item) => NearbyUstaModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
          _persistUstalarToPrefs(_cachedUstalar!);
          _changesStreamController.add(null);
        } else if (data is Map) {
          final ustaId = data['usta_id']?.toString() ?? '';
          final phone = (data['phone'] ?? '').toString();
          final isOnline = data['is_online'] as bool? ?? data['isOnline'] as bool? ?? true;
          if (_cachedUstalar != null) {
            for (int i = 0; i < _cachedUstalar!.length; i++) {
              final u = _cachedUstalar![i];
              if ((ustaId.isNotEmpty && u.ustaId == ustaId) ||
                  (phone.isNotEmpty && normalizePhone(u.phone) == normalizePhone(phone))) {
                _cachedUstalar![i] = u.copyWith(isOnline: isOnline);
              }
            }
            _persistUstalarToPrefs(_cachedUstalar!);
          }
          if (_cachedJobs != null) {
            for (int i = 0; i < _cachedJobs!.length; i++) {
              final j = _cachedJobs![i];
              final jUstaId = (j['usta_id'] ?? '').toString();
              final jPhone = normalizePhone((j['customer_phone'] ?? j['usta_phone'] ?? '').toString());
              if ((ustaId.isNotEmpty && jUstaId == ustaId) || (phone.isNotEmpty && jPhone == normalizePhone(phone))) {
                _cachedJobs![i] = Map<String, dynamic>.from(j);
                _cachedJobs![i]['is_online'] = isOnline;
                _cachedJobs![i]['isOnline'] = isOnline;
              }
            }
            _persistJobsToPrefs(_cachedJobs!);
          }
          _changesStreamController.add(null);
        }
      } else if (event == 'jobs_updated' && data is List) {
        _cachedJobs = List<Map<String, dynamic>>.from(data);
        _persistJobsToPrefs(_cachedJobs!);
        _changesStreamController.add(null);
      } else if (event == 'categories_updated' && data is List && data.length >= 20) {
        _cachedCategories = List<Map<String, dynamic>>.from(data);
        _changesStreamController.add(null);
      } else if (event == 'map_pins_updated' && data is List) {
        _cachedPins = List<Map<String, dynamic>>.from(data);
        _changesStreamController.add(null);
      } else if (event == 'members_updated' && data is List) {
        _cachedMembers = List<Map<String, dynamic>>.from(data);
        _changesStreamController.add(null);
      } else if (event == 'pending_ustalar_updated' && data is List) {
        _cachedPending = List<Map<String, dynamic>>.from(data);
        _changesStreamController.add(null);
      } else if (event == 'tedarikciler_updated' && data is List) {
        _cachedTedarikciler = List<Map<String, dynamic>>.from(data);
        _changesStreamController.add(null);
      } else if (event == 'financial_transactions_updated' && data is List) {
        _cachedFinancialTransactions = List<Map<String, dynamic>>.from(data);
        _persistFinancialTransactionsToPrefs(_cachedFinancialTransactions!);
        _changesStreamController.add(null);
      } else if (event == 'cagrilar_updated' && data is List) {
        _cachedCagrilar = List<Map<String, dynamic>>.from(data);
        _syncCallsToDemoRepo(_cachedCagrilar!);
        _changesStreamController.add(null);
      } else if (event == 'cagri_updated' && data is Map) {
        _cachedCagrilar ??= [];
        final cagriMap = Map<String, dynamic>.from(data);
        final id = (cagriMap['id'] ?? '').toString();
        final idx = _cachedCagrilar!.indexWhere((c) => (c['id'] ?? '').toString() == id);
        if (idx >= 0) {
          _cachedCagrilar![idx] = cagriMap;
        } else {
          _cachedCagrilar!.insert(0, cagriMap);
        }
        try {
          final model = CagriModel.fromJson(cagriMap);
          DemoCallRepository.save(model);
        } catch (_) {}

        // Usta adrese vardığında (adreste veya usta_arrived == true) kilit ekranında ve sesli bildirim göster
        final isAdreste = cagriMap['durum'] == 'adreste' || cagriMap['usta_arrived'] == true;
        if (isAdreste && !_notifiedArrivalCagriIds.contains(id)) {
          _notifiedArrivalCagriIds.add(id);
          final currentRole = _cachedActiveSession?['role']?.toString().toLowerCase();
          // Müşteri ekranında veya rol seçilmemişken bildirim ver
          if (currentRole != 'usta') {
            final ustaName = cagriMap['usta_name'] ?? cagriMap['ustaName'] ?? 'Ustanız';
            NotificationService.instance.showUstaArrived(
              ustaName: ustaName.toString(),
              cagriId: id,
              address: cagriMap['address']?.toString(),
            );
          }
        }
        _changesStreamController.add(null);
      } else if (event == 'usta_arrived' && data is Map) {
        final arrivalData = Map<String, dynamic>.from(data);
        final cid = arrivalData['cagri_id']?.toString() ?? '';
        if (cid.isNotEmpty && !_notifiedArrivalCagriIds.contains(cid)) {
          _notifiedArrivalCagriIds.add(cid);
          final currentRole = _cachedActiveSession?['role']?.toString().toLowerCase();
          if (currentRole != 'usta') {
            final ustaName = arrivalData['usta_name']?.toString() ?? 'Ustanız';
            NotificationService.instance.showUstaArrived(
              ustaName: ustaName,
              cagriId: cid,
              address: arrivalData['address']?.toString(),
            );
          }
        }
      } else if (event == 'system_notification' && data is Map) {
        try {
          final notifMap = Map<String, dynamic>.from(data);
          final notif = AppNotificationModel.fromJson(notifMap);
          final currentRole = _cachedActiveSession?['role']?.toString().toLowerCase();
          final currentPhone = normalizePhone(_cachedActiveSession?['phone']?.toString() ?? '');

          bool isTargeted = false;
          if (notif.target == 'all') {
            isTargeted = true;
          } else if (notif.target == 'ustalar' && currentRole == 'usta') {
            isTargeted = true;
          } else if (notif.target == 'musteriler' && currentRole != 'usta') {
            isTargeted = true;
          } else if (notif.target == 'user' &&
              notif.targetPhone != null &&
              normalizePhone(notif.targetPhone!) == currentPhone) {
            isTargeted = true;
          }

          if (isTargeted) {
            NotificationService.instance.showBroadcastNotification(notif);
          }
        } catch (e) {
          debugPrint('[AppDataService] system_notification işleme hatası: $e');
        }
      } else if (event == 'notifications_cleared') {
        NotificationService.instance.clearAll();
      } else if (event == 'all_cleared') {
        _cachedUstalar = [];
        _cachedJobs = [];
        _cachedMembers = [];
        _persistUstalarToPrefs([]);
        _persistJobsToPrefs([]);
        _changesStreamController.add(null);
      }
    } catch (e) {
      debugPrint('[AppDataService] WS parse hatası: $e');
    }
  }

  Future<void> _postToSyncServer(String endpoint, dynamic body) async {
    final payload = jsonEncode(body);
    final headers = {'Content-Type': 'application/json'};

    try {
      final res = await http
          .post(Uri.parse('$_syncBaseUrl$endpoint'), headers: headers, body: payload)
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) return;
    } catch (_) {}

    if (!kIsWeb) {
      try {
        await http
            .post(Uri.parse('http://10.0.2.2:$_kSyncPort$endpoint'), headers: headers, body: payload)
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
  }

  Future<void> _persistUstalarToPrefs(List<NearbyUstaModel> ustalar) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = ustalar.map((u) => u.toJson()).toList();
      await prefs.setString(_kUstalarKey, jsonEncode(list));
      await prefs.setBool('app_data_initialized', true);
    } catch (e) {
      debugPrint('SharedPreferences ustalar kaydetme hatası: $e');
    }
  }

  Future<void> _persistJobsToPrefs(List<Map<String, dynamic>> jobs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kJobsKey, jsonEncode(jobs));
      await prefs.setBool('app_data_initialized', true);
    } catch (e) {
      debugPrint('SharedPreferences jobs kaydetme hatası: $e');
    }
  }

  Future<void> _persistFinancialTransactionsToPrefs(List<Map<String, dynamic>> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kFinancialTransactionsKey, jsonEncode(list));
    } catch (e) {
      debugPrint('SharedPreferences financial_transactions kaydetme hatası: $e');
    }
  }

  // Bellek İçi Önbellek (Hızlı erişim için)
  List<NearbyUstaModel>? _cachedUstalar;
  List<Map<String, dynamic>>? _cachedCategories;
  List<Map<String, dynamic>>? _cachedJobs;
  List<Map<String, dynamic>>? _cachedTedarikciler;
  List<Map<String, dynamic>>? _cachedPins;
  List<Map<String, dynamic>>? _cachedMembers;
  List<Map<String, dynamic>>? _cachedPending;
  List<Map<String, dynamic>>? _cachedFinancialTransactions;
  List<Map<String, dynamic>>? _cachedCagrilar;
  Map<String, dynamic>? _cachedActiveSession;
  Map<String, Map<String, dynamic>>? _cachedRegisteredUsers;

  // ==========================================
  // 1. USTALAR & HARİTA VERİSİ (CRUD)
  // ==========================================

  Future<List<NearbyUstaModel>> getUstalar() async {
    if (_cachedUstalar != null) return List.from(_cachedUstalar!);

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kUstalarKey);
      if (raw != null) {
        final List list = jsonDecode(raw);
        _cachedUstalar = list
            .map((item) => NearbyUstaModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        return List.from(_cachedUstalar!);
      }
    } catch (e) {
      debugPrint('Ustalar yüklenirken hata: $e');
    }

    await _fetchServerData();
    if (_cachedUstalar != null) return List.from(_cachedUstalar!);

    // Kullanıcı isteği doğrultusunda mock içerik dönülmez, temiz başlanır
    _cachedUstalar = [];
    return [];
  }

  Future<void> saveUstalar(List<NearbyUstaModel> ustalar) async {
    List<String> deletedList = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      deletedList = prefs.getStringList('deleted_usta_ids') ?? <String>[];
    } catch (_) {}

    final cleanUstalar = ustalar.where((u) {
      final p = normalizePhone(u.phone);
      return !deletedList.contains(u.ustaId) && (p.isEmpty || !deletedList.contains(p));
    }).toList();

    _cachedUstalar = List.from(cleanUstalar);
    final list = cleanUstalar.map((u) => u.toJson()).toList();
    await _persistUstalarToPrefs(cleanUstalar);
    _changesStreamController.add(null);
    _postToSyncServer('/api/ustalar', list);
  }

  Future<List<NearbyUstaModel>> getNearbyUstalar({
    required String category,
    double customerLat = 40.9905,
    double customerLng = 29.0270,
    double maxRadiusMeter = 25000.0,
  }) async {
    final List<NearbyUstaModel> result = [];
    final Set<String> seenPinIds = {};
    final normalizedCat = category.trim().toLowerCase();

    // 1. Canlı ve Aktif Hizmet İlanları (Her ilan haritada kendi konumunda, başlığıyla ve fiyatıyla ayrı bir pin oluşturur)
    final activeJobs = await getActiveJobs();
    final allKnownUstalar = await getUstalar();

    for (final job in activeJobs) {
      final status = (job['status'] ?? 'Aktif').toString();
      // Sadece 'Aktif' durumundaki ilanlar haritada pin olarak yer alır
      if (status != 'Aktif') continue;

      // Usta çevrimdışı (meşgul) ise harita pininde ve aramada ASLA gösterilmez!
      final jobIsOnline = job['is_online'] as bool? ?? job['isOnline'] as bool? ?? true;
      if (!jobIsOnline) continue;

      double lat = (job['latitude'] as num?)?.toDouble() ?? 0.0;
      double lng = (job['longitude'] as num?)?.toDouble() ?? 0.0;
      String district = (job['district'] ?? job['address'] ?? job['konum'] ?? 'Sandıklı').toString();

      // Ustanın canlı yayınlanan gerçek konumu ve çalışma bölgesi statik ilan verisinden her zaman üstündür!
      final ustaId = (job['usta_id'] ?? '').toString();
      final ustaPhone = normalizePhone((job['customer_phone'] ?? job['usta_phone'] ?? '').toString());
      final matchingUsta = allKnownUstalar.cast<NearbyUstaModel?>().firstWhere(
        (u) => (u != null && (
          (ustaId.isNotEmpty && u.ustaId == ustaId) ||
          (ustaPhone.isNotEmpty && normalizePhone(u.phone) == ustaPhone)
        )),
        orElse: () => null,
      );

      if (matchingUsta != null) {
        if (!matchingUsta.isOnline) {
          // Usta meşgul/çevrimdışı yapıldığında ilanı haritadan anında yok olur!
          continue;
        }
        if (matchingUsta.latitude != 0.0 && matchingUsta.longitude != 0.0) {
          lat = matchingUsta.latitude;
          lng = matchingUsta.longitude;
          if (matchingUsta.uzmanlikBasligi.isNotEmpty) {
            district = matchingUsta.uzmanlikBasligi;
          }
        }
      } else if (lat == 0.0 && lng == 0.0) {
        // Fallback 1: Adresi yerel konum sözlüğünden çözümle
        final match = LocationLookupService.resolveSync(district);
        if (match != null) {
          lat = match.lat;
          lng = match.lng;
        }
      }
      if (lat == 0.0 && lng == 0.0) continue;

      final jobCat = (job['kategori'] ?? job['category'] ?? '').toString().trim().toLowerCase();
      final catMatch = (normalizedCat == 'tümü' || normalizedCat == 'all' || normalizedCat == 'tum')
          ? true
          : (jobCat.contains(normalizedCat) || normalizedCat.contains(jobCat));
      if (!catMatch) continue;

      // İl/İlçe ve Bölge Filtresi: Arama yarıçapını (varsayılan 25 km, maks 35 km) aşan ilanlar elenir.
      // Örnek: İstanbul'da Afyon, Sandıklı veya Ankara ilanları asla görünmez.
      final dist = Geolocator.distanceBetween(customerLat, customerLng, lat, lng);
      if (dist > maxRadiusMeter) continue;

      final jobId = (job['id'] ?? '').toString();
      if (seenPinIds.add(jobId)) {
        final rawPrice = job['price'];
        double price = 1750.0;
        if (rawPrice is num) {
          price = rawPrice.toDouble();
        } else if (rawPrice is String) {
          price = double.tryParse(rawPrice.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 1750.0;
        }

        final ustaName = (job['customer_name'] ?? job['usta_name'] ?? 'Kadir Usta').toString();
        final ustaPhone = (job['customer_phone'] ?? job['usta_phone'] ?? '05524342069').toString();
        final title = (job['title'] ?? 'Standart Servis & Arıza Tespiti').toString();
        final desc = (job['description'] ?? '').toString();

        // Aynı koordinata denk gelen ilanların üst üste binip tek pin gibi görünmesini engellemek için hafif mikro-kaydırma
        for (final existing in result) {
          if ((existing.latitude - lat).abs() < 0.0003 && (existing.longitude - lng).abs() < 0.0003) {
            final idx = result.length + 1;
            lat += (idx % 2 == 1 ? 0.0007 : -0.0007) * (1 + (idx ~/ 4) * 0.3);
            lng += (idx % 4 >= 2 ? 0.0007 : -0.0007) * (1 + (idx ~/ 4) * 0.3);
            break;
          }
        }

        final normCategory = _normalizeCatKey(jobCat);
        String ustaAvatar = (job['avatar_url'] ?? job['avatarUrl'])?.toString() ?? '';
        if (ustaAvatar.isEmpty) {
          if (normCategory.contains('cilingir')) {
            ustaAvatar = 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?q=80&w=600&auto=format&fit=crop';
          } else if (normCategory.contains('tesisat')) {
            ustaAvatar = 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?q=80&w=600&auto=format&fit=crop';
          } else {
            ustaAvatar = 'https://images.unsplash.com/photo-1541888946425-d0fbb186156f?q=80&w=600&auto=format&fit=crop';
          }
        }

        result.add(NearbyUstaModel(
          ustaId: jobId, // Her ilan için benzersiz harita pin ID'si
          fullName: ustaName,
          phone: ustaPhone,
          avatarUrl: ustaAvatar,
          kategori: normCategory,
          puan: 5.0,
          tamamlananIsSayisi: 48,
          latitude: lat,
          longitude: lng,
          mesafeMetre: dist > 0 ? dist : 100.0,
          toplamTutar: price,
          ustaHakedis: price * 0.85,
          komisyonOrani: 0.15,
          komisyonTutari: price * 0.15,
          servisUcreti: 150.0,
          deneyimYili: 10,
          uzmanlikBasligi: district,
          guvenceler: const [
            '30 Gün İşçilik Garantisi',
            'Sabit Fiyat Güvencesi',
            'MYK Belgeli',
          ],
          ilanlar: [
            UstaHizmetIlan(
              id: jobId,
              baslik: title,
              aciklama: desc,
              fiyat: price,
              tahminiSure: '30-60 dk',
              ikon: '⚡',
              isDefault: true,
              konum: district,
              lat: lat,
              lng: lng,
            ),
          ],
        ));
      }
    }

    // 2. Sistemdeki kayıtlı ustalardan henüz haritada aktif bir ilanı bulunmayanlar (varsa)
    final allUstalar = await getUstalar();
    for (final u in allUstalar) {
      if (!u.isOnline) continue; // Çevrimdışı usta haritada kesinlikle gösterilmez!
      if (u.ilanlar.isEmpty) continue;
      bool alreadyRepresented = result.any((r) => r.phone == u.phone && r.fullName == u.fullName);
      if (!alreadyRepresented && seenPinIds.add(u.ustaId)) {
        final ustaCat = u.kategori.trim().toLowerCase();
        final catMatch = (normalizedCat == 'tümü' || normalizedCat == 'all' || normalizedCat == 'tum')
            ? true
            : (ustaCat.contains(normalizedCat) || normalizedCat.contains(ustaCat));
        if (catMatch) {
          final dist = Geolocator.distanceBetween(customerLat, customerLng, u.latitude, u.longitude);
          if (dist <= maxRadiusMeter) {
            result.add(u.copyWith(mesafeMetre: dist > 0 ? dist : 500.0));
          }
        }
      }
    }

    result.sort((a, b) => a.mesafeMetre.compareTo(b.mesafeMetre));
    return result;
  }

  String _normalizeCatKey(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('elektrik')) return 'elektrik';
    if (lower.contains('tesisat') || lower.contains('su')) return 'tesisat';
    if (lower.contains('çilingir') || lower.contains('kilit')) return 'cilingir';
    if (lower.contains('klima') || lower.contains('kombi')) return 'klima';
    if (lower.contains('boya') || lower.contains('badana')) return 'boya';
    return lower;
  }

  Future<void> addOrUpdateUsta(NearbyUstaModel usta) async {
    final list = await getUstalar();
    final index = list.indexWhere((u) => u.ustaId == usta.ustaId);
    if (index >= 0) {
      list[index] = usta;
    } else {
      list.insert(0, usta);
    }
    await saveUstalar(list);
  }

  Future<bool> isUstaDeleted(String phoneOrId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deletedList = prefs.getStringList('deleted_usta_ids') ?? <String>[];
      final norm = normalizePhone(phoneOrId);
      return deletedList.contains(phoneOrId) || (norm.isNotEmpty && deletedList.contains(norm));
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteUsta(String ustaId, {String? phone}) async {
    final normPhone = phone != null && phone.isNotEmpty ? normalizePhone(phone) : '';

    // 1. Kara listeye ekle (Deleted ustalar listesi)
    try {
      final prefs = await SharedPreferences.getInstance();
      final deletedList = prefs.getStringList('deleted_usta_ids') ?? <String>[];
      final deletedSet = deletedList.toSet();
      if (ustaId.isNotEmpty) deletedSet.add(ustaId);
      if (normPhone.isNotEmpty) deletedSet.add(normPhone);
      await prefs.setStringList('deleted_usta_ids', deletedSet.toList());
    } catch (_) {}

    // 2. Ustalar listesinden sil
    final list = await getUstalar();
    list.removeWhere((u) {
      final uPhone = normalizePhone(u.phone);
      return (ustaId.isNotEmpty && u.ustaId == ustaId) ||
          (normPhone.isNotEmpty && uPhone == normPhone) ||
          (ustaId.isNotEmpty && uPhone == normalizePhone(ustaId));
    });
    await saveUstalar(list);

    // 3. İlanları sil
    final jobs = await getActiveJobs();
    jobs.removeWhere((j) {
      final jId = (j['usta_id'] ?? '').toString();
      final jPhone = normalizePhone((j['customer_phone'] ?? j['usta_phone'] ?? '').toString());
      return (ustaId.isNotEmpty && jId == ustaId) ||
          (normPhone.isNotEmpty && jPhone == normPhone);
    });
    await saveActiveJobs(jobs);

    // 4. Üyeler listesinden sil
    final members = await getMembers();
    members.removeWhere((m) {
      final mId = (m['id'] ?? '').toString();
      final mPhone = normalizePhone((m['phone'] ?? '').toString());
      return (ustaId.isNotEmpty && mId == ustaId) ||
          (normPhone.isNotEmpty && mPhone == normPhone);
    });
    await saveMembers(members);

    // 5. Kayıtlı kullanıcılar önbelleğinden sil
    if (_cachedRegisteredUsers != null) {
      if (normPhone.isNotEmpty) _cachedRegisteredUsers!.remove(normPhone);
      if (ustaId.isNotEmpty) _cachedRegisteredUsers!.remove(ustaId);
    }

    // 6. Eğer aktif oturum bu ustaya aitse oturumu temizle
    final session = await getActiveSession();
    if (session != null) {
      final sPhone = normalizePhone((session['phone'] ?? '').toString());
      if ((normPhone.isNotEmpty && sPhone == normPhone) || (session['uid'] ?? session['id']) == ustaId) {
        await clearActiveSession();
      }
    }
  }

  // ==========================================
  // 2. TÜM HİZMET İLANLARI (CRUD)
  // ==========================================

  /// Mobil uygulamadaki tüm ustaların sunduğu hizmet ilanlarını ve genel ilanları listeler
  Future<List<Map<String, dynamic>>> getAllHizmetIlanlari() async {
    final ustalar = await getUstalar();
    final List<Map<String, dynamic>> result = [];
    final Set<String> seenIds = {};

    // 1. Önce aktif işler / çağrılar tablosundaki kayıtları al (Burada tam kategori ve usta detayları yer alır)
    final jobs = await getActiveJobs();
    for (final job in jobs) {
      final rawPrice = job['price'];
      double parsedPrice = 500.0;
      if (rawPrice is num) {
        parsedPrice = rawPrice.toDouble();
      } else if (rawPrice is String) {
        parsedPrice = double.tryParse(rawPrice.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 500.0;
      }

      String rawJobId = (job['id'] ?? 'ILN-${DateTime.now().millisecondsSinceEpoch % 10000}').toString();
      if (rawJobId.startsWith('hz-')) {
        final digits = rawJobId.replaceAll(RegExp(r'[^0-9]'), '');
        final suffix = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
        rawJobId = 'ILN-$suffix';
      }

      // Aynı ID veya başlık+usta varsa tekilleştir
      if (seenIds.add(rawJobId)) {
        result.add({
          'id': rawJobId,
          'title': job['title'] ?? 'Servis Talebi',
          'description': job['description'] ?? '${job['customer_name'] ?? 'Müşteri'} - ${job['category'] ?? 'Genel'} (${job['district'] ?? 'Kadıköy'})',
          'price': parsedPrice,
          'duration': '30 dk',
          'icon': '📋',
          'kategori': job['category'] ?? job['kategori'] ?? 'Genel',
          'category': job['category'] ?? job['kategori'] ?? 'elektrik',
          'district': job['district'] ?? 'Kadıköy',
          'customer_name': job['customer_name'] ?? job['usta_name'] ?? 'Kadir Usta',
          'customer_phone': job['customer_phone'] ?? job['usta_phone'] ?? '+90 5XX XXX XX XX',
          'status': job['status'] ?? 'Aktif',
          'assigned_usta': job['assigned_usta'] ?? '—',
          'created_at': job['time'] ?? 'Yeni',
          'usta_id': job['usta_id'] ?? '',
          'usta_name': job['usta_name'] ?? job['customer_name'] ?? 'Kadir Usta',
          'type': job['type'] ?? 'Usta Hizmet İlanı',
        });
      }
    }

    // 2. Ustalara bağlı hizmet ilanları (Eğer jobs tablosunda henüz yoksa ekle - ASLA mükerrer ekleme yapmaz)
    for (final usta in ustalar) {
      for (final ilan in usta.ilanlar) {
        String cleanId = ilan.id;
        if (cleanId.startsWith('hz-')) {
          final digits = cleanId.replaceAll(RegExp(r'[^0-9]'), '');
          final suffix = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
          cleanId = 'ILN-$suffix';
        }

        // Eğer bu ilan jobs tablosunda zaten eklenmişse tekrar ekleme!
        if (seenIds.add(cleanId)) {
          result.add({
            'id': cleanId,
            'title': ilan.baslik,
            'description': ilan.aciklama,
            'price': ilan.fiyat,
            'duration': ilan.tahminiSure,
            'icon': ilan.ikon,
            'kategori': usta.kategori,
            'category': usta.kategori,
            'district': usta.uzmanlikBasligi,
            'customer_name': usta.fullName,
            'customer_phone': usta.phone,
            'status': 'Aktif',
            'assigned_usta': usta.fullName,
            'created_at': 'Bugün',
            'usta_id': usta.ustaId,
            'usta_name': usta.fullName,
            'type': 'Usta Hizmet İlanı',
            'is_default': ilan.isDefault,
          });
        }
      }
    }

    return result;
  }

  Future<void> addOrUpdateHizmetIlan({
    required String id,
    required String title,
    required String description,
    required double price,
    required String duration,
    required String icon,
    required String category,
    String? targetUstaId,
  }) async {
    final ustalar = await getUstalar();
    bool updated = false;

    // Hedef ustayı bul veya kategoriye uyan ilk ustaya bağla
    for (int i = 0; i < ustalar.length; i++) {
      final usta = ustalar[i];
      final matchesUsta = (targetUstaId != null && targetUstaId.isNotEmpty)
          ? usta.ustaId == targetUstaId
          : usta.kategori.toLowerCase().contains(category.toLowerCase());

      final ilanIndex = usta.ilanlar.indexWhere((il) => il.id == id);
      if (ilanIndex >= 0) {
        // Mevcut ilanı güncelle
        final updatedIlanlar = List<UstaHizmetIlan>.from(usta.ilanlar);
        updatedIlanlar[ilanIndex] = UstaHizmetIlan(
          id: id,
          baslik: title,
          aciklama: description,
          fiyat: price,
          tahminiSure: duration,
          ikon: icon,
          isDefault: updatedIlanlar[ilanIndex].isDefault,
        );
        ustalar[i] = usta.copyWith(ilanlar: updatedIlanlar);
        updated = true;
        break;
      } else if (matchesUsta && !updated) {
        // Yeni ilan ekle
        final updatedIlanlar = List<UstaHizmetIlan>.from(usta.ilanlar);
        updatedIlanlar.insert(
          0,
          UstaHizmetIlan(
            id: id,
            baslik: title,
            aciklama: description,
            fiyat: price,
            tahminiSure: duration,
            ikon: icon,
          ),
        );
        ustalar[i] = usta.copyWith(ilanlar: updatedIlanlar);
        updated = true;
        break;
      }
    }

    if (updated) {
      await saveUstalar(ustalar);
    }
  }

  Future<void> deleteHizmetIlan(String ilanId) async {
    final ustalar = await getUstalar();
    bool changed = false;

    for (int i = 0; i < ustalar.length; i++) {
      final usta = ustalar[i];
      final hasIlan = usta.ilanlar.any((il) => il.id == ilanId);
      if (hasIlan) {
        final updatedIlanlar = usta.ilanlar.where((il) => il.id != ilanId).toList();
        ustalar[i] = usta.copyWith(ilanlar: updatedIlanlar);
        changed = true;
      }
    }

    if (changed) {
      await saveUstalar(ustalar);
    }

    // Ayrıca jobs listesinde varsa kaldır
    final jobs = await getActiveJobs();
    if (jobs.any((j) => j['id'] == ilanId)) {
      jobs.removeWhere((j) => j['id'] == ilanId);
      await saveActiveJobs(jobs);
    }
  }

  // ==========================================
  // 3. KATEGORİ YÖNETİMİ (CRUD)
  // ==========================================

  static const List<Map<String, dynamic>> defaultAppCategories = [
    {
      'id': 'cat-elektrik',
      'name': 'Elektrik',
      'title': 'Elektrik',
      'type': 'Usta Hizmeti',
      'icon': 'bolt',
      'iconName': 'bolt',
      'colorValue': 0xFF0284C7,
      'count': 0,
      'description': 'Elektrik tesisatı, priz, anahtar, sigorta panosu, aydınlatma ve arıza tamiri',
    },
    {
      'id': 'cat-tesisat',
      'name': 'Sıhhi Tesisat',
      'title': 'Sıhhi Tesisat',
      'type': 'Usta Hizmeti',
      'icon': 'water',
      'iconName': 'water',
      'colorValue': 0xFF0284C7,
      'count': 0,
      'description': 'Temiz su, atık su, musluk/batarya, boru patlağı ve su kaçağı tespiti',
    },
    {
      'id': 'cat-cilingir',
      'name': 'Çilingir',
      'title': 'Çilingir',
      'type': 'Acil Servis',
      'icon': 'key',
      'iconName': 'key',
      'colorValue': 0xFFD97706,
      'count': 0,
      'description': 'Kapı açma, kilit değiştirme, emniyet kilidi montajı ve oto çilingir',
    },
    {
      'id': 'cat-kombi',
      'name': 'Kombi Servisi',
      'title': 'Kombi Servisi',
      'type': 'Teknik Servis',
      'icon': 'fire',
      'iconName': 'fire',
      'colorValue': 0xFFEA580C,
      'count': 0,
      'description': 'Kombi arıza, periyodik bakım, elektronik kart tamiri ve petek temizleme',
    },
    {
      'id': 'cat-klima',
      'name': 'Klima Servisi',
      'title': 'Klima Servisi',
      'type': 'Teknik Servis',
      'icon': 'ac',
      'iconName': 'ac',
      'colorValue': 0xFF0284C7,
      'count': 0,
      'description': 'Klima montaj, söküm, gaz dolumu, filtre bakımı ve arıza onarımı',
    },
    {
      'id': 'cat-boya',
      'name': 'Boya',
      'title': 'Boya',
      'type': 'Ev & Dekorasyon',
      'icon': 'paint',
      'iconName': 'paint',
      'colorValue': 0xFF8B5CF6,
      'count': 0,
      'description': 'İç ve dış cephe boyama, tavan boyası, kapı boyama ve tadilat boyası',
    },
    {
      'id': 'cat-alci',
      'name': 'Alçı & Dekorasyon',
      'title': 'Alçı & Dekorasyon',
      'type': 'Ev & Dekorasyon',
      'icon': 'engineering',
      'iconName': 'engineering',
      'colorValue': 0xFFF59E0B,
      'count': 0,
      'description': 'Alçıpan, asma tavan, kartonpiyer, duvar çıtası ve ışık bandı montajı',
    },
    {
      'id': 'cat-marangoz',
      'name': 'Mobilya & Marangoz',
      'title': 'Mobilya & Marangoz',
      'type': 'Usta Hizmeti',
      'icon': 'carpenter',
      'iconName': 'carpenter',
      'colorValue': 0xFF78350F,
      'count': 0,
      'description': 'Mobilya montajı, ray dolap, mutfak dolabı tamiri ve ahşap işçiliği',
    },
    {
      'id': 'cat-beyazesya',
      'name': 'Beyaz Eşya Tamiri',
      'title': 'Beyaz Eşya Tamiri',
      'type': 'Teknik Servis',
      'icon': 'repair',
      'iconName': 'repair',
      'colorValue': 0xFF2563EB,
      'count': 0,
      'description': 'Buzdolabı, çamaşır makinesi, bulaşık makinesi ve fırın tamir servisi',
    },
    {
      'id': 'cat-kucukevaletleri',
      'name': 'Küçük Ev Aletleri',
      'title': 'Küçük Ev Aletleri',
      'type': 'Teknik Servis',
      'icon': 'repair',
      'iconName': 'repair',
      'colorValue': 0xFF475569,
      'count': 0,
      'description': 'Süpürge, kahve makinesi, mikrodalga, robot süpürge ve ütü arıza onarımı',
    },
    {
      'id': 'cat-pimapen',
      'name': 'Pimapen & Cam Balkon',
      'title': 'Pimapen & Cam Balkon',
      'type': 'Usta Hizmeti',
      'icon': 'store',
      'iconName': 'store',
      'colorValue': 0xFF0284C7,
      'count': 0,
      'description': 'PVC pencere/kapı kilit ayarı, cam balkon montajı, ısıcam ve fitil yenileme',
    },
    {
      'id': 'cat-fayans',
      'name': 'Fayans & Seramik',
      'title': 'Fayans & Seramik',
      'type': 'Usta Hizmeti',
      'icon': 'engineering',
      'iconName': 'engineering',
      'colorValue': 0xFF059669,
      'count': 0,
      'description': 'Banyo, mutfak fayans döşeme, seramik kaplama ve derz dolgu yenileme',
    },
    {
      'id': 'cat-parke',
      'name': 'Parke & Zemin',
      'title': 'Parke & Zemin',
      'type': 'Usta Hizmeti',
      'icon': 'carpenter',
      'iconName': 'carpenter',
      'colorValue': 0xFFB45309,
      'count': 0,
      'description': 'Laminat ve lamine parke döşeme, süpürgelik montajı, zemin yalıtımı',
    },
    {
      'id': 'cat-cati',
      'name': 'Çatı & İzolasyon',
      'title': 'Çatı & İzolasyon',
      'type': 'Usta Hizmeti',
      'icon': 'engineering',
      'iconName': 'engineering',
      'colorValue': 0xFFDC2626,
      'count': 0,
      'description': 'Çatı aktarma, membran, su ve ısı izolasyonu, yağmur oluğu temizleme',
    },
    {
      'id': 'cat-temizlik',
      'name': 'Temizlik & İlaçlama',
      'title': 'Temizlik & İlaçlama',
      'type': 'Hizmet',
      'icon': 'cleaning',
      'iconName': 'cleaning',
      'colorValue': 0xFF10B981,
      'count': 0,
      'description': 'Ev, ofis ve inşaat sonrası detaylı temizlik, haşere ve böcek ilaçlama',
    },
    {
      'id': 'cat-hali',
      'name': 'Halı & Koltuk Yıkama',
      'title': 'Halı & Koltuk Yıkama',
      'type': 'Hizmet',
      'icon': 'cleaning',
      'iconName': 'cleaning',
      'colorValue': 0xFF0D9488,
      'count': 0,
      'description': 'Yerinde buharlı koltuk, yatak ve stor perde yıkama, halı yıkama servisi',
    },
    {
      'id': 'cat-cekici',
      'name': 'Oto Kurtarma & Çekici',
      'title': 'Oto Kurtarma & Çekici',
      'type': 'Yol Yardım',
      'icon': 'shipping',
      'iconName': 'shipping',
      'colorValue': 0xFFEA580C,
      'count': 0,
      'description': '7/24 acil oto kurtarma, şehirlerarası çekici ve araç transfer hizmeti',
    },
    {
      'id': 'cat-otomekanik',
      'name': 'Oto Mekanik & Bakım',
      'title': 'Oto Mekanik & Bakım',
      'type': 'Oto Servis',
      'icon': 'car',
      'iconName': 'car',
      'colorValue': 0xFF475569,
      'count': 0,
      'description': 'Mobil oto tamir, periyodik bakım, fren/balata, akü takviyesi ve lastik yardım',
    },
    {
      'id': 'cat-demirdograma',
      'name': 'Demir Doğrama & Ferforje',
      'title': 'Demir Doğrama & Ferforje',
      'type': 'Usta Hizmeti',
      'icon': 'engineering',
      'iconName': 'engineering',
      'colorValue': 0xFF334155,
      'count': 0,
      'description': 'Kaynak işleri, demir korkuluk, otomatik kepenk tamiri ve yangın merdiveni',
    },
    {
      'id': 'cat-guvenlik',
      'name': 'Elektronik & Güvenlik',
      'title': 'Elektronik & Güvenlik',
      'type': 'Teknik Servis',
      'icon': 'security',
      'iconName': 'security',
      'colorValue': 0xFF4F46E5,
      'count': 0,
      'description': 'Güvenlik kamerası, hırsız alarmı, görüntülü diafon ve uydu çanak montajı',
    },
    {
      'id': 'cat-bahce',
      'name': 'Bahçe & Peyzaj',
      'title': 'Bahçe & Peyzaj',
      'type': 'Usta Hizmeti',
      'icon': 'grass',
      'iconName': 'grass',
      'colorValue': 0xFF16A34A,
      'count': 0,
      'description': 'Çim biçme, ağaç budama, otomatik bahçe sulama ve peyzaj düzenleme',
    },
    {
      'id': 'cat-solar',
      'name': 'Güneş Enerjisi & Solar',
      'title': 'Güneş Enerjisi & Solar',
      'type': 'Teknik Servis',
      'icon': 'solar',
      'iconName': 'solar',
      'colorValue': 0xFFF59E0B,
      'count': 0,
      'description': 'Güneş paneli montajı, solar inverter arıza ve güneş enerjili sıcak su sistemleri',
    },
    {
      'id': 'cat-havalandirma',
      'name': 'Havalandırma & Baca',
      'title': 'Havalandırma & Baca',
      'type': 'Usta Hizmeti',
      'icon': 'engineering',
      'iconName': 'engineering',
      'colorValue': 0xFF64748B,
      'count': 0,
      'description': 'Endüstriyel havalandırma, baca temizliği, aspiratör ve menfez montajı',
    },
    {
      'id': 'cat-rezervuar',
      'name': 'Gömme Rezervuar & Klozet',
      'title': 'Gömme Rezervuar & Klozet',
      'type': 'Usta Hizmeti',
      'icon': 'water',
      'iconName': 'water',
      'colorValue': 0xFF0284C7,
      'count': 0,
      'description': 'Gömme rezervuar tamiri, şamandıra, klozet iç takım değişimi',
    },
    {
      'id': 'cat-tente',
      'name': 'Tente & Gölgelendirme',
      'title': 'Tente & Gölgelendirme',
      'type': 'Usta Hizmeti',
      'icon': 'store',
      'iconName': 'store',
      'colorValue': 0xFF0891B2,
      'count': 0,
      'description': 'Mafsallı tente, pergola, otomatik tente montajı ve branda tamiri',
    },
    {
      'id': 'cat-suaritma',
      'name': 'Su Arıtma Servisi',
      'title': 'Su Arıtma Servisi',
      'type': 'Teknik Servis',
      'icon': 'water',
      'iconName': 'water',
      'colorValue': 0xFF06B6D4,
      'count': 0,
      'description': 'Su arıtma cihazı montajı, filtre değişimi, tank ve pompa tamiri',
    },
    {
      'id': 'cat-dogalgaz',
      'name': 'Doğalgaz & Kalorifer',
      'title': 'Doğalgaz & Kalorifer',
      'type': 'Usta Hizmeti',
      'icon': 'fire',
      'iconName': 'fire',
      'colorValue': 0xFFDC2626,
      'count': 0,
      'description': 'Doğalgaz tesisatı, gaz kaçağı onarımı, vana ve radyatör montajı',
    },
    {
      'id': 'cat-nakliye',
      'name': 'Kurye & Nakliye',
      'title': 'Kurye & Nakliye',
      'type': 'Nakliye & Lojistik',
      'icon': 'shipping',
      'iconName': 'shipping',
      'colorValue': 0xFF475569,
      'count': 0,
      'description': 'Parça eşya taşıma, evden eve nakliye, acil kurye ve kamyonet kiralama',
    },
  ];

  Future<List<Map<String, dynamic>>> getCategories() async {
    if (_cachedCategories != null && _cachedCategories!.length >= 20) {
      return List.from(_cachedCategories!);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCategoriesKey);
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw);
        // Eski 5 kategorili veya eski isimli yapıysa 28 meslek dalına yükselt
        if (list.length >= 20) {
          _cachedCategories = list.map((e) => Map<String, dynamic>.from(e)).toList();
          return List.from(_cachedCategories!);
        }
      }
    } catch (e) {
      debugPrint('Kategoriler yüklenirken hata: $e');
    }

    _cachedCategories = List.from(defaultAppCategories);
    await saveCategories(_cachedCategories!);
    return List.from(_cachedCategories!);
  }

  Future<void> saveCategories(List<Map<String, dynamic>> categories) async {
    _cachedCategories = List.from(categories);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCategoriesKey, jsonEncode(categories));
    } catch (e) {
      debugPrint('Kategoriler kaydedilirken hata: $e');
    }
    _changesStreamController.add(null);
    _postToSyncServer('/api/categories', categories);
  }

  Future<void> addOrUpdateCategory(Map<String, dynamic> category) async {
    final list = await getCategories();
    final index = list.indexWhere((c) => c['id'] == category['id'] || c['key'] == category['key']);
    if (index >= 0) {
      list[index] = category;
    } else {
      list.add(category);
    }
    await saveCategories(list);
  }

  Future<void> deleteCategory(String categoryIdOrKey) async {
    final list = await getCategories();
    list.removeWhere((c) => c['id'] == categoryIdOrKey || c['key'] == categoryIdOrKey);
    await saveCategories(list);
  }

  // ==========================================
  // 4. AKTİF İŞ / ÇAĞRI LİSTESİ (CRUD)
  // ==========================================

  Future<List<Map<String, dynamic>>> getActiveJobs() async {
    if (_cachedJobs != null) return List.from(_cachedJobs!);

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kJobsKey);
      if (raw != null) {
        final List list = jsonDecode(raw);
        _cachedJobs = list.map((e) => Map<String, dynamic>.from(e)).toList();
        return List.from(_cachedJobs!);
      }
    } catch (e) {
      debugPrint('İlanlar yüklenirken hata: $e');
    }

    await _fetchServerData();
    if (_cachedJobs != null) return List.from(_cachedJobs!);

    _cachedJobs = [];
    return [];
  }

  Future<void> saveActiveJobs(List<Map<String, dynamic>> jobs) async {
    _cachedJobs = List.from(jobs);
    await _persistJobsToPrefs(jobs);
    _changesStreamController.add(null);
    _postToSyncServer('/api/jobs', jobs);
  }

  Future<void> addOrUpdateJob(Map<String, dynamic> job) async {
    final list = await getActiveJobs();
    final index = list.indexWhere((j) => j['id'] == job['id']);
    if (index >= 0) {
      list[index] = job;
    } else {
      list.insert(0, job);
    }
    await saveActiveJobs(list);
  }

  Future<void> deleteJob(String jobId) async {
    final list = await getActiveJobs();
    list.removeWhere((j) => j['id'] == jobId);
    await saveActiveJobs(list);
  }

  /// Usta yeni bir hizmet ilanı eklediğinde veya düzenlediğinde haritaya ve admin paneline canlı senkronize eder
  Future<void> syncUstaHizmetListing({
    required UstaHizmetIlan hizmet,
    required String ustaName,
    required String ustaPhone,
    required String ustaId,
    required String ustaCategory,
    required String location,
    required double lat,
    required double lng,
  }) async {
    final jobs = await getActiveJobs();
    final jobId = (hizmet.id.startsWith('ILN-') || hizmet.id.startsWith('hz-'))
        ? (hizmet.id.startsWith('ILN-') ? hizmet.id : 'ILN-${hizmet.id.hashCode.abs() % 9000 + 1000}')
        : 'ILN-${(hizmet.id.hashCode.abs() % 9000 + 1000)}';

    final jobMap = <String, dynamic>{
      'id': jobId,
      'title': hizmet.baslik,
      'customer_name': ustaName,
      'customer_phone': ustaPhone,
      'assigned_usta': ustaName,
      'usta_name': ustaName,
      'usta_phone': ustaPhone,
      'usta_id': ustaId,
      'kategori': ustaCategory,
      'category': ustaCategory,
      'price': hizmet.fiyat,
      'district': location,
      'address': location,
      'latitude': lat,
      'longitude': lng,
      'status': 'Aktif',
      'created_at': 'Şimdi',
      'is_urgent': false,
      'duration': hizmet.tahminiSure,
      'icon': hizmet.ikon,
      'description': hizmet.aciklama.isNotEmpty ? hizmet.aciklama : 'Usta hizmet ilanı',
      'type': 'Usta Hizmet İlanı',
    };

    final existingIndex = jobs.indexWhere((j) => j['id'] == jobId || j['id'] == hizmet.id);
    if (existingIndex >= 0) {
      jobs[existingIndex] = jobMap;
    } else {
      jobs.insert(0, jobMap);
    }
    await saveActiveJobs(jobs);

    // Aktif usta modelini de güncelle
    final ustalar = await getUstalar();
    final ustaIndex = ustalar.indexWhere((u) => u.ustaId == ustaId || u.phone == ustaPhone);
    if (ustaIndex >= 0) {
      final u = ustalar[ustaIndex];
      final ilanlar = List<UstaHizmetIlan>.from(u.ilanlar);
      final hIdx = ilanlar.indexWhere((h) => h.id == hizmet.id || h.id == jobId);
      if (hIdx >= 0) {
        ilanlar[hIdx] = hizmet;
      } else {
        ilanlar.add(hizmet);
      }
      ustalar[ustaIndex] = u.copyWith(
        latitude: lat,
        longitude: lng,
        uzmanlikBasligi: location,
        ilanlar: ilanlar,
      );
      await saveUstalar(ustalar);
    }
  }

  /// Usta bir hizmet ilanını sildiğinde haritadan, ilanlar masasından ve ustanın profilinden tamamen kaldırır
  Future<void> removeUstaHizmetListing(String hizmetId, {String? ustaPhone}) async {
    final jobs = await getActiveJobs();
    jobs.removeWhere((j) => j['id'] == hizmetId || j['id'].toString().contains(hizmetId) || hizmetId.contains(j['id'].toString()));
    await saveActiveJobs(jobs);

    final ustalar = await getUstalar();
    bool changed = false;
    for (int i = 0; i < ustalar.length; i++) {
      final u = ustalar[i];
      final originalCount = u.ilanlar.length;
      final filtered = u.ilanlar.where((h) => h.id != hizmetId && !hizmetId.contains(h.id)).toList();
      if (filtered.length != originalCount) {
        ustalar[i] = u.copyWith(ilanlar: filtered);
        changed = true;
        final norm = normalizePhone(u.phone);
        try {
          final prefs = await SharedPreferences.getInstance();
          final key = 'usta_hizmetler_$norm';
          final encoded = jsonEncode(filtered.map((s) => s.toJson()).toList());
          await prefs.setString(key, encoded);
        } catch (_) {}
      }
    }
    if (changed) {
      await saveUstalar(ustalar);
    }

    if (ustaPhone != null && ustaPhone.isNotEmpty) {
      final norm = normalizePhone(ustaPhone);
      final current = await getUstaHizmetleri(norm);
      final updated = current.where((h) => h.id != hizmetId && !hizmetId.contains(h.id)).toList();
      await saveUstaHizmetleri(norm, updated);
    }
  }

  /// Belirli bir ustanın hizmetlerini getirir (Kalıcı ve gerçek)
  Future<List<UstaHizmetIlan>> getUstaHizmetleri(String phoneOrUstaId) async {
    final norm = normalizePhone(phoneOrUstaId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'usta_hizmetler_$norm';
      final raw = prefs.getString(key);
      if (raw != null) {
        final List list = jsonDecode(raw);
        return list.map((e) => UstaHizmetIlan.fromJson(Map<String, dynamic>.from(e))).toList();
      }
    } catch (e) {
      debugPrint('getUstaHizmetleri prefs error: $e');
    }

    final ustalar = await getUstalar();
    final match = ustalar.cast<NearbyUstaModel?>().firstWhere(
      (u) => u != null && (normalizePhone(u.phone) == norm || u.ustaId == phoneOrUstaId),
      orElse: () => null,
    );
    if (match != null) {
      return List<UstaHizmetIlan>.from(match.ilanlar);
    }
    return [];
  }

  /// Belirli bir ustanın hizmet tarifesini günceller ve hem prefs hem ustalar listesine kalıcı yazar
  Future<void> saveUstaHizmetleri(String phoneOrUstaId, List<UstaHizmetIlan> services) async {
    final norm = normalizePhone(phoneOrUstaId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'usta_hizmetler_$norm';
      final encoded = jsonEncode(services.map((s) => s.toJson()).toList());
      await prefs.setString(key, encoded);
    } catch (e) {
      debugPrint('saveUstaHizmetleri prefs error: $e');
    }

    final ustalar = await getUstalar();
    final idx = ustalar.indexWhere(
      (u) => normalizePhone(u.phone) == norm || u.ustaId == phoneOrUstaId,
    );
    if (idx >= 0) {
      ustalar[idx] = ustalar[idx].copyWith(ilanlar: List.from(services));
      await saveUstalar(ustalar);
    }
    _changesStreamController.add(null);
  }

  /// Belirli bir ustanın ayrıntılı fiyatlandırma & yakıt tarifesini kalıcı kaydeder (SharedPreferences ve ustalar tablosu)
  Future<void> saveUstaTarife({
    required String phoneOrUstaId,
    required double tabanServis,
    required double kmBasiYakit,
    required double ucretsizMesafeKm,
    required double acilGeceUcreti,
    required double calismaYaricapiKm,
  }) async {
    final norm = normalizePhone(phoneOrUstaId);
    final key = 'usta_tarife_${norm.isNotEmpty ? norm : 'default'}';
    final data = {
      'taban_servis': tabanServis,
      'km_basi_yakit': kmBasiYakit,
      'ucretsiz_mesafe_km': ucretsizMesafeKm,
      'acil_gece_ucreti': acilGeceUcreti,
      'calisma_yaricapi_km': calismaYaricapiKm,
      'is_custom': true,
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
      debugPrint('[AppDataService] Usta tarife kalıcı hafızaya kaydedildi: $data');
    } catch (e) {
      debugPrint('saveUstaTarife prefs error: $e');
    }

    final ustalar = await getUstalar();
    final idx = ustalar.indexWhere(
      (u) => normalizePhone(u.phone) == norm || u.ustaId == phoneOrUstaId,
    );
    if (idx >= 0) {
      ustalar[idx] = ustalar[idx].copyWith(
        servisUcreti: tabanServis,
        kmBasiYakitUcreti: kmBasiYakit,
        ucretsizMesafeKm: ucretsizMesafeKm,
        acilGeceUcreti: acilGeceUcreti,
        calismaYaricapiKm: calismaYaricapiKm,
        hasCustomTarife: true,
      );
      await saveUstalar(ustalar);
    }
    _changesStreamController.add(null);
  }

  /// Belirli bir ustanın kalıcı ayrıntılı tarife ayarlarını getirir (Yalnızca usta kaydettiyse döner)
  Future<Map<String, double>?> getUstaTarife(String phoneOrUstaId) async {
    final norm = normalizePhone(phoneOrUstaId);
    final key = 'usta_tarife_${norm.isNotEmpty ? norm : 'default'}';
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        if (map['is_custom'] == true) {
          return {
            'taban_servis': (map['taban_servis'] as num?)?.toDouble() ?? 0.0,
            'km_basi_yakit': (map['km_basi_yakit'] as num?)?.toDouble() ?? 0.0,
            'ucretsiz_mesafe_km': (map['ucretsiz_mesafe_km'] as num?)?.toDouble() ?? 0.0,
            'acil_gece_ucreti': (map['acil_gece_ucreti'] as num?)?.toDouble() ?? 0.0,
            'calisma_yaricapi_km': (map['calisma_yaricapi_km'] as num?)?.toDouble() ?? 20.0,
          };
        }
      }
    } catch (e) {
      debugPrint('getUstaTarife prefs error: $e');
    }

    final ustalar = await getUstalar();
    final match = ustalar.cast<NearbyUstaModel?>().firstWhere(
      (u) => u != null && (normalizePhone(u.phone) == norm || u.ustaId == phoneOrUstaId),
      orElse: () => null,
    );
    if (match != null && match.hasCustomTarife && match.servisUcreti > 0) {
      return {
        'taban_servis': match.servisUcreti,
        'km_basi_yakit': match.kmBasiYakitUcreti,
        'ucretsiz_mesafe_km': match.ucretsizMesafeKm,
        'acil_gece_ucreti': match.acilGeceUcreti,
        'calisma_yaricapi_km': match.calismaYaricapiKm,
      };
    }
    return null;
  }

  /// Ustanın çalışma konumunu ve koordinatlarını günceller (Tüm ilanlar ve harita pinleri dahil anında senkronize olur)
  Future<void> updateUstaLocation({
    required String ustaId,
    String? phone,
    required String address,
    required double lat,
    required double lng,
  }) async {
    final norm = phone != null && phone.isNotEmpty ? normalizePhone(phone) : '';

    // 1. Ustalar listesini ve ustanın kendi alt ilanlarını güncelle
    final ustalar = await getUstalar();
    bool ustaUpdated = false;
    for (int i = 0; i < ustalar.length; i++) {
      final u = ustalar[i];
      final match = u.ustaId == ustaId || (norm.isNotEmpty && normalizePhone(u.phone) == norm);
      if (match) {
        final updatedIlanlar = u.ilanlar.map((il) => il.copyWith(
          konum: address,
          lat: lat,
          lng: lng,
        )).toList();
        ustalar[i] = u.copyWith(
          uzmanlikBasligi: address,
          latitude: lat,
          longitude: lng,
          ilanlar: updatedIlanlar,
        );
        ustaUpdated = true;
      }
    }
    if (ustaUpdated) {
      await saveUstalar(ustalar);
    }

    // 2. Jobs listesindeki bu ustaya ait tüm aktif ilanların konumunu ve koordinatını canlı güncelle
    final jobs = await getActiveJobs();
    bool jobsUpdated = false;
    for (int i = 0; i < jobs.length; i++) {
      final j = jobs[i];
      final jUstaId = (j['usta_id'] ?? '').toString();
      final jPhone = normalizePhone((j['customer_phone'] ?? j['usta_phone'] ?? '').toString());
      if (jUstaId == ustaId || (norm.isNotEmpty && jPhone == norm)) {
        jobs[i] = Map<String, dynamic>.from(j);
        jobs[i]['district'] = address;
        jobs[i]['address'] = address;
        jobs[i]['latitude'] = lat;
        jobs[i]['longitude'] = lng;
        jobsUpdated = true;
      }
    }
    if (jobsUpdated) {
      await saveActiveJobs(jobs);
    }

    // 3. SharedPreferences ve Active Session güncelle
    try {
      final session = await getActiveSession();
      if (session != null && (session['phone'] == norm || session['full_name'] != null)) {
        session['city_district'] = address;
        session['address'] = address;
        session['latitude'] = lat;
        session['longitude'] = lng;
        await saveActiveSession(
          phone: session['phone']?.toString() ?? norm,
          fullName: session['full_name']?.toString() ?? 'Usta',
          role: 'usta',
          extra: session,
        );
      }
    } catch (_) {}

    _changesStreamController.add(null);
  }

  /// Ustanın çevrimiçi (müsait) veya çevrimdışı (meşgul) durumunu günceller.
  /// Usta çevrimdışı olduğunda haritadaki pinleri anında yok olur;
  /// usta çevrimiçi olduğunda haritada anında yeniden belirir.
  Future<void> updateUstaOnlineStatus({
    required String ustaId,
    String? phone,
    required bool isOnline,
  }) async {
    final norm = phone != null && phone.isNotEmpty ? normalizePhone(phone) : '';

    // 1. Ustalar listesini güncelle
    final ustalar = await getUstalar();
    bool ustaUpdated = false;
    for (int i = 0; i < ustalar.length; i++) {
      final u = ustalar[i];
      final match = (ustaId.isNotEmpty && u.ustaId == ustaId) ||
          (norm.isNotEmpty && normalizePhone(u.phone) == norm);
      if (match) {
        ustalar[i] = u.copyWith(isOnline: isOnline);
        ustaUpdated = true;
      }
    }
    if (ustaUpdated) {
      await saveUstalar(ustalar);
    }

    // 2. Jobs listesindeki bu ustaya ait tüm ilanların çevrimiçi durumunu canlı güncelle
    final jobs = await getActiveJobs();
    bool jobsUpdated = false;
    for (int i = 0; i < jobs.length; i++) {
      final j = jobs[i];
      final jUstaId = (j['usta_id'] ?? '').toString();
      final jPhone = normalizePhone((j['customer_phone'] ?? j['usta_phone'] ?? '').toString());
      if ((ustaId.isNotEmpty && jUstaId == ustaId) || (norm.isNotEmpty && jPhone == norm)) {
        jobs[i] = Map<String, dynamic>.from(j);
        jobs[i]['is_online'] = isOnline;
        jobs[i]['isOnline'] = isOnline;
        jobsUpdated = true;
      }
    }
    if (jobsUpdated) {
      await saveActiveJobs(jobs);
    }

    // 3. Aktif oturumdaki usta nesnesine de kaydet
    try {
      final session = await getActiveSession();
      if (session != null && (session['phone'] == norm || session['full_name'] != null)) {
        session['is_online'] = isOnline;
        session['isOnline'] = isOnline;
        await saveActiveSession(
          phone: session['phone']?.toString() ?? norm,
          fullName: session['full_name']?.toString() ?? 'Usta',
          role: 'usta',
          extra: session,
        );
      }
    } catch (_) {}

    _changesStreamController.add(null);
  }

  // ==========================================
  // 5. TEDARİKÇİ & HARİTA PİN YÖNETİMİ (CRUD)
  // ==========================================

  Future<List<Map<String, dynamic>>> getTedarikciler() async {
    if (_cachedTedarikciler != null) return List.from(_cachedTedarikciler!);

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kTedarikcilerKey);
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw);
        _cachedTedarikciler = list.map((e) => Map<String, dynamic>.from(e)).toList();
        return List.from(_cachedTedarikciler!);
      }
    } catch (e) {
      debugPrint('Tedarikçiler yüklenirken hata: $e');
    }

    _cachedTedarikciler = const [
      {
        'id': 'isletme-cebeci-sandikli',
        'ad': 'Cebeci Elektrik & Solar Enerji Sistemleri',
        'kategori': 'Elektrik & Toptan Malzeme',
        'telefon': '05524342069',
        'adres': 'Ece Mahallesi, Sandıklı / Afyonkarahisar',
        'lat': 38.460075,
        'lng': 30.265469,
        'indirim_orani': '%15 Anlaşmalı İndirim',
        'is_sponsored': true,
      },
    ];
    await saveTedarikciler(_cachedTedarikciler!);
    return List.from(_cachedTedarikciler!);
  }

  Future<List<Map<String, dynamic>>> getNearbyTedarikciler({
    double customerLat = 40.9905,
    double customerLng = 29.0270,
    double maxRadiusMeter = 25000.0,
  }) async {
    final all = await getTedarikciler();
    final filtered = all.where((item) {
      final lat = (item['latitude'] as num?)?.toDouble() ??
          (item['lat'] as num?)?.toDouble() ??
          (item['enlem'] as num?)?.toDouble() ??
          0.0;
      final lng = (item['longitude'] as num?)?.toDouble() ??
          (item['lng'] as num?)?.toDouble() ??
          (item['boylam'] as num?)?.toDouble() ??
          0.0;
      if (lat == 0.0 && lng == 0.0) return false;
      final dist = Geolocator.distanceBetween(customerLat, customerLng, lat, lng);
      return dist <= maxRadiusMeter;
    }).toList();
    return filtered;
  }

  Future<void> saveTedarikciler(List<Map<String, dynamic>> list) async {
    _cachedTedarikciler = List.from(list);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTedarikcilerKey, jsonEncode(list));
    } catch (e) {
      debugPrint('Tedarikçiler kaydedilirken hata: $e');
    }
    _changesStreamController.add(null);
    _postToSyncServer('/api/tedarikciler', list);
  }

  Future<List<Map<String, dynamic>>> getMapPins() async {
    if (_cachedPins != null) return List.from(_cachedPins!);

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kMapPinsKey);
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw);
        _cachedPins = list.map((e) => Map<String, dynamic>.from(e)).toList();
        return List.from(_cachedPins!);
      }
    } catch (e) {
      debugPrint('Pinler yüklenirken hata: $e');
    }

    _cachedPins = [];
    await saveMapPins(_cachedPins!);
    return List.from(_cachedPins!);
  }

  Future<void> saveMapPins(List<Map<String, dynamic>> list) async {
    _cachedPins = List.from(list);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kMapPinsKey, jsonEncode(list));
    } catch (e) {
      debugPrint('Pinler kaydedilirken hata: $e');
    }
    _changesStreamController.add(null);
    _postToSyncServer('/api/map_pins', list);
  }

  // ==========================================
  // 6. ÜYELER & BEKLEYEN BAŞVURULAR (CRUD)
  // ==========================================

  Future<List<Map<String, dynamic>>> getMembers() async {
    if (_cachedMembers != null) return List.from(_cachedMembers!);

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kMembersKey);
      if (raw != null) {
        final List list = jsonDecode(raw);
        _cachedMembers = list.map((e) => Map<String, dynamic>.from(e)).toList();
        return List.from(_cachedMembers!);
      }
    } catch (e) {
      debugPrint('Üyeler yüklenirken hata: $e');
    }

    await _fetchServerData();
    if (_cachedMembers != null) return List.from(_cachedMembers!);

    _cachedMembers = [];
    return [];
  }

  Future<void> saveMembers(List<Map<String, dynamic>> list) async {
    _cachedMembers = List.from(list);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kMembersKey, jsonEncode(list));
    } catch (e) {
      debugPrint('Üyeler kaydedilirken hata: $e');
    }
    _changesStreamController.add(null);
    _postToSyncServer('/api/members', list);
  }

  Future<List<Map<String, dynamic>>> getPendingApplications() async {
    if (_cachedPending != null) return List.from(_cachedPending!);

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPendingUstalarKey);
      if (raw != null) {
        final List list = jsonDecode(raw);
        _cachedPending = list.map((e) => Map<String, dynamic>.from(e)).toList();
        return List.from(_cachedPending!);
      }
    } catch (e) {
      debugPrint('Başvurular yüklenirken hata: $e');
    }

    await _fetchServerData();
    if (_cachedPending != null) return List.from(_cachedPending!);

    _cachedPending = [];
    return [];
  }

  Future<void> savePendingApplications(List<Map<String, dynamic>> list) async {
    _cachedPending = List.from(list);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPendingUstalarKey, jsonEncode(list));
    } catch (e) {
      debugPrint('Başvurular kaydedilirken hata: $e');
    }
    _changesStreamController.add(null);
    _postToSyncServer('/api/pending_ustalar', list);
  }

  // ==========================================
  // 6.1 KULLANICI / ÜYE KAYITLARI & OTURUM KALICILIĞI (SESSION PERSISTENCE)
  // ==========================================

  static String normalizePhone(String raw) {
    String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('90') && digits.length == 12) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }
    return digits;
  }

  /// Kayıtlı kullanıcıları getirir (telefon -> kullanıcı profili)
  Future<Map<String, Map<String, dynamic>>> getRegisteredUsers() async {
    if (_cachedRegisteredUsers != null) return Map.from(_cachedRegisteredUsers!);

    _cachedRegisteredUsers = {};

    // 1. Önce SharedPreferences'tan oku
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kRegisteredUsersKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((key, val) {
          _cachedRegisteredUsers![key] = Map<String, dynamic>.from(val as Map);
        });
      }
    } catch (e) {
      debugPrint('Kayıtlı kullanıcılar yüklenirken hata: $e');
    }

    // 2. Silinen ustaları listeden temizle
    List<String> deletedList = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      deletedList = prefs.getStringList('deleted_usta_ids') ?? <String>[];
    } catch (_) {}
    for (final delId in deletedList) {
      _cachedRegisteredUsers!.remove(delId);
    }

    // 3. Mevcut members listesindeki kullanıcıları da dahil et
    final members = await getMembers();
    for (final m in members) {
      final p = normalizePhone((m['phone'] ?? '').toString());
      if (p.isNotEmpty && !_cachedRegisteredUsers!.containsKey(p)) {
        _cachedRegisteredUsers![p] = {
          'phone': p,
          'full_name': m['full_name'] ?? m['name'] ?? 'Kullanıcı',
          'role': m['role'] ?? 'musteri',
          'registered_at': m['created_at'] ?? DateTime.now().toIso8601String(),
        };
      }
    }

    // 4. Mevcut ustalar listesindeki ustaları da dahil et
    final ustalar = await getUstalar();
    for (final u in ustalar) {
      final p = normalizePhone(u.phone);
      if (p.isNotEmpty && !_cachedRegisteredUsers!.containsKey(p)) {
        _cachedRegisteredUsers![p] = {
          'phone': p,
          'full_name': u.fullName,
          'role': 'usta',
          'registered_at': DateTime.now().toIso8601String(),
        };
      }
    }

    return Map.from(_cachedRegisteredUsers!);
  }

  /// Telefon numarasına göre kayıtlı kullanıcı arar
  Future<Map<String, dynamic>?> findUserByPhone(String rawPhone) async {
    final norm = normalizePhone(rawPhone);
    if (norm.isEmpty) return null;

    final users = await getRegisteredUsers();
    if (users.containsKey(norm)) {
      return Map<String, dynamic>.from(users[norm]!);
    }

    // Ayrıca members ve ustalar'da da ara (farklı formatlar için)
    final members = await getMembers();
    for (final m in members) {
      final p = normalizePhone((m['phone'] ?? '').toString());
      if (p == norm) {
        return {
          'phone': norm,
          'full_name': m['full_name'] ?? m['name'] ?? 'Kullanıcı',
          'role': m['role'] ?? 'musteri',
        };
      }
    }

    final ustalar = await getUstalar();
    for (final u in ustalar) {
      if (normalizePhone(u.phone) == norm) {
        return {
          'phone': norm,
          'full_name': u.fullName,
          'role': 'usta',
        };
      }
    }

    return null;
  }

  /// Yeni kullanıcı kaydeder veya günceller
  Future<void> registerOrUpdateUser({
    required String phone,
    required String fullName,
    required String role,
  }) async {
    final norm = normalizePhone(phone);
    if (norm.isEmpty) return;

    await getRegisteredUsers(); // ensure cache loaded
    final profile = {
      'phone': norm,
      'full_name': fullName.trim(),
      'role': role.trim().toLowerCase(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    _cachedRegisteredUsers![norm] = profile;

    // Prefs'e yaz
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kRegisteredUsersKey, jsonEncode(_cachedRegisteredUsers));
    } catch (e) {
      debugPrint('Kullanıcı kaydedilirken hata: $e');
    }

    // members tablosunu da güncelle ve sunucuya bildir
    final members = await getMembers();
    final idx = members.indexWhere((m) => normalizePhone((m['phone'] ?? '').toString()) == norm);
    if (idx >= 0) {
      members[idx] = {
        ...members[idx],
        'phone': norm,
        'full_name': fullName.trim(),
        'name': fullName.trim(),
        'role': role.trim().toLowerCase(),
      };
    } else {
      members.add({
        'id': 'mem-${DateTime.now().millisecondsSinceEpoch}',
        'phone': norm,
        'full_name': fullName.trim(),
        'name': fullName.trim(),
        'role': role.trim().toLowerCase(),
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    await saveMembers(members);

    // Eğer usta ise ustalar listesini de kontrol et
    if (role.trim().toLowerCase() == 'usta') {
      final ustalar = await getUstalar();
      final uIdx = ustalar.indexWhere((u) => normalizePhone(u.phone) == norm);
      if (uIdx < 0) {
        // Yeni usta olarak ekle
        final newUsta = NearbyUstaModel(
          ustaId: 'usta-${DateTime.now().millisecondsSinceEpoch}',
          fullName: fullName.trim(),
          phone: norm,
          kategori: 'elektrik',
          puan: 5.0,
          tamamlananIsSayisi: 0,
          latitude: 38.4647,
          longitude: 30.2719,
          mesafeMetre: 500,
          ustaHakedis: 750.0,
          komisyonOrani: 0.15,
          komisyonTutari: 112.5,
          toplamTutar: 862.5,
          servisUcreti: 750.0,
          deneyimYili: 5,
          uzmanlikBasligi: 'Uzman Usta',
          guvenceler: const [
            '30 Gün İşçilik Garantisi',
            'Sabit Fiyat Güvencesi',
            'MYK Belgeli'
          ],
          ilanlar: const [],
        );
        ustalar.add(newUsta);
        await saveUstalar(ustalar);
      }
    }

    // Aktif oturum olarak da kaydet
    await saveActiveSession(
      phone: norm,
      fullName: fullName.trim(),
      role: role.trim().toLowerCase(),
    );
  }

  /// Profesyonel Müşteri Kaydı (Ad, Soyad, Telefon, E-posta, Adres vb.)
  Future<void> registerCustomer({
    required String phone,
    required String firstName,
    required String lastName,
    String? email,
    required String cityDistrict,
    required String address,
    String? addressTitle,
    String? addressNotes,
  }) async {
    final norm = normalizePhone(phone);
    final fullName = '${firstName.trim()} ${lastName.trim()}'.trim();

    final profile = {
      'phone': norm,
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'full_name': fullName,
      'email': email?.trim() ?? '',
      'city_district': cityDistrict.trim(),
      'address': address.trim(),
      'address_title': addressTitle ?? 'Ev',
      'address_notes': addressNotes?.trim() ?? '',
      'role': 'musteri',
      'registered_at': DateTime.now().toIso8601String(),
    };

    await getRegisteredUsers();
    _cachedRegisteredUsers![norm] = profile;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kRegisteredUsersKey, jsonEncode(_cachedRegisteredUsers));
    } catch (e) {
      debugPrint('Müşteri kaydedilirken hata: $e');
    }

    final members = await getMembers();
    final idx = members.indexWhere((m) => normalizePhone((m['phone'] ?? '').toString()) == norm);
    if (idx >= 0) {
      members[idx] = {
        ...members[idx],
        ...profile,
        'name': fullName,
      };
    } else {
      members.add({
        'id': 'mem-${DateTime.now().millisecondsSinceEpoch}',
        ...profile,
        'name': fullName,
      });
    }
    await saveMembers(members);

    await saveActiveSession(
      phone: norm,
      fullName: fullName,
      role: 'musteri',
      extra: profile,
    );
  }

  /// Profesyonel Usta Kaydı (Ad, Soyad, Vergi No, Adres, Telefon vb.)
  Future<void> registerUsta({
    required String phone,
    required String firstName,
    required String lastName,
    String? email,
    required String category,
    required String cityDistrict,
    required String address,
    String? vergiNo,
    int experienceYears = 5,
    bool hasMykCertificate = false,
    String? iban,
    double baseServiceFee = 750.0,
    double workRadiusKm = 15.0,
  }) async {
    final norm = normalizePhone(phone);
    final fullName = '${firstName.trim()} ${lastName.trim()}'.trim();
    final bool isOnayli = vergiNo != null && vergiNo.trim().isNotEmpty;

    final guvenceler = <String>[
      '30 Gün İşçilik Garantisi',
      'Sabit Fiyat Güvencesi',
      if (hasMykCertificate) 'MYK Belgeli',
      if (isOnayli) 'Vergi Levhalı Onaylı Usta',
    ];

    final profile = {
      'phone': norm,
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'full_name': fullName,
      'email': email?.trim() ?? '',
      'category': category.trim(),
      'city_district': cityDistrict.trim(),
      'address': address.trim(),
      'vergi_no': vergiNo?.trim() ?? '',
      'is_onayli': isOnayli,
      'experience_years': experienceYears,
      'has_myk': hasMykCertificate,
      'iban': iban?.trim() ?? '',
      'base_service_fee': baseServiceFee,
      'work_radius_km': workRadiusKm,
      'role': 'usta',
      'registered_at': DateTime.now().toIso8601String(),
    };

    await getRegisteredUsers();
    _cachedRegisteredUsers![norm] = profile;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kRegisteredUsersKey, jsonEncode(_cachedRegisteredUsers));
    } catch (e) {
      debugPrint('Usta kaydedilirken hata: $e');
    }

    final members = await getMembers();
    final idx = members.indexWhere((m) => normalizePhone((m['phone'] ?? '').toString()) == norm);
    if (idx >= 0) {
      members[idx] = {
        ...members[idx],
        ...profile,
        'name': fullName,
      };
    } else {
      members.add({
        'id': 'mem-${DateTime.now().millisecondsSinceEpoch}',
        ...profile,
        'name': fullName,
      });
    }
    await saveMembers(members);

    // Koordinat çözümleme (Şehir/İlçe bazlı harita pini)
    double resolvedLat = 38.4647;
    double resolvedLng = 30.2719;
    final syncMatch = LocationLookupService.resolveSync(cityDistrict);
    if (syncMatch != null) {
      resolvedLat = syncMatch.lat;
      resolvedLng = syncMatch.lng;
    }

    final ustalar = await getUstalar();
    final uIdx = ustalar.indexWhere((u) => normalizePhone(u.phone) == norm);
    final ustaId = uIdx >= 0 ? ustalar[uIdx].ustaId : 'usta-${DateTime.now().millisecondsSinceEpoch}';

    final initialHizmet = UstaHizmetIlan(
      id: 'ILN-${DateTime.now().millisecondsSinceEpoch % 9000 + 1000}',
      baslik: '$category Hizmeti',
      aciklama: 'Yerinde arıza tespiti, malzeme kontrolü ve profesyonel müdahale.',
      fiyat: baseServiceFee,
      tahminiSure: '30 dk',
      isDefault: true,
      konum: cityDistrict,
      lat: resolvedLat,
      lng: resolvedLng,
    );

    final ustaModel = NearbyUstaModel(
      ustaId: ustaId,
      fullName: fullName,
      phone: norm,
      kategori: category.toLowerCase().contains('elektrik')
          ? 'elektrik'
          : (category.toLowerCase().contains('tesisat')
              ? 'tesisat'
              : (category.toLowerCase().contains('çilingir') ? 'cilingir' : 'genel')),
      puan: 5.0,
      tamamlananIsSayisi: 0,
      latitude: resolvedLat,
      longitude: resolvedLng,
      mesafeMetre: 500,
      ustaHakedis: baseServiceFee,
      komisyonOrani: 0.15,
      komisyonTutari: baseServiceFee * 0.15,
      toplamTutar: baseServiceFee * 1.15,
      servisUcreti: baseServiceFee,
      deneyimYili: experienceYears,
      uzmanlikBasligi: '$cityDistrict • ${isOnayli ? '⭐ Onaylı Usta' : 'Uzman Usta'}',
      guvenceler: guvenceler,
      ilanlar: [initialHizmet],
    );

    if (uIdx >= 0) {
      ustalar[uIdx] = ustaModel;
    } else {
      ustalar.add(ustaModel);
    }
    await saveUstalar(ustalar);
    await saveUstaHizmetleri(norm, [initialHizmet]);
    await syncUstaHizmetListing(
      hizmet: initialHizmet,
      ustaName: fullName,
      ustaPhone: norm,
      ustaId: ustaId,
      ustaCategory: category,
      location: cityDistrict,
      lat: resolvedLat,
      lng: resolvedLng,
    );

    await saveActiveSession(
      phone: norm,
      fullName: fullName,
      role: 'usta',
      extra: profile,
    );
  }

  /// Aktif oturumu getirir (Cihaz/Tarayıcı yenilenince girişin korunması için)
  Future<Map<String, dynamic>?> getActiveSession() async {
    if (_cachedActiveSession != null) return Map.from(_cachedActiveSession!);

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kActiveSessionKey);
      if (raw != null) {
        _cachedActiveSession = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        return Map.from(_cachedActiveSession!);
      }
    } catch (e) {
      debugPrint('Aktif oturum yüklenirken hata: $e');
    }
    return null;
  }

  /// Aktif oturumu kaydeder
  Future<void> saveActiveSession({
    required String phone,
    required String fullName,
    required String role,
    Map<String, dynamic>? extra,
  }) async {
    final norm = normalizePhone(phone);
    final session = {
      'phone': norm,
      'full_name': fullName.trim(),
      'role': role.trim().toLowerCase(),
      'saved_at': DateTime.now().toIso8601String(),
      if (extra != null) ...extra,
    };
    _cachedActiveSession = session;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kActiveSessionKey, jsonEncode(session));
    } catch (e) {
      debugPrint('Aktif oturum kaydedilirken hata: $e');
    }
    _changesStreamController.add(null);
  }

  /// Oturumu kapatır (Çıkış yapıldığında oturumu temizler)
  Future<void> clearActiveSession() async {
    _cachedActiveSession = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kActiveSessionKey);
    } catch (e) {
      debugPrint('Aktif oturum silinirken hata: $e');
    }
    _changesStreamController.add(null);
  }

  // ==========================================
  // 6. FİNANSAL İŞLEMLER & HİZMET AKIŞI
  // ==========================================

  Future<List<Map<String, dynamic>>> getFinancialTransactions({bool forceRefresh = false}) async {
    if (_cachedFinancialTransactions != null && !forceRefresh) {
      return List.from(_cachedFinancialTransactions!);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kFinancialTransactionsKey);
      if (str != null && !forceRefresh) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          _cachedFinancialTransactions = List<Map<String, dynamic>>.from(decoded);
          return List.from(_cachedFinancialTransactions!);
        }
      }
    } catch (e) {
      debugPrint('Finansal verileri okuma hatası: $e');
    }

    try {
      final res = await http
          .get(Uri.parse('$_syncBaseUrl/api/financial_transactions'))
          .timeout(const Duration(seconds: 1));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          _cachedFinancialTransactions = List<Map<String, dynamic>>.from(data);
          _persistFinancialTransactionsToPrefs(_cachedFinancialTransactions!);
          return List.from(_cachedFinancialTransactions!);
        }
      }
    } catch (_) {}

    await _fetchServerData();
    if (_cachedFinancialTransactions != null) return List.from(_cachedFinancialTransactions!);

    _cachedFinancialTransactions = [];
    return [];
  }

  Future<void> saveFinancialTransactions(List<Map<String, dynamic>> list) async {
    _cachedFinancialTransactions = List.from(list);
    await _persistFinancialTransactionsToPrefs(list);
    _changesStreamController.add(null);
    _postToSyncServer('/api/financial_transactions', list);
  }

  Future<void> addOrUpdateFinancialTransaction(Map<String, dynamic> tx) async {
    final list = await getFinancialTransactions();
    final txId = (tx['id'] ?? tx['receipt_no'] ?? tx['cagri_id'] ?? '').toString();
    final receiptNo = (tx['receipt_no'] ?? '').toString();
    final cagriId = (tx['cagri_id'] ?? '').toString();

    final existingIndex = list.indexWhere((item) {
      final itemId = (item['id'] ?? '').toString();
      final itemReceipt = (item['receipt_no'] ?? '').toString();
      final itemCagri = (item['cagri_id'] ?? '').toString();
      return (txId.isNotEmpty && itemId == txId) ||
             (receiptNo.isNotEmpty && itemReceipt == receiptNo) ||
             (cagriId.isNotEmpty && itemCagri == cagriId);
    });

    if (existingIndex >= 0) {
      list[existingIndex] = {...list[existingIndex], ...tx};
    } else {
      list.insert(0, tx);
    }
    await saveFinancialTransactions(list);
  }

  void _syncCallsToDemoRepo(List<Map<String, dynamic>> list) {
    for (final raw in list) {
      try {
        final model = CagriModel.fromJson(raw);
        DemoCallRepository.save(model);
      } catch (_) {}
    }
  }

  Future<List<CagriModel>> getCagrilar({bool forceRefresh = false}) async {
    if (_cachedCagrilar == null || forceRefresh) {
      try {
        final res = await http
            .get(Uri.parse('$_syncBaseUrl/api/cagrilar'))
            .timeout(const Duration(seconds: 1));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is List) {
            _cachedCagrilar = List<Map<String, dynamic>>.from(data);
            _syncCallsToDemoRepo(_cachedCagrilar!);
          }
        }
      } catch (_) {}
    }
    return (_cachedCagrilar ?? []).map((json) {
      try {
        return CagriModel.fromJson(json);
      } catch (_) {
        return null;
      }
    }).whereType<CagriModel>().toList();
  }

  Future<CagriModel?> getCagriById(String cagriId) async {
    final list = await getCagrilar();
    try {
      return list.firstWhere((c) => c.id == cagriId);
    } catch (_) {
      return DemoCallRepository.get(cagriId);
    }
  }

  Future<void> saveOrUpdateCagri(CagriModel cagri) async {
    final json = cagri.toJson();
    _cachedCagrilar ??= [];
    final idx =
        _cachedCagrilar!.indexWhere((c) => (c['id'] ?? '').toString() == cagri.id);
    if (idx >= 0) {
      _cachedCagrilar![idx] = json;
    } else {
      _cachedCagrilar!.insert(0, json);
    }
    DemoCallRepository.save(cagri);
    _changesStreamController.add(null);
    _postToSyncServer('/api/cagri', json);
  }

  Future<void> updateCagriStatus(
    String cagriId,
    CagriDurumu newStatus, {
    bool? ustaArrived,
    bool? completionRequested,
    String? completionPhotoUrl,
    String? completionNote,
  }) async {
    final existing = await getCagriById(cagriId);
    if (existing != null) {
      final updated = existing.copyWith(
        durum: newStatus,
        ustaArrived: ustaArrived ?? existing.ustaArrived,
        completionRequested:
            completionRequested ?? existing.completionRequested,
        completionPhotoUrl: completionPhotoUrl ?? existing.completionPhotoUrl,
        completionNote: completionNote ?? existing.completionNote,
      );
      await saveOrUpdateCagri(updated);
    } else {
      DemoCallRepository.updateStatus(cagriId, newStatus);
    }
  }

  /// Admin panelinden canlı push/duyuru bildirimi gönderir
  Future<bool> sendAdminNotification(AppNotificationModel notif) async {
    try {
      final res = await http.post(
        Uri.parse('$_syncBaseUrl/api/notifications'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(notif.toJson()),
      ).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[AppDataService] Bildirim gönderme hatası: $e');
      return false;
    }
  }

  /// Sunucudaki geçmiş bildirimleri listeler
  Future<List<AppNotificationModel>> fetchServerNotifications() async {
    try {
      final res = await http.get(
        Uri.parse('$_syncBaseUrl/api/notifications'),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as List;
        return decoded
            .map((item) => AppNotificationModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (e) {
      debugPrint('[AppDataService] Bildirimleri çekme hatası: $e');
    }
    return [];
  }

  /// Sunucudaki tüm bildirimleri kalıcı olarak siler
  Future<bool> clearServerNotifications() async {
    try {
      final res = await http.post(
        Uri.parse('$_syncBaseUrl/api/notifications/clear'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        await NotificationService.instance.clearAll();
        _changesStreamController.add(null);
        return true;
      }
    } catch (e) {
      debugPrint('[AppDataService] Bildirimleri temizleme hatası: $e');
    }
    return false;
  }

  /// Sunucudan tekil bir bildirimi siler
  Future<bool> deleteServerNotification(String id) async {
    try {
      final res = await http.post(
        Uri.parse('$_syncBaseUrl/api/notifications/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id}),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        _changesStreamController.add(null);
        return true;
      }
    } catch (e) {
      debugPrint('[AppDataService] Tekil bildirim silme hatası: $e');
    }
    return false;
  }

  // ==========================================
  // KOMİSYON ORANLARI VE BLOKE KURALLARI
  // ==========================================

  static const String _kCommissionSettingsKey = 'app_commission_settings';

  Future<Map<String, dynamic>> getCommissionSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kCommissionSettingsKey);
      if (str != null) {
        final decoded = jsonDecode(str);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (_) {}

    final Map<String, dynamic> initialCategoryRates = {};
    for (final cat in defaultAppCategories) {
      final name = (cat['name'] ?? cat['title'] ?? '').toString();
      if (name.isNotEmpty) {
        initialCategoryRates[name] = 15.0;
      }
    }

    return {
      'default_rate': 15.0, // Varsayılan genel komisyon oranı %15
      'is_category_based': false, // Tüm kategoriler için genel oran mı yoksa kategoriye özel mi
      'category_rates': initialCategoryRates,
      'hold_days': 7, // 7 gün blokeli kalma kuralı
    };
  }

  Future<void> saveCommissionSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCommissionSettingsKey, jsonEncode(settings));
      _changesStreamController.add(null);
      _postToSyncServer('/api/commission_settings', settings);
    } catch (e) {
      debugPrint('[AppDataService] Komisyon ayarları kaydetme hatası: $e');
    }
  }

  Future<double> getCommissionRateForCategory(String? category) async {
    final settings = await getCommissionSettings();
    final defaultRate = (settings['default_rate'] as num?)?.toDouble() ?? 15.0;
    final isCategoryBased = settings['is_category_based'] == true;
    if (isCategoryBased && category != null && category.isNotEmpty) {
      final categoryRates = settings['category_rates'] as Map<String, dynamic>? ?? {};
      for (final entry in categoryRates.entries) {
        if (category.toLowerCase().contains(entry.key.toLowerCase()) ||
            entry.key.toLowerCase().contains(category.toLowerCase())) {
          return (entry.value as num?)?.toDouble() ?? defaultRate;
        }
      }
    }
    return defaultRate;
  }

  // ==========================================
  // USTA CÜZDAN & HAKEDİŞ YÖNETİMİ METODLARI
  // ==========================================

  static const String _kUstaIbanPrefix = 'app_usta_iban_';
  static const String _kUstaPayoutsPrefix = 'app_usta_payouts_';

  /// Ustanın kayıtlı IBAN bilgilerini getirir
  Future<Map<String, String>> getUstaIban(String phoneOrUstaId) async {
    final normPhone = normalizePhone(phoneOrUstaId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('$_kUstaIbanPrefix$normPhone') ??
                  prefs.getString('$_kUstaIbanPrefix$phoneOrUstaId');
      if (str != null) {
        final decoded = jsonDecode(str);
        if (decoded is Map) {
          return {
            'iban': (decoded['iban'] ?? '').toString(),
            'banka': (decoded['banka'] ?? '').toString(),
            'ad_soyad': (decoded['ad_soyad'] ?? '').toString(),
          };
        }
      }
    } catch (_) {}

    // Fallback usta profili veya varsayılan banka hesabı
    return {
      'iban': 'TR56 0006 2000 0001 2345 6789 01',
      'banka': 'Ziraat Bankası',
      'ad_soyad': 'Kadir Cebeci',
    };
  }

  /// Ustanın IBAN bilgilerini kalıcı olarak kaydeder
  Future<void> saveUstaIban(
    String phoneOrUstaId, {
    required String iban,
    required String banka,
    required String adSoyad,
  }) async {
    final normPhone = normalizePhone(phoneOrUstaId);
    final data = {
      'iban': iban.trim(),
      'banka': banka.trim(),
      'ad_soyad': adSoyad.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(data);
      if (normPhone.isNotEmpty) {
        await prefs.setString('$_kUstaIbanPrefix$normPhone', encoded);
      }
      await prefs.setString('$_kUstaIbanPrefix$phoneOrUstaId', encoded);
      _changesStreamController.add(null);
    } catch (e) {
      debugPrint('[AppDataService] IBAN kaydetme hatası: $e');
    }
  }

  /// Ustanın geçmiş para çekim / hakediş transfer taleplerini getirir
  Future<List<Map<String, dynamic>>> getUstaPayoutRequests(String phoneOrUstaId) async {
    final normPhone = normalizePhone(phoneOrUstaId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('$_kUstaPayoutsPrefix$normPhone') ??
                  prefs.getString('$_kUstaPayoutsPrefix$phoneOrUstaId');
      if (str != null) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(decoded);
        }
      }
    } catch (_) {}

    // İlk defa açıldığında ustanın profesyonel geçmiş çekim kayıtları
    final defaultPayouts = <Map<String, dynamic>>[
      {
        'id': 'WD-9041',
        'tutar': 15000.0,
        'iban': 'TR56 0006 2000 0001 2345 6789 01',
        'banka': 'Ziraat Bankası',
        'ad_soyad': 'Kadir Cebeci',
        'tarih': '15 Kasım 2026, 14:20',
        'durum': 'Tamamlandı (Hesaba Aktarıldı)',
        'dekont_no': 'EFT-20261115-8841',
      },
      {
        'id': 'WD-8120',
        'tutar': 22500.0,
        'iban': 'TR56 0006 2000 0001 2345 6789 01',
        'banka': 'Ziraat Bankası',
        'ad_soyad': 'Kadir Cebeci',
        'tarih': '08 Kasım 2026, 11:45',
        'durum': 'Tamamlandı (Hesaba Aktarıldı)',
        'dekont_no': 'EFT-20261108-5102',
      },
      {
        'id': 'WD-7304',
        'tutar': 18200.0,
        'iban': 'TR56 0006 2000 0001 2345 6789 01',
        'banka': 'Ziraat Bankası',
        'ad_soyad': 'Kadir Cebeci',
        'tarih': '01 Kasım 2026, 16:10',
        'durum': 'Tamamlandı (Hesaba Aktarıldı)',
        'dekont_no': 'EFT-20261101-2094',
      },
    ];

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = normPhone.isNotEmpty ? '$_kUstaPayoutsPrefix$normPhone' : '$_kUstaPayoutsPrefix$phoneOrUstaId';
      await prefs.setString(key, jsonEncode(defaultPayouts));
    } catch (_) {}

    return defaultPayouts;
  }

  /// Yeni çekim talebi oluşturur
  Future<bool> createUstaPayoutRequest(
    String phoneOrUstaId, {
    required double amount,
    required String iban,
    required String banka,
    required String adSoyad,
  }) async {
    final list = await getUstaPayoutRequests(phoneOrUstaId);
    final randomId = 'WD-${1000 + DateTime.now().millisecond + list.length * 10}';
    final now = DateTime.now();
    final months = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    final dateStr = '${now.day} ${months[now.month - 1]} ${now.year}, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final newRequest = {
      'id': randomId,
      'tutar': amount,
      'iban': iban,
      'banka': banka,
      'ad_soyad': adSoyad,
      'tarih': dateStr,
      'durum': 'İşlemde (Bankaya İletildi)',
      'dekont_no': 'EFT-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${1000 + list.length}',
    };

    list.insert(0, newRequest);

    final normPhone = normalizePhone(phoneOrUstaId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(list);
      if (normPhone.isNotEmpty) {
        await prefs.setString('$_kUstaPayoutsPrefix$normPhone', encoded);
      }
      await prefs.setString('$_kUstaPayoutsPrefix$phoneOrUstaId', encoded);
      _changesStreamController.add(null);
      return true;
    } catch (e) {
      debugPrint('[AppDataService] Çekim talebi kaydetme hatası: $e');
      return false;
    }
  }

  /// Ustanın müşteri bazlı detaylı kazanç ve iş geçmişini derler
  Future<List<Map<String, dynamic>>> getUstaDetailedJobEarnings(String phoneOrUstaId) async {
    final normPhone = normalizePhone(phoneOrUstaId);
    final allTx = await getFinancialTransactions();
    final allCalls = await getCagrilar();

    final List<Map<String, dynamic>> results = [];
    final Set<String> processedKeys = {};

    // 1. Gerçek finansal işlemlerden filtrele
    for (final tx in allTx) {
      final txPhone = normalizePhone((tx['usta_tel'] ?? '').toString());
      if (normPhone.isEmpty || txPhone == normPhone || (tx['usta_id'] ?? '').toString().contains(normPhone)) {
        final key = (tx['receipt_no'] ?? tx['cagri_id'] ?? tx['id'] ?? '').toString();
        if (key.isNotEmpty && !processedKeys.contains(key)) {
          processedKeys.add(key);
          results.add({
            'id': key,
            'musteri_ad': tx['musteri_ad'] ?? 'Bilinmeyen Müşteri',
            'musteri_tel': tx['musteri_tel'] ?? '',
            'musteri_adres': tx['musteri_adres'] ?? 'Sandıklı, Afyonkarahisar',
            'hizmet_baslik': tx['hizmet_baslik'] ?? 'Standart Servis & Arıza Onarımı',
            'toplam_tutar': (tx['toplam_tutar'] as num?)?.toDouble() ?? 750.0,
            'komisyon_tutari': (tx['komisyon_tutari'] as num?)?.toDouble() ?? 112.5,
            'usta_hakedis': (tx['usta_hakedis'] as num?)?.toDouble() ?? 637.5,
            'durum': tx['durum'] ?? 'Tamamlandı (Provizyon Çözüldü)',
            'puan': (tx['puan'] as num?)?.toDouble() ?? 5.0,
            'tarih': tx['created_at']?.toString() ?? 'Bugün',
            'yorum': tx['yorum'] ?? 'Hızlı ve kaliteli hizmet için ustama teşekkür ederim.',
          });
        }
      }
    }

    // 2. Tamamlanan çağrılardan ekle
    for (final call in allCalls) {
      final cPhone = normalizePhone(call.ustaPhone ?? '');
      if (call.durum == CagriDurumu.tamamlandi && (normPhone.isEmpty || cPhone == normPhone)) {
        if (!processedKeys.contains(call.id)) {
          processedKeys.add(call.id);
          final toplam = call.toplamTutar ?? 750.0;
          final hakedis = call.ustaHakedis ?? (toplam * 0.85);
          final komisyon = call.komisyonTutari ?? (toplam - hakedis);
          results.add({
            'id': call.id,
            'musteri_ad': call.musteriFullName ?? 'Müşteri',
            'musteri_tel': call.musteriPhone ?? '',
            'musteri_adres': call.adresTarifi ?? 'Sandıklı, Afyonkarahisar',
            'hizmet_baslik': 'Standart Servis & Arıza Onarımı',
            'toplam_tutar': toplam,
            'komisyon_tutari': komisyon,
            'usta_hakedis': hakedis,
            'durum': 'Tamamlandı (Provizyon Çözüldü)',
            'puan': 5.0,
            'tarih': '${call.createdAt.day}.${call.createdAt.month}.${call.createdAt.year}',
            'yorum': 'Çok memnun kaldım, zamanında geldi ve işini titizlikle bitirdi.',
          });
        }
      }
    }

    // 3. Eğer toplam kayıt 4'ten azsa, ustanın panelinde zengin ve profesyonel müşteri verileri göster
    if (results.length < 5) {
      final sampleCustomers = [
        {
          'id': 'TR-89450',
          'musteri_ad': 'Kemal Vural',
          'musteri_tel': '0532 123 45 67',
          'musteri_adres': 'Ece Mah. Afyon Cad. No: 5, Sandıklı',
          'hizmet_baslik': 'Elektrik Pano Arızası & Sigorta Değişimi',
          'toplam_tutar': 1750.0,
          'komisyon_tutari': 262.5,
          'usta_hakedis': 1487.5,
          'durum': 'Tamamlandı (7 Gün Blokeli)',
          'puan': 5.0,
          'tarih': 'Bugün, 11:20',
          'iso_date': '2026-11-22T11:20:00',
          'yorum': 'Bugün hemen gelip arızayı çözdü, çok teşekkürler.',
        },
        {
          'id': 'TR-89412',
          'musteri_ad': 'Esra Cebeci',
          'musteri_tel': '0553 412 88 90',
          'musteri_adres': 'Ece Mah. Atatürk Cad. No: 14, Sandıklı',
          'hizmet_baslik': 'Kombi Bakımı & Petek Temizliği',
          'toplam_tutar': 2400.0,
          'komisyon_tutari': 360.0,
          'usta_hakedis': 2040.0,
          'durum': 'Tamamlandı (7 Gün Blokeli)',
          'puan': 5.0,
          'tarih': '21 Kasım 2026, 16:45',
          'iso_date': '2026-11-21T16:45:00',
          'yorum': 'Kadir usta tam vaktinde geldi, kombiyi ve tüm petekleri tertemiz yaptı.',
        },
        {
          'id': 'TR-89390',
          'musteri_ad': 'Zeynep Kaya',
          'musteri_tel': '0542 618 22 14',
          'musteri_adres': 'Çakır Mah. Yunus Emre Cad. No: 8, Sandıklı',
          'hizmet_baslik': 'Elektrik Tesisatı & Kaçak Akım Rölesi Değişimi',
          'toplam_tutar': 1850.0,
          'komisyon_tutari': 277.5,
          'usta_hakedis': 1572.5,
          'durum': 'Tamamlandı (7 Gün Blokeli)',
          'puan': 5.0,
          'tarih': '20 Kasım 2026, 13:15',
          'iso_date': '2026-11-20T13:15:00',
          'yorum': 'Sigorta sürekli atıyordu, 20 dakikada arızayı bulup çözdü. Ellerine sağlık.',
        },
        {
          'id': 'TR-89245',
          'musteri_ad': 'Ahmet Demir',
          'musteri_tel': '0533 912 34 56',
          'musteri_adres': 'Koçhisar Mah. İstasyon Cad. No: 22, Sandıklı',
          'hizmet_baslik': 'Acil Çilingir & Çelik Kapı Kilit Göbeği Montajı',
          'toplam_tutar': 1200.0,
          'komisyon_tutari': 180.0,
          'usta_hakedis': 1020.0,
          'durum': 'Tamamlandı (7 Gün Blokeli)',
          'puan': 5.0,
          'tarih': '19 Kasım 2026, 21:30',
          'iso_date': '2026-11-19T21:30:00',
          'yorum': 'Gece kapıda kalmıştık, 15 dakikada ulaştı ve kapıya hiç zarar vermeden açtı.',
        },
        {
          'id': 'TR-89102',
          'musteri_ad': 'Murat Yılmaz',
          'musteri_tel': '0544 555 77 88',
          'musteri_adres': 'Sandıklı Merkez, Afyonkarahisar',
          'hizmet_baslik': 'Banyo Bataryası & Su Tesisatı Onarımı',
          'toplam_tutar': 950.0,
          'komisyon_tutari': 142.5,
          'usta_hakedis': 807.5,
          'durum': 'Tamamlandı (Bloke Çözüldü)',
          'puan': 5.0,
          'tarih': '14 Kasım 2026, 10:20',
          'iso_date': '2026-11-14T10:20:00',
          'yorum': 'Su sızıntısını anında giderdi, malzeme kalitesi ve işçiliği çok iyi.',
        },
        {
          'id': 'TR-88980',
          'musteri_ad': 'Fatma Şahin',
          'musteri_tel': '0535 667 89 01',
          'musteri_adres': 'Bolvadin Yolu Üzeri, Sandıklı',
          'hizmet_baslik': 'Aydınlatma & Led Spot Montajı',
          'toplam_tutar': 1600.0,
          'komisyon_tutari': 240.0,
          'usta_hakedis': 1360.0,
          'durum': 'Tamamlandı (Bloke Çözüldü)',
          'puan': 5.0,
          'tarih': '10 Kasım 2026, 15:00',
          'iso_date': '2026-11-10T15:00:00',
          'yorum': 'Tüm salonun avize ve led montajlarını kusursuz yaptı. Çok saygılı bir usta.',
        },
        {
          'id': 'TR-88844',
          'musteri_ad': 'Hasan Ali Çelik',
          'musteri_tel': '0552 890 12 34',
          'musteri_adres': 'Ece Mah. 102. Sok. Sandıklı',
          'hizmet_baslik': 'Şofben Arıza Tespiti & Termostat Değişimi',
          'toplam_tutar': 1450.0,
          'komisyon_tutari': 217.5,
          'usta_hakedis': 1232.5,
          'durum': 'Tamamlandı (Bloke Çözüldü)',
          'puan': 4.9,
          'tarih': '05 Kasım 2026, 17:40',
          'iso_date': '2026-11-05T17:40:00',
          'yorum': 'Sıcak su gelmiyordu, parça değişimi yapıp test etti. Güvenilir usta.',
        },
      ];

      for (final sample in sampleCustomers) {
        if (!processedKeys.contains(sample['id'])) {
          results.add(sample);
        }
      }
    }

    // 4. Her işlem için 7 Gün Provizyon Blokesi Hesaplaması (Bugün yapılan en az 7 gün blokeli kalır)
    final now = DateTime.now();
    for (final item in results) {
      DateTime? itemDate;
      if (item['iso_date'] != null) {
        itemDate = DateTime.tryParse(item['iso_date'].toString());
      }
      if (itemDate == null && item['tarih'] != null) {
        final tStr = item['tarih'].toString();
        if (tStr.toLowerCase().contains('bugün')) {
          itemDate = now;
        } else {
          try {
            final months = {
              'ocak': 1, 'şubat': 2, 'mart': 3, 'nisan': 4, 'mayıs': 5, 'haziran': 6,
              'temmuz': 7, 'ağustos': 8, 'eylül': 9, 'ekim': 10, 'kasım': 11, 'aralık': 12
            };
            final parts = tStr.split(' ');
            if (parts.length >= 3) {
              final d = int.tryParse(parts[0]);
              final m = months[parts[1].toLowerCase()];
              final y = int.tryParse(parts[2].replaceAll(',', ''));
              if (d != null && m != null && y != null) {
                itemDate = DateTime(y, m, d);
              }
            }
          } catch (_) {}
        }
      }
      itemDate ??= now;

      final diffDays = now.difference(itemDate).inDays;
      final bool isBlocked = diffDays < 7;
      final int remainingDays = isBlocked ? (7 - diffDays) : 0;

      item['is_blocked'] = isBlocked;
      item['remaining_days'] = remainingDays;
      item['completion_date'] = itemDate;

      if (isBlocked) {
        item['durum_etiketi'] = '7 Gün Blokeli ($remainingDays gün kaldı)';
        item['durum_aciklama'] = diffDays == 0
            ? 'Bugün tamamlandı. 7 günlük İyzico provizyon güvencesi blokesindedir.'
            : '$diffDays gün önce tamamlandı. Kalan $remainingDays gün sonra çekilebilir bakiyenize aktarılacaktır.';
      } else {
        item['durum_etiketi'] = 'Bloke Çözüldü • Çekilebilir';
        item['durum_aciklama'] = '7 günlük yasal provizyon koruma süresi tamamlandı. Hakediş anında çekilebilir.';
      }
    }

    return results;
  }

  Future<void> clearAll() async {
    _cachedUstalar = [];
    _cachedJobs = [];
    _cachedMembers = [];
    _cachedFinancialTransactions = [];
    await _persistUstalarToPrefs([]);
    await _persistJobsToPrefs([]);
    await _persistFinancialTransactionsToPrefs([]);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kMembersKey, '[]');
    } catch (_) {}
    _changesStreamController.add(null);
    _postToSyncServer('/api/clear_all', {});
  }

}
