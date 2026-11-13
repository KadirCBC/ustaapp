import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final appDataServiceProvider = Provider<AppDataService>((ref) {
  return AppDataService();
});

/// Mobil Uygulama ve Admin Paneli Arasındaki Ortak Merkezi Veri Servisi (Single Source of Truth)
/// Admin panelden eklenen, silinen veya düzenlenen her usta, ilan, kategori ve harita pini
/// anında bu servis üzerinden yerel kalıcı hafızaya (SharedPreferences) kaydedilir ve
/// mobil uygulamadaki harita, kategori çubukları ve usta ekranları tarafından canlı kullanılır.
class AppDataService {
  static const String _kUstalarKey = 'app_shared_ustalar';
  static const String _kCategoriesKey = 'app_shared_categories';
  static const String _kJobsKey = 'app_shared_jobs';
  static const String _kTedarikcilerKey = 'app_shared_tedarikciler';
  static const String _kMapPinsKey = 'app_shared_map_pins';
  static const String _kMembersKey = 'app_shared_members';
  static const String _kPendingUstalarKey = 'app_shared_pending_ustalar';

  static const int _kSyncPort = 8090;

  final StreamController<void> _changesStreamController = StreamController<void>.broadcast();
  Stream<void> get onDataChanged => _changesStreamController.stream;

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  bool _isConnectingWs = false;
  Timer? _reconnectTimer;
  bool _isSyncInitialized = false;

  String get _syncHost {
    if (kIsWeb) {
      final host = Uri.base.host;
      return (host.isNotEmpty && host != '0.0.0.0') ? host : 'localhost';
    }
    // Android emulator: adb reverse forwards 127.0.0.1:8090 to host
    return '127.0.0.1';
  }

  String get _syncBaseUrl => 'http://$_syncHost:$_kSyncPort';
  String get _syncWsUrl => 'ws://$_syncHost:$_kSyncPort/ws';

  AppDataService() {
    initRealtimeSync();
  }

  void initRealtimeSync() {
    if (_isSyncInitialized) return;
    _isSyncInitialized = true;
    _connectWebSocket();
    _fetchServerData();
  }

