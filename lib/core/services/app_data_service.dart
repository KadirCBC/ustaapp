import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ustaapp/core/services/location_lookup_service.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';
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

  static const int _kSyncPort = 8090;

  final StreamController<void> _changesStreamController = StreamController<void>.broadcast();
  Stream<void> get onDataChanged => _changesStreamController.stream;

  StreamSubscription? _wsSubscription;
  bool _isConnectingWs = false;
  Timer? _reconnectTimer;
  bool _isSyncInitialized = false;

  String get _syncHost {
    if (kIsWeb) {
      final host = Uri.base.host;
      return (host.isNotEmpty && host != '0.0.0.0') ? host : 'localhost';
    }
    // Android emülatöründe host makine 10.0.2.2'dir
    if (defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
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
    _connectWebSocket();
    _fetchServerData();
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

      final district = (job['district'] ?? job['address'] ?? job['konum'] ?? 'Sandıklı').toString();
      if (lat == 0.0 && lng == 0.0) {
        // Fallback 1: Adresi yerel konum sözlüğünden çözümle
        final match = LocationLookupService.resolveSync(district);
        if (match != null) {
          lat = match.lat;
          lng = match.lng;
        } else {
          // Fallback 2: İlanın sahibinin (usta) koordinatlarına bak
          final ustaId = (job['usta_id'] ?? '').toString();
          final ustaPhone = (job['customer_phone'] ?? job['usta_phone'] ?? '').toString();
          final usta = allKnownUstalar.cast<NearbyUstaModel?>().firstWhere(
            (u) => (u != null && (u.ustaId == ustaId || u.phone == ustaPhone)),
            orElse: () => null,
          );
          if (usta != null && usta.latitude != 0.0) {
            lat = usta.latitude;
            lng = usta.longitude;
          }
        }
      }
      if (lat == 0.0 && lng == 0.0) continue;

      final jobCat = (job['kategori'] ?? job['category'] ?? '').toString().trim().toLowerCase();
      final catMatch = (normalizedCat == 'tümü' || normalizedCat == 'all')
          ? true
          : (jobCat.contains(normalizedCat) || normalizedCat.contains(jobCat));
      if (!catMatch) continue;

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

        final dist = Geolocator.distanceBetween(customerLat, customerLng, lat, lng);

        result.add(NearbyUstaModel(
          ustaId: jobId, // Her ilan için benzersiz harita pin ID'si
          fullName: ustaName,
          phone: ustaPhone,
          kategori: _normalizeCatKey(jobCat),
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
        final catMatch = (normalizedCat == 'tümü' || normalizedCat == 'all')
            ? true
            : (ustaCat.contains(normalizedCat) || normalizedCat.contains(ustaCat));
        if (catMatch) {
          final dist = Geolocator.distanceBetween(customerLat, customerLng, u.latitude, u.longitude);
          result.add(u.copyWith(mesafeMetre: dist > 0 ? dist : u.mesafeMetre));
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

  /// Usta bir hizmet ilanını sildiğinde haritadan ve ilanlar masasından kaldırır
  Future<void> removeUstaHizmetListing(String hizmetId) async {
    final jobs = await getActiveJobs();
    jobs.removeWhere((j) => j['id'] == hizmetId || j['id'].toString().contains(hizmetId) || hizmetId.contains(j['id'].toString()));
    await saveActiveJobs(jobs);
  }

  /// Ustanın çalışma konumunu ve koordinatlarını günceller
  Future<void> updateUstaLocation({
    required String ustaId,
    required String address,
    required double lat,
    required double lng,
  }) async {
    final ustalar = await getUstalar();
    final idx = ustalar.indexWhere((u) => u.ustaId == ustaId);
    if (idx >= 0) {
      ustalar[idx] = ustalar[idx].copyWith(
        uzmanlikBasligi: address,
        latitude: lat,
        longitude: lng,
      );
      await saveUstalar(ustalar);
    }
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
      return true; // Harita üzerinde tüm tedarikçi dükkanları gösterilir
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
  // 6. FİNANSAL İŞLEMLER & HİZMET AKIŞI
  // ==========================================

  Future<List<Map<String, dynamic>>> getFinancialTransactions() async {
    if (_cachedFinancialTransactions != null) {
      return List.from(_cachedFinancialTransactions!);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kFinancialTransactionsKey);
      if (str != null) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          _cachedFinancialTransactions = List<Map<String, dynamic>>.from(decoded);
          return List.from(_cachedFinancialTransactions!);
        }
      }
    } catch (e) {
      debugPrint('Finansal verileri okuma hatası: $e');
    }

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
