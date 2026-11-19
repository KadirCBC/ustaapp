import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ustaapp/core/services/location_lookup_service.dart';
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
          if (data['categories'] is List && (data['categories'] as List).isNotEmpty) {
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
      } else if (event == 'ustalar_updated' && data is List) {
        _cachedUstalar = data
            .map((item) => NearbyUstaModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _persistUstalarToPrefs(_cachedUstalar!);
        _changesStreamController.add(null);
      } else if (event == 'jobs_updated' && data is List) {
        _cachedJobs = List<Map<String, dynamic>>.from(data);
        _persistJobsToPrefs(_cachedJobs!);
        _changesStreamController.add(null);
      } else if (event == 'categories_updated' && data is List) {
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
        _changesStreamController.add(null);
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
    _cachedUstalar = List.from(ustalar);
    final list = ustalar.map((u) => u.toJson()).toList();
    await _persistUstalarToPrefs(ustalar);
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

      if (matchingUsta != null && matchingUsta.latitude != 0.0 && matchingUsta.longitude != 0.0) {
        lat = matchingUsta.latitude;
        lng = matchingUsta.longitude;
        if (matchingUsta.uzmanlikBasligi.isNotEmpty) {
          district = matchingUsta.uzmanlikBasligi;
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

  Future<void> deleteUsta(String ustaId) async {
    final list = await getUstalar();
    list.removeWhere((u) => u.ustaId == ustaId);
    await saveUstalar(list);
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

  Future<List<Map<String, dynamic>>> getCategories() async {
    if (_cachedCategories != null) return List.from(_cachedCategories!);

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCategoriesKey);
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw);
        _cachedCategories = list.map((e) => Map<String, dynamic>.from(e)).toList();
        return List.from(_cachedCategories!);
      }
    } catch (e) {
      debugPrint('Kategoriler yüklenirken hata: $e');
    }

    _cachedCategories = const [
      {'title': 'Elektrik & Aydınlatma', 'icon': '⚡', 'count': '3 Usta'},
      {'title': 'Sıhhi Tesisat & Su Kaçağı', 'icon': '🚰', 'count': '3 Usta'},
      {'title': 'Çilingir & Kapı Açma', 'icon': '🔑', 'count': '3 Usta'},
      {'title': 'Klima & Kombi Servisi', 'icon': '❄️', 'count': '2 Usta'},
      {'title': 'Boya, Alçı & Dekorasyon', 'icon': '🎨', 'count': '1 Usta'},
    ];
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

    // 2. Varsayılan kullanıcıları (Demo Kadir Usta ve Ahmet Demir) ekle
    if (!_cachedRegisteredUsers!.containsKey('5524342069')) {
      _cachedRegisteredUsers!['5524342069'] = {
        'phone': '5524342069',
        'full_name': 'Kadir Usta',
        'role': 'usta',
        'registered_at': DateTime.now().toIso8601String(),
      };
    }
    if (!_cachedRegisteredUsers!.containsKey('5329998877')) {
      _cachedRegisteredUsers!['5329998877'] = {
        'phone': '5329998877',
        'full_name': 'Ahmet Demir',
        'role': 'musteri',
        'registered_at': DateTime.now().toIso8601String(),
      };
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
