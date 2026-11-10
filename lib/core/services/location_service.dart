import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ustaapp/core/services/supabase_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return LocationService(supabase);
});

class LocationService {
  final SupabaseClient _supabase;
  StreamSubscription<Position>? _positionStreamSub;
  Timer? _periodicTimer;
  Position? _lastUpdatedPosition;
  DateTime? _lastUpdateTime;

  LocationService(this._supabase);

  bool get isTracking => _positionStreamSub != null;

  /// Konum servisinin ve izinlerinin açık olup olmadığını kontrol eder, gerekirse izin ister.
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Konum servisleri cihazda kapalı.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Konum izni kullanıcı tarafından reddedildi.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Konum izni kalıcı olarak reddedildi.');
      return false;
    }

    return true;
  }

  /// Usta 'Online' moduna geçtiğinde konum dinleyicisini başlatır.
  /// 25 metre mesafe filtresi (distanceFilter: 25) ve her 30 saniyede bir periyodik kontrol uygular.
  Future<bool> startTracking(String ustaId) async {
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) {
      return false;
    }

    // Varsa eski dinleyiciyi temizle
    await stopTracking();

    try {
      // İlk anlık konumu al ve hemen veritabanına gönder
      final currentPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _syncLocationToSupabase(ustaId, currentPos);

      // Konum akış ayarları (Her 25 metrede bir tetiklensin)
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      );

      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) async {
          debugPrint('Yeni konum alındı (25m mesafe): ${position.latitude}, ${position.longitude}');
          await _syncLocationToSupabase(ustaId, position);
        },
        onError: (e) {
          debugPrint('Konum dinleme hatası: $e');
        },
      );

      // Her 30 saniyede bir ustanın hala aynı yerde olup olmadığını kontrol edip senkronize tut
      _periodicTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        if (_lastUpdateTime == null ||
            DateTime.now().difference(_lastUpdateTime!).inSeconds >= 30) {
          try {
            final latestPos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
            );
            await _syncLocationToSupabase(ustaId, latestPos);
          } catch (e) {
            debugPrint('Periyodik konum güncelleme hatası: $e');
          }
        }
      });

      return true;
    } catch (e) {
      debugPrint('startTracking başlatılamadı: $e');
      await stopTracking();
      return false;
    }
  }

  /// Supabase PostGIS RPC fonksiyonu (`usta_konum_guncelle`) ile koordinatları aktarır.
  Future<void> _syncLocationToSupabase(String ustaId, Position position) async {
    try {
      _lastUpdatedPosition = position;
      _lastUpdateTime = DateTime.now();

      // RPC fonksiyonu aracılığıyla atomik PostGIS geography güncellemesi
      await _supabase.rpc('usta_konum_guncelle', params: {
        'p_lat': position.latitude,
        'p_lng': position.longitude,
        'p_is_online': true,
      });

      debugPrint('Konum Supabase\'e başarıyla yazıldı: (${position.latitude}, ${position.longitude})');
    } catch (e) {
      debugPrint('Supabase konum güncelleme hatası: $e');
      // RPC çağrısı başarısız olursa doğrudan tablo güncellemesini dene
      try {
        await _supabase.from('ustalar').update({
          'konum': 'SRID=4326;POINT(${position.longitude} ${position.latitude})',
          'is_online': true,
        }).eq('id', ustaId);
      } catch (innerError) {
        debugPrint('Doğrudan konum tablosu güncelleme hatası: $innerError');
      }
    }
  }

  /// Usta 'Offline' moduna geçtiğinde dinleyiciyi tamamen kapatıp pili korur.
  Future<void> stopTracking() async {
    if (_positionStreamSub != null) {
      await _positionStreamSub!.cancel();
      _positionStreamSub = null;
    }
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _lastUpdatedPosition = null;
    _lastUpdateTime = null;
    debugPrint('Konum takibi durduruldu ve kaynaklar serbest bırakıldı (Pil koruma).');
  }

  Position? get lastPosition => _lastUpdatedPosition;
}
