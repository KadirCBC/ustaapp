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
  stdout.writeln('[UstamBurada Sync Server] Dinleniyor: http://0.0.0.0:$kSyncPort');

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

  if (request.method == 'GET' && path == '/api/data') {
    response.write(jsonEncode(_data));
    await response.close();
    return;
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

      if (path == '/api/financial_transactions') {
        _data['financial_transactions'] = body;
        await _saveDataToFile();
        _broadcast('financial_transactions_updated', body);
        response.write(jsonEncode({'status': 'ok', 'count': (body as List).length}));
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
