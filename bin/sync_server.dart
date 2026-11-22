import 'dart:async';
import 'dart:convert';
import 'dart:io';

const int kSyncPort = 8090;
final File _dataFile = File('app_sync_data.json');
final Set<WebSocket> _activeSockets = {};
Map<String, dynamic> _data = {};

void main() async {
  // 1. Veri dosyasını yükle veya varsayılanlarla başlat
  await _loadDataFromFile();

  // 2. HTTP ve WebSocket sunucusunu 0.0.0.0 üzerinden başlat (Hem localhost hem de Android 10.0.2.2 erişebilir)
  final server = await HttpServer.bind(InternetAddress.anyIPv4, kSyncPort);
  stdout.writeln('[UstaGelio Sync Server] Dinleniyor: http://0.0.0.0:$kSyncPort');

  await for (final request in server) {
    _handleRequest(request);
  }
}

Future<void> _loadDataFromFile() async {
  if (await _dataFile.exists()) {
    try {
      final content = await _dataFile.readAsString();
      _data = jsonDecode(content) as Map<String, dynamic>;
      _data['financial_transactions'] ??= [];
      _data['cagrilar'] ??= [];
      _data['notifications'] ??= [];
      _data['commission_settings'] ??= {};
      stdout.writeln('[Sync Server] Mevcut veriler dosyadan yüklendi.');
      return;
    } catch (e) {
      stdout.writeln('[Sync Server] Dosya okuma hatası: $e');
    }
  }

  // Varsayılan boş veya başlangıç yapısı
  _data = {
    'ustalar': [],
    'jobs': [],
    'categories': [],
    'map_pins': [],
    'members': [],
    'pending_ustalar': [],
    'tedarikciler': [],
    'financial_transactions': [],
    'notifications': [],
    'initialized': true,
  };
  await _saveDataToFile();
}

Future<void> _saveDataToFile() async {
  try {
    await _dataFile.writeAsString(jsonEncode(_data));
  } catch (e) {
    stderr.writeln('[Sync Server] Dosya kaydetme hatası: $e');
  }
}

void _broadcast(String event, dynamic payload) {
  final message = jsonEncode({
    'event': event,
    'data': payload,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  });

  final deadSockets = <WebSocket>[];
  for (final socket in _activeSockets) {
    try {
      socket.add(message);
    } catch (_) {
      deadSockets.add(socket);
    }
  }
  _activeSockets.removeAll(deadSockets);
  stdout.writeln('[Sync Broadcast] Event: $event -> ${_activeSockets.length} istemciye iletildi.');
}