  void _connectWebSocket() {
    if (_isConnectingWs) return;
    _isConnectingWs = true;

    try {
      final uri = Uri.parse(_syncWsUrl);
      final channel = WebSocketChannel.connect(uri);
      _wsChannel = channel;

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

  // Bellek İçi Önbellek (Hızlı erişim için)
  List<NearbyUstaModel>? _cachedUstalar;
  List<Map<String, dynamic>>? _cachedCategories;
  List<Map<String, dynamic>>? _cachedJobs;
  List<Map<String, dynamic>>? _cachedTedarikciler;
  List<Map<String, dynamic>>? _cachedPins;
  List<Map<String, dynamic>>? _cachedMembers;
  List<Map<String, dynamic>>? _cachedPending;

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
    final allUstalar = await getUstalar();
    final normalizedCat = category.trim().toLowerCase();

    final filtered = allUstalar.where((u) {
      final ustaCat = u.kategori.trim().toLowerCase();
      final catMatch = (normalizedCat == 'tümü' || normalizedCat == 'all')
          ? true
          : (ustaCat.contains(normalizedCat) || normalizedCat.contains(ustaCat));
      if (!catMatch) return false;

      final dist = Geolocator.distanceBetween(
        customerLat,
        customerLng,
        u.latitude,
        u.longitude,
      );
      return dist <= maxRadiusMeter;
    }).map((u) {
      final dist = Geolocator.distanceBetween(
        customerLat,
        customerLng,
        u.latitude,
        u.longitude,
      );
      return u.copyWith(mesafeMetre: dist > 0 ? dist : u.mesafeMetre);
    }).toList();

    filtered.sort((a, b) => a.mesafeMetre.compareTo(b.mesafeMetre));
    return filtered;
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

    // 1. Ustalara bağlı hizmet ilanları
    for (final usta in ustalar) {
      for (final ilan in usta.ilanlar) {
        result.add({
          'id': ilan.id,
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

    // 2. Müşteri servis çağrıları ve genel aktif işler
    final jobs = await getActiveJobs();
    for (final job in jobs) {
      final rawPrice = job['price'];
      double parsedPrice = 500.0;
      if (rawPrice is num) {
        parsedPrice = rawPrice.toDouble();
      } else if (rawPrice is String) {
        parsedPrice = double.tryParse(rawPrice.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 500.0;
      }

      result.add({
        'id': job['id'] ?? 'job-${DateTime.now().millisecondsSinceEpoch}',
        'title': job['title'] ?? 'Servis Talebi',
        'description': job['description'] ?? '${job['customer_name'] ?? 'Müşteri'} - ${job['category'] ?? 'Genel'} (${job['district'] ?? 'Kadıköy'})',
        'price': parsedPrice,
        'duration': '30 dk',
        'icon': '📋',
        'kategori': job['category'] ?? job['kategori'] ?? 'Genel',
        'category': job['category'] ?? job['kategori'] ?? 'elektrik',
        'district': job['district'] ?? 'Kadıköy',
        'customer_name': job['customer_name'] ?? 'Müşteri Talebi',
        'customer_phone': job['customer_phone'] ?? '+90 5XX XXX XX XX',
        'status': job['status'] ?? 'Bekliyor',
        'assigned_usta': job['assigned_usta'] ?? '— (Atama Bekliyor)',
        'created_at': job['time'] ?? 'Yeni',
        'usta_id': job['usta_id'] ?? '',
        'usta_name': job['customer_name'] ?? 'Müşteri Talebi',
        'type': 'Müşteri İş Çağrısı',
      });
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

    _cachedCategories = _getDefaultCategories();
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

    _cachedTedarikciler = _getDefaultTedarikciler();
    await saveTedarikciler(_cachedTedarikciler!);
    return List.from(_cachedTedarikciler!);
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

    _cachedPins = _getDefaultMapPins();
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

  Future<void> clearAll() async {
    _cachedUstalar = [];
    _cachedJobs = [];
    _cachedMembers = [];
    await _persistUstalarToPrefs([]);
    await _persistJobsToPrefs([]);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kMembersKey, '[]');
    } catch (_) {}
    _changesStreamController.add(null);
    _postToSyncServer('/api/clear_all', {});
  }

  // ==========================================
  // 7. VARSAYILAN SİSTEM VERİLERİ (İLK ÇALIŞMA)
  // ==========================================

  List<NearbyUstaModel> _getDefaultUstalar() {
    const lat = 40.9905;
    const lng = 29.0270;

    return [
      // 1. Elektrik Ustaları
      NearbyUstaModel(
        ustaId: 'demo-usta-1',
        fullName: 'Ahmet Yılmaz',
        phone: '+90 532 111 22 33',
        kategori: 'elektrik',
        puan: 4.9,
        tamamlananIsSayisi: 142,
        latitude: lat + 0.0042,
        longitude: lng + 0.0034,
        mesafeMetre: 850,
        ustaHakedis: 800.0,
        komisyonOrani: 0.15,
        komisyonTutari: 120.0,
        toplamTutar: 920.0,
        servisUcreti: 200.0,
        deneyimYili: 14,
        uzmanlikBasligi: 'Yetkili Elektrik & Akıllı Ev Teknisyeni',
        guvenceler: const [
          '30 Gün İşçilik Garantisi',
          'Sabit Fiyat Güvencesi',
          'MYK Belgeli',
          'Hızlı Varış',
        ],
        ilanlar: const [
          UstaHizmetIlan(
            id: 'e1-1',
            baslik: 'Temel Arıza Tespiti & Sigorta Kontrolü',
            aciklama: 'Yerinde voltaj ölçümü, arızalı hat izolasyonu ve güvenli onarım.',
            fiyat: 800.0,
            tahminiSure: '30 dk',
            ikon: '⚡',
            isDefault: true,
          ),
          UstaHizmetIlan(
            id: 'e1-2',
            baslik: 'Sigorta Panosu & Kaçak Akım Rölesi Montajı',
            aciklama: 'Eski sigortaların yenilenmesi, yangın ve kaçak koruma rölesi.',
            fiyat: 950.0,
            tahminiSure: '45 dk',
            ikon: '🛡️',
          ),
        ],
      ),
      NearbyUstaModel(
        ustaId: 'demo-usta-2',
        fullName: 'Hasan Çetin',
        phone: '+90 544 222 33 44',
        kategori: 'elektrik',
        puan: 4.8,
        tamamlananIsSayisi: 98,
        latitude: lat - 0.0052,
        longitude: lng - 0.0041,
        mesafeMetre: 1400,
        ustaHakedis: 650.0,
        komisyonOrani: 0.15,
        komisyonTutari: 97.5,
        toplamTutar: 747.5,
        servisUcreti: 150.0,
        deneyimYili: 9,
        uzmanlikBasligi: 'Usta Elektrikçi & Aydınlatma Montajı',
        guvenceler: const [
          'Hızlı Müdahale (~15 dk)',
          'TSE Standartlarında Malzeme',
          'Faturalı Hizmet',
        ],
        ilanlar: const [
          UstaHizmetIlan(
            id: 'e2-1',
            baslik: 'Priz / Anahtar Hat Çekimi & Değişimi',
            aciklama: 'Yanmış prizlerin değişimi, çocuk korumalı yeni priz montajı.',
            fiyat: 400.0,
            tahminiSure: '25 dk',
            ikon: '🔌',
            isDefault: true,
          ),
          UstaHizmetIlan(
            id: 'e2-2',
            baslik: 'Avize & LED Spot Aydınlatma Montajı',
            aciklama: 'Tavana sağlam dübelleme ve modern aydınlatma bağlantısı.',
            fiyat: 500.0,
            tahminiSure: '35 dk',
            ikon: '💡',
          ),
        ],
      ),
      NearbyUstaModel(
        ustaId: 'demo-usta-3',
        fullName: 'Serkan Yıldırım',
        phone: '+90 555 333 44 55',
        kategori: 'elektrik',
        puan: 5.0,
        tamamlananIsSayisi: 215,
        latitude: lat + 0.0068,
        longitude: lng - 0.0058,
        mesafeMetre: 2400,
        ustaHakedis: 550.0,
        komisyonOrani: 0.15,
        komisyonTutari: 82.5,
        toplamTutar: 632.5,
        servisUcreti: 120.0,
        deneyimYili: 12,
        uzmanlikBasligi: 'Pratik Elektrik & Kablolama Uzmanı',
        guvenceler: const [
          'Ekonomik Fiyat Garantisi',
          'İşçilik Garantisi',
          'Temiz Çalışma',
        ],
        ilanlar: const [
          UstaHizmetIlan(
            id: 'e3-1',
            baslik: 'Kaçak Tespiti & Hızlı Müdahale',
            aciklama: 'Kısa devre yapan hatların tespiti ve acil onarımı.',
            fiyat: 550.0,
            tahminiSure: '20 dk',
            ikon: '⚡',
            isDefault: true,
          ),
          UstaHizmetIlan(
            id: 'e3-2',
            baslik: 'Aydınlatma & Zil Tesisatı Tamiri',
            aciklama: 'Bina içi diafon, kapı otomatiği ve zil hattı onarımı.',
            fiyat: 450.0,
            tahminiSure: '30 dk',
            ikon: '🔔',
          ),
        ],
      ),

      // 2. Tesisat Ustaları
      NearbyUstaModel(
        ustaId: 'demo-tesisat-1',
        fullName: 'Murat Kaya',
        phone: '+90 532 111 22 33',
        kategori: 'tesisat',
        puan: 4.9,
        tamamlananIsSayisi: 189,
        latitude: lat + 0.0042,
        longitude: lng + 0.0034,
        mesafeMetre: 850,
        ustaHakedis: 800.0,
        komisyonOrani: 0.15,
        komisyonTutari: 120.0,
        toplamTutar: 920.0,
        servisUcreti: 200.0,
        deneyimYili: 16,
        uzmanlikBasligi: 'Sıhhi Tesisat & Termal Kaçak Tespiti Uzmanı',
        guvenceler: const [
          'Kırmadan Cihazlı Tespit',
          '30 Gün İşçilik Garantisi',
          'TSE Belgeli Malzeme',
          'Garantili Onarım',
        ],
        ilanlar: const [
          UstaHizmetIlan(
            id: 't1-1',
            baslik: 'Cihazla Kırmadan Su Kaçağı Tespiti',
            aciklama: 'Termal kamera ve akustik frekans dinleme ile noktasal tespit.',
            fiyat: 800.0,
            tahminiSure: '30-45 dk',
            ikon: '🔍',
            isDefault: true,
          ),
          UstaHizmetIlan(
            id: 't1-2',
            baslik: 'Robot Makineyle Tıkanıklık Açma',
            aciklama: 'Spiral çelik robotla banyo, mutfak pimaş gideri açımı.',
            fiyat: 850.0,
            tahminiSure: '40 dk',
            ikon: '🚿',
          ),
          UstaHizmetIlan(
            id: 't1-3',
            baslik: 'Batarya / Musluk Değişimi & Montajı',
            aciklama: 'Aç-kapa lavabo veya eviye bataryası montajı ve sızdırmazlık.',
            fiyat: 400.0,
            tahminiSure: '25 dk',
            ikon: '🚰',
          ),
        ],
      ),
      NearbyUstaModel(
        ustaId: 'demo-tesisat-2',
        fullName: 'Selim Arslan',
        phone: '+90 544 222 33 44',
        kategori: 'tesisat',
        puan: 4.8,
        tamamlananIsSayisi: 130,
        latitude: lat - 0.0052,
        longitude: lng - 0.0041,
        mesafeMetre: 1400,
        ustaHakedis: 650.0,
        komisyonOrani: 0.15,
        komisyonTutari: 97.5,
        toplamTutar: 747.5,
        servisUcreti: 150.0,
        deneyimYili: 11,
        uzmanlikBasligi: 'Acil Tesisatçı & Musluk / Gider Ustası',
        guvenceler: const [
          'Hızlı Müdahale',
          'İşçilik Garantisi',
          'Orijinal Parça Garantisi',
        ],
        ilanlar: const [
          UstaHizmetIlan(
            id: 't2-1',
            baslik: 'Acil Tesisat Onarımı & Keşif',
            aciklama: 'Patlayan boru, damlatan vana tespiti ve acil tamir.',
            fiyat: 650.0,
            tahminiSure: '30 dk',
            ikon: '🔧',
            isDefault: true,
          ),
          UstaHizmetIlan(
            id: 't2-2',
            baslik: 'Musluk Tamiri & Salmastra Değişimi',
            aciklama: 'Su damlatan muslukların conta ve salmastra onarımı.',
            fiyat: 320.0,
            tahminiSure: '20 dk',
            ikon: '💧',
          ),
        ],
      ),
      NearbyUstaModel(
        ustaId: 'demo-tesisat-3',
        fullName: 'Burak Aydın',
        phone: '+90 555 333 44 55',
        kategori: 'tesisat',
        puan: 5.0,
        tamamlananIsSayisi: 245,
        latitude: lat + 0.0068,
        longitude: lng - 0.0058,
        mesafeMetre: 2400,
        ustaHakedis: 550.0,
        komisyonOrani: 0.15,
        komisyonTutari: 82.5,
        toplamTutar: 632.5,
        servisUcreti: 120.0,
        deneyimYili: 9,
        uzmanlikBasligi: 'Pratik Tesisat & Gider Temizleme Ustası',
        guvenceler: const [
          'Ekonomik Fiyat',
          'Hızlı Servis',
          'Müşteri Memnuniyeti',
        ],
        ilanlar: const [
          UstaHizmetIlan(
            id: 't3-1',
            baslik: 'Lavabo / Eviye Gider Temizliği',
            aciklama: 'Tıkanan eviye sifonunun temizlenmesi ve conta yenileme.',
            fiyat: 550.0,
            tahminiSure: '20 dk',
            ikon: '🚿',
            isDefault: true,
          ),
        ],
      ),

      // 3. Çilingir Ustaları
      NearbyUstaModel(
        ustaId: 'demo-cilingir-1',
        fullName: 'Kemal Demir',
        phone: '+90 532 111 22 33',
        kategori: 'cilingir',
        puan: 4.9,
        tamamlananIsSayisi: 174,
        latitude: lat + 0.0042,
        longitude: lng + 0.0034,
        mesafeMetre: 850,
        ustaHakedis: 800.0,
        komisyonOrani: 0.15,
        komisyonTutari: 120.0,
        toplamTutar: 920.0,
        servisUcreti: 200.0,
        deneyimYili: 15,
        uzmanlikBasligi: 'Yetkili Çilingir & Kilit Güvenlik Uzmanı',
        guvenceler: const [
          'Hasarsız Açım Garantisi',
          '30 Gün İşçilik Garantisi',
          'Orijinal Kale / Yale Kilit',
          'MYK Yetki Belgeli',
        ],
        ilanlar: const [
          UstaHizmetIlan(
            id: 'c1-1',
            baslik: 'Çelik Kapı / Kilit Açımı (Hasarsız)',
            aciklama: 'Özel aparatlarla kapı ve kasaya hasar vermeden kilit açımı.',
            fiyat: 800.0,
            tahminiSure: '15-20 dk',
            ikon: '🔑',
            isDefault: true,
          ),
          UstaHizmetIlan(
            id: 'c1-2',
            baslik: 'Barel (Göbek) Değişimi & 3 Anahtar',
            aciklama: 'Yüksek güvenlikli bilyalı barel montajı ve yeni anahtar teslimi.',
            fiyat: 650.0,
            tahminiSure: '20 dk',
            ikon: '🔒',
          ),
          UstaHizmetIlan(
            id: 'c1-3',
            baslik: 'Oto Kapı Açımı (Hasarsız Acil)',
            aciklama: 'Otomobil cam fitili veya kapısına sıfır hasarla açım.',
            fiyat: 1100.0,
            tahminiSure: '20 dk',
            ikon: '🚗',
          ),
        ],
      ),
      NearbyUstaModel(
        ustaId: 'demo-cilingir-2',
        fullName: 'Oğuz Şahin',
        phone: '+90 544 222 33 44',
        kategori: 'cilingir',
        puan: 4.8,
        tamamlananIsSayisi: 112,
        latitude: lat - 0.0052,
        longitude: lng - 0.0041,
        mesafeMetre: 1400,
        ustaHakedis: 650.0,
        komisyonOrani: 0.15,
        komisyonTutari: 97.5,
        toplamTutar: 747.5,
        servisUcreti: 150.0,
        deneyimYili: 10,
        uzmanlikBasligi: 'Acil Çilingir & Kapı Mekanizma Ustası',
        guvenceler: const [
          'Hızlı Varış (~12 dk)',
          'Sabit Fiyat Güvencesi',
          'Faturalı Hizmet',
        ],
        ilanlar: const [
          UstaHizmetIlan(
            id: 'c2-1',
            baslik: 'Acil Kapı Açma Hizmeti',
            aciklama: 'Çekili kapılar için kilidi bozmadan hızlı açım.',
            fiyat: 650.0,
            tahminiSure: '15 dk',
            ikon: '🔑',
            isDefault: true,
          ),
        ],
      ),
      NearbyUstaModel(
        ustaId: 'demo-cilingir-3',
        fullName: 'İsmail Koç',
        phone: '+90 555 333 44 55',
        kategori: 'cilingir',
        puan: 5.0,
        tamamlananIsSayisi: 228,
        latitude: lat + 0.0068,
        longitude: lng - 0.0058,
        mesafeMetre: 2400,
        ustaHakedis: 550.0,
        komisyonOrani: 0.15,
        komisyonTutari: 82.5,
        toplamTutar: 632.5,
        servisUcreti: 120.0,
        deneyimYili: 8,
        uzmanlikBasligi: 'Pratik Çilingir & Kilit Bakım Ustası',
        guvenceler: const [
          'Uygun Fiyat Garantisi',
          'İşçilik Garantisi',
          'Temiz İşçilik',
        ],
        ilanlar: const [
          UstaHizmetIlan(
            id: 'c3-1',
            baslik: 'Hızlı Kilit Açımı & Ayar',
            aciklama: 'Sürtünen kapı ayarı ve kilit açımı.',
            fiyat: 550.0,
            tahminiSure: '15 dk',
            ikon: '🔑',
            isDefault: true,
          ),
        ],
      ),
    ];
  }

  List<Map<String, dynamic>> _getDefaultCategories() {
    return [
      {
        'id': 'cat-1',
        'key': 'elektrik',
        'name': 'Elektrik & Aydınlatma',
        'type': 'Usta Hizmeti',
        'iconName': 'bolt',
        'colorValue': 0xFF0284C7,
        'count': 3,
        'description': 'Sigorta panosu, arıza tespiti, priz değişimi ve aydınlatma',
      },
      {
        'id': 'cat-2',
        'key': 'cilingir',
        'name': 'Çilingir & Kapı Açma',
        'type': 'Usta Hizmeti',
        'iconName': 'key',
        'colorValue': 0xFF0D9488,
        'count': 3,
        'description': 'Kilitli kapı açımı, barel değişimi, oto kapı açma',
      },
      {
        'id': 'cat-3',
        'key': 'tesisat',
        'name': 'Sıhhi Tesisat & Su Kaçağı',
        'type': 'Usta Hizmeti',
        'iconName': 'build',
        'colorValue': 0xFF2563EB,
        'count': 3,
        'description': 'Termal kamera ile su kaçağı tespiti, tıkanıklık açma, musluk montajı',
      },
      {
        'id': 'cat-4',
        'key': 'boya',
        'name': 'Boya, Alçı & Dekorasyon',
        'type': 'Usta Hizmeti',
        'iconName': 'paint',
        'colorValue': 0xFFEA580C,
        'count': 1,
        'description': 'Daire içi boya, tavan alçısı, rutubet onarımı',
      },
      {
        'id': 'cat-5',
        'key': 'klima',
        'name': 'Klima & Kombi Servisi',
        'type': 'Usta Hizmeti',
        'iconName': 'ac_unit',
        'colorValue': 0xFF7C3AED,
        'count': 2,
        'description': 'Klima montajı, gaz dolumu, kombi periyodik bakım',
      },
    ];
  }

  List<Map<String, dynamic>> _getDefaultActiveJobs() {
    return [
      {
        'id': 'ILN-4081',
        'title': 'Mutfak Lavabo Altı Su Kaçağı & Boru Değişimi',
        'category': 'Sıhhi Tesisat & Su Kaçağı',
        'district': 'Kadıköy / Caferağa',
        'customer_name': 'Zeynep Kaya',
        'customer_phone': '+90 532 999 11 22',
        'price': 850.0,
        'status': 'Bekliyor',
        'time': '10 dk önce',
      },
      {
        'id': 'ILN-4082',
        'title': 'Sigorta Panosu Attı, Dairede Elektrik Yok',
        'category': 'Elektrik & Aydınlatma',
        'district': 'Ataşehir / Batı',
        'customer_name': 'Mehmet Ali Öztürk',
        'customer_phone': '+90 544 888 22 33',
        'price': 950.0,
        'status': 'Usta Yolda',
        'time': '25 dk önce',
      },
      {
        'id': 'ILN-4083',
        'title': 'Çelik Kapı Kilidi Bozuldu, Anahtar Dönmüyor',
        'category': 'Çilingir & Kapı Açma',
        'district': 'Üsküdar / Altunizade',
        'customer_name': 'Burak Yılmazer',
        'customer_phone': '+90 555 777 33 44',
        'price': 750.0,
        'status': 'İşlemde',
        'time': '40 dk önce',
      },
    ];
  }

  List<Map<String, dynamic>> _getDefaultTedarikciler() {
    return [
      {
        'id': 'ted-1',
        'business_name': 'Kadıköy Elektrik Dünyası (Toptan & Perakende)',
        'kategori': 'Elektrik Malzemesi & Toptan',
        'telefon': '+90 216 414 50 60',
        'latitude': 40.9912,
        'longitude': 29.0285,
        'adres': 'Osmanağa Mah. Söğütlüçeşme Cad. No:44, Kadıköy',
        'indirim_orani': '%12 Usta İndirimi',
        'is_active': true,
      },
      {
        'id': 'ted-2',
        'business_name': 'Moda Teknik Sıhhi Tesisat & Boru Market',
        'kategori': 'Sıhhi Tesisat & Su Armatürleri',
        'telefon': '+90 216 330 12 12',
        'latitude': 40.9850,
        'longitude': 29.0240,
        'adres': 'Caferağa Mah. Moda Cad. No:88, Kadıköy',
        'indirim_orani': '%15 Usta İndirimi',
        'is_active': true,
      },
      {
        'id': 'ted-3',
        'business_name': 'Göztepe Yapı & Nalburiye Hırdavat',
        'kategori': 'Hırdavat & Nalburiye',
        'telefon': '+90 216 565 80 90',
        'latitude': 40.9740,
        'longitude': 29.0560,
        'adres': 'Göztepe Mah. Bağdat Cad. No:180, Kadıköy',
        'indirim_orani': '%10 Usta İndirimi',
        'is_active': true,
      },
    ];
  }

  List<Map<String, dynamic>> _getDefaultMapPins() {
    return [
      {
        'id': 'pin-1',
        'title': 'Kadıköy Acil Usta İstasyonu (Merkez)',
        'pin_type': 'Merkez Nokta (Mavi)',
        'colorValue': 0xFF0284C7,
        'iconName': 'location',
        'lat': 40.9905,
        'lng': 29.0270,
        'description': 'Kadıköy boğa heykeli çevresi hızlı intikal koordinasyon noktası',
        'is_active': true,
      },
      {
        'id': 'pin-2',
        'title': 'Moda Anlaşmalı Tesisat Malzeme Deposu (Sarı Pin)',
        'pin_type': 'Tedarikçi (Sarı)',
        'colorValue': 0xFFF59E0B,
        'iconName': 'store',
        'lat': 40.9850,
        'lng': 29.0240,
        'description': 'Tüm ustalara anında %15 indirimli boru ve batarya temini',
        'is_active': true,
      },
      {
        'id': 'pin-3',
        'title': 'Bağdat Caddesi Lojistik Destek Noktası',
        'pin_type': 'Lojistik (Yeşil)',
        'colorValue': 0xFF10B981,
        'iconName': 'local_shipping',
        'lat': 40.9740,
        'lng': 29.0560,
        'description': 'Motosikletli yedek parça ve malzeme ulaştırma noktası',
        'is_active': true,
      },
    ];
  }

  List<Map<String, dynamic>> _getDefaultMembers() {
    return [
      {
        'id': 'usr-1',
        'full_name': 'Ayşe Nilgün Yılmaz',
        'phone': '+90 532 211 44 55',
        'email': 'ayse.nilgun@gmail.com',
        'total_orders': 4,
        'total_spent': 3450.0,
        'status': 'Aktif',
        'created_at': '12 Ekim 2026',
      },
      {
        'id': 'usr-2',
        'full_name': 'Barış Demirkan',
        'phone': '+90 542 333 77 88',
        'email': 'baris.d@outlook.com',
        'total_orders': 1,
        'total_spent': 850.0,
        'status': 'Aktif',
        'created_at': '18 Ekim 2026',
      },
    ];
  }

  List<Map<String, dynamic>> _getDefaultPendingApplications() {
    return [
      {
        'id': 'app-1',
        'full_name': 'Ahmet Yılmaz',
        'phone': '+90 532 111 22 33',
        'kategori': 'Elektrik & Aydınlatma',
        'tecrube_yil': 9,
        'belgeler': 'Mesleki Yeterlilik (MYK-4), Ustalık Belgesi',
        'created_at': 'Bugün, 14:20',
        'onay_durumu': 'beklemede',
      },
      {
        'id': 'app-2',
        'full_name': 'Murat Kara',
        'phone': '+90 544 333 44 55',
        'kategori': 'Sıhhi Tesisat & Su Kaçağı',
        'tecrube_yil': 12,
        'belgeler': 'Termal Kamera Sertifikası, Tesisatçılar Odası Kaydı',
        'created_at': 'Bugün, 11:05',
        'onay_durumu': 'beklemede',
      },
      {
        'id': 'app-3',
        'full_name': 'Selim Demir',
        'phone': '+90 555 888 99 00',
        'kategori': 'Çilingir & Kapı Açma',
        'tecrube_yil': 6,
        'belgeler': 'Anahtarcılar ve Çilingirler Federasyon Kaydı',
        'created_at': 'Dün, 18:40',
        'onay_durumu': 'beklemede',
      },
    ];
  }
}