Future<void> _handleRequest(HttpRequest request) async {
  final response = request.response;

  // CORS Başlıkları
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  response.headers.set('Access-Control-Allow-Headers', 'Origin, Content-Type, Accept, Authorization');

  if (request.method == 'OPTIONS') {
    response.statusCode = HttpStatus.ok;
    await response.close();
    return;
  }

  final path = request.uri.path;

  // 1. WebSocket Yolu
  if (path == '/ws') {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      try {
        final socket = await WebSocketTransformer.upgrade(request);
        _activeSockets.add(socket);
        stdout.writeln('[Sync Server] Yeni istemci bağlandı (Toplam: ${_activeSockets.length})');

        // İlk bağlantıda mevcut veriyi gönder
        socket.add(jsonEncode({
          'event': 'initial_data',
          'data': _data,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }));

        socket.listen(
          (msg) {
            // İstemciden gelen komutlar (varsa)
          },
          onDone: () {
            _activeSockets.remove(socket);
            stdout.writeln('[Sync Server] İstemci ayrıldı (Kalan: ${_activeSockets.length})');
          },
          onError: (_) {
            _activeSockets.remove(socket);
          },
        );
        return;
      } catch (e) {
        response.statusCode = HttpStatus.internalServerError;
        await response.close();
        return;
      }
    }
  }

  // 2. REST API Yolları
  response.headers.contentType = ContentType.json;

  if (request.method == 'GET' || request.method == 'HEAD') {
    if (path == '/' || path == '/indir') {
      response.headers.contentType = ContentType.html;
      if (request.method == 'HEAD') {
        response.statusCode = HttpStatus.ok;
        await response.close();
        return;
      }
      response.write('''
<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>UstaGelio - APK İndir</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #0F172A; color: #FFF; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 20px; box-sizing: border-box; }
    .card { background: #1E293B; border-radius: 24px; padding: 32px 24px; max-width: 440px; width: 100%; text-align: center; border: 1px solid #334155; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.5); }
    .icon { font-size: 54px; margin-bottom: 12px; }
    h1 { font-size: 24px; margin: 0 0 8px; color: #F97316; font-weight: 800; }
    p { font-size: 15px; color: #94A3B8; margin: 0 0 24px; line-height: 1.5; }
    .btn { display: block; background: linear-gradient(135deg, #F97316, #EA580C); color: #FFF; text-decoration: none; font-weight: 700; font-size: 17px; padding: 18px 24px; border-radius: 16px; box-shadow: 0 10px 20px -3px rgba(234, 88, 12, 0.4); margin: 0 auto 16px; }
    .btn:hover { background: linear-gradient(135deg, #EA580C, #C2410C); }
    .badge { display: inline-block; background: rgba(56, 189, 248, 0.12); color: #38BDF8; padding: 8px 16px; border-radius: 999px; font-size: 13px; font-weight: 600; border: 1px solid rgba(56, 189, 248, 0.2); }
    .steps { text-align: left; background: #0F172A; border-radius: 16px; padding: 16px 20px; margin-top: 24px; font-size: 13px; color: #CBD5E1; line-height: 1.6; border: 1px solid #1E293B; }
    .steps ol { margin: 8px 0 0; padding-left: 20px; }
    .steps li { margin-bottom: 6px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon">🛠️</div>
    <h1>UstaGelio Canlı Test</h1>
    <p>Aynı Wi-Fi ağındaki tüm Android cihazlarda anlık konum ve senkronizasyon ile test edin.</p>
    <a href="/app.apk" class="btn">📲 UstaGelio APK İndir (~242 MB)</a>
    <span class="badge">🌐 Canlı Sunucu: 192.168.1.101:8090</span>
    <div class="steps">
      <strong>Hızlı Test Adımları:</strong>
      <ol>
        <li>APK'yı indirip telefonunuza kurun (Bilinmeyen kaynaklara izin verin).</li>
        <li>1 telefonda <b>Usta</b> olarak giriş yapın (Örn: 5524342069).</li>
        <li>Diğer telefonlarda <b>Müşteri</b> olarak giriş yapın.</li>
        <li>Hizmet çağrısı oluşturduğunuzda usta telefonuna anında bildirim düşer ve harita canlı güncellenir!</li>
      </ol>
    </div>
  </div>
</body>
</html>
''');
      await response.close();
      return;
    }

    if (path == '/app.apk' || path == '/download') {
      final candidates = [
        File('build/app/outputs/flutter-apk/app-debug.apk'),
        File('c:/Users/taner/Documents/GitHub/ustaapp/build/app/outputs/flutter-apk/app-debug.apk'),
        File(r'c:\Users\taner\Documents\GitHub\ustaapp\build\app\outputs\flutter-apk\app-debug.apk'),
      ];
      File? apkFile;
      for (final f in candidates) {
        if (await f.exists()) {
          apkFile = f;
          break;
        }
      }
      if (apkFile != null) {
        response.headers.contentType = ContentType('application', 'vnd.android.package-archive');
        response.headers.set('Content-Disposition', 'attachment; filename="UstaGelio-Test.apk"');
        final fileLength = await apkFile.length();
        response.headers.contentLength = fileLength;
        if (request.method == 'HEAD') {
          response.statusCode = HttpStatus.ok;
          await response.close();
          return;
        }
        await response.addStream(apkFile.openRead());
        await response.close();
        return;
      } else {
        response.statusCode = HttpStatus.notFound;
        response.headers.contentType = ContentType.text;
        response.write('APK henüz derlenmedi. Lütfen derleme işlemi tamamlanana kadar bekleyin.');
        await response.close();
        return;
      }
    }

    if (path == '/api/data') {
      response.write(jsonEncode(_data));
      await response.close();
      return;
    }
    if (path == '/api/financial_transactions') {
      response.write(jsonEncode(_data['financial_transactions'] ?? []));
      await response.close();
      return;
    }
    if (path == '/api/ustalar') {
      response.write(jsonEncode(_data['ustalar'] ?? []));
      await response.close();
      return;
    }
    if (path == '/api/tedarikciler') {
      response.write(jsonEncode(_data['tedarikciler'] ?? []));
      await response.close();
      return;
    }
    if (path == '/api/cagrilar') {
      response.write(jsonEncode(_data['cagrilar'] ?? []));
      await response.close();
      return;
    }
    if (path == '/api/notifications') {
      response.write(jsonEncode(_data['notifications'] ?? []));
      await response.close();
      return;
    }
    if (path == '/api/commission_settings') {
      response.write(jsonEncode(_data['commission_settings'] ?? {}));
      await response.close();
      return;
    }
  }

  if (request.method == 'POST') {
    try {
      final bodyStr = await utf8.decodeStream(request);
      final dynamic body = bodyStr.isNotEmpty ? jsonDecode(bodyStr) : null;

      if (path == '/api/ustalar') {
        _data['ustalar'] = body;
        _data['initialized'] = true;
        await _saveDataToFile();
        _broadcast('ustalar_updated', body);
        response.write(jsonEncode({'status': 'ok', 'count': (body as List).length}));
        await response.close();
        return;
      }

      if (path == '/api/jobs') {
        _data['jobs'] = body;
        _data['initialized'] = true;
        await _saveDataToFile();
        _broadcast('jobs_updated', body);
        response.write(jsonEncode({'status': 'ok', 'count': (body as List).length}));
        await response.close();
        return;
      }

      if (path == '/api/categories') {
        _data['categories'] = body;
        await _saveDataToFile();
        _broadcast('categories_updated', body);
        response.write(jsonEncode({'status': 'ok'}));
        await response.close();
        return;
      }

      if (path == '/api/map_pins') {
        _data['map_pins'] = body;
        await _saveDataToFile();
        _broadcast('map_pins_updated', body);
        response.write(jsonEncode({'status': 'ok'}));
        await response.close();
        return;
      }

      if (path == '/api/members') {
        _data['members'] = body;
        await _saveDataToFile();
        _broadcast('members_updated', body);
        response.write(jsonEncode({'status': 'ok'}));
        await response.close();
        return;
      }

      if (path == '/api/pending_ustalar') {
        _data['pending_ustalar'] = body;
        await _saveDataToFile();
        _broadcast('pending_ustalar_updated', body);
        response.write(jsonEncode({'status': 'ok'}));
        await response.close();
        return;
      }

      if (path == '/api/tedarikciler') {
        _data['tedarikciler'] = body;
        await _saveDataToFile();
        _broadcast('tedarikciler_updated', body);
        response.write(jsonEncode({'status': 'ok'}));
        await response.close();
        return;
      }

      if (path == '/api/commission_settings') {
        _data['commission_settings'] = body;
        await _saveDataToFile();
        _broadcast('commission_settings_updated', body);
        response.write(jsonEncode({'status': 'ok'}));
        await response.close();
        return;
      }

      if (path == '/api/financial_transactions') {
        _data['financial_transactions'] = body;
        await _saveDataToFile();
        _broadcast('financial_transactions_updated', body);
        response.write(jsonEncode({'status': 'ok', 'count': (body as List).length}));
        await response.close();
        return;
      }

      if (path == '/api/cagrilar') {
        _data['cagrilar'] = body;
        await _saveDataToFile();
        _broadcast('cagrilar_updated', body);
        response.write(jsonEncode({'status': 'ok', 'count': (body as List).length}));
        await response.close();
        return;
      }

      if (path == '/api/cagri') {
        _data['cagrilar'] ??= [];
        final list = List<Map<String, dynamic>>.from(_data['cagrilar'] as List);
        final cagriMap = Map<String, dynamic>.from(body as Map);
        final id = (cagriMap['id'] ?? '').toString();
        final idx = list.indexWhere((item) => (item['id'] ?? '').toString() == id);
        if (idx >= 0) {
          list[idx] = cagriMap;
        } else {
          list.insert(0, cagriMap);
        }
        _data['cagrilar'] = list;
        await _saveDataToFile();
        _broadcast('cagri_updated', cagriMap);
        _broadcast('cagrilar_updated', list);

        // Usta adrese vardığında özel bildirim event'i yayınla
        final isAdreste = (cagriMap['durum'] == 'adreste' || cagriMap['usta_arrived'] == true);
        if (isAdreste) {
          final arrivalPayload = {
            'cagri_id': id,
            'usta_name': cagriMap['usta_name'] ?? cagriMap['ustaName'] ?? 'Ustanız',
            'musteri_phone': cagriMap['musteri_phone'] ?? cagriMap['musteriPhone'] ?? '',
            'musteri_name': cagriMap['musteri_name'] ?? cagriMap['musteriName'] ?? '',
            'address': cagriMap['address'] ?? '',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };
          _broadcast('usta_arrived', arrivalPayload);
          stdout.writeln('[Sync Server] 🚨 Usta varış eventi yayınlandı: $arrivalPayload');
        }

        response.write(jsonEncode({'status': 'ok', 'cagri': cagriMap}));
        await response.close();
        return;
      }

      if (path == '/api/notifications') {
        _data['notifications'] ??= [];
        final notifList = List<Map<String, dynamic>>.from(_data['notifications'] as List);
        final notifMap = Map<String, dynamic>.from(body as Map);
        if (notifMap['id'] == null || notifMap['id'].toString().isEmpty) {
          notifMap['id'] = 'notif_${DateTime.now().millisecondsSinceEpoch}';
        }
        notifMap['created_at'] ??= DateTime.now().toIso8601String();
        notifList.insert(0, notifMap);
        _data['notifications'] = notifList;
        await _saveDataToFile();
        _broadcast('system_notification', notifMap);
        stdout.writeln('[Sync Server] 📢 Sistem bildirimi yayınlandı: ${notifMap['title']} -> Hedef: ${notifMap['target']}');
        response.write(jsonEncode({'status': 'ok', 'notification': notifMap}));
        await response.close();
        return;
      }

      if (path == '/api/notifications/clear') {
        _data['notifications'] = [];
        await _saveDataToFile();
        _broadcast('notifications_cleared', {});
        stdout.writeln('[Sync Server] 🗑️ Tüm bildirimler temizlendi.');
        response.write(jsonEncode({'status': 'ok', 'message': 'Notifications cleared'}));
        await response.close();
        return;
      }

      if (path == '/api/notifications/delete') {
        final id = (body is Map ? body['id'] : null)?.toString() ?? '';
        _data['notifications'] ??= [];
        final notifList = List<Map<String, dynamic>>.from(_data['notifications'] as List);
        notifList.removeWhere((item) => (item['id'] ?? '').toString() == id);
        _data['notifications'] = notifList;
        await _saveDataToFile();
        _broadcast('notifications_updated', notifList);
        stdout.writeln('[Sync Server] 🗑️ Bildirim silindi: $id');
        response.write(jsonEncode({'status': 'ok', 'message': 'Notification deleted', 'remaining': notifList.length}));
        await response.close();
        return;
      }

      if (path == '/api/clear_all') {
        _data['ustalar'] = [];
        _data['jobs'] = [];
        _data['members'] = [];
        _data['initialized'] = true;
        await _saveDataToFile();
        _broadcast('all_cleared', {});
        response.write(jsonEncode({'status': 'ok', 'message': 'All cleared'}));
        await response.close();
        return;
      }
    } catch (e) {
      response.statusCode = HttpStatus.badRequest;
      response.write(jsonEncode({'error': e.toString()}));
      await response.close();
      return;
    }
  }

  // Varsayılan 404
  response.statusCode = HttpStatus.notFound;
  response.write(jsonEncode({'error': 'Not found'}));
  await response.close();
}
