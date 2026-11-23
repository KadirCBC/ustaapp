import 'dart:io';
import 'dart:convert';

void main() {
  final file = File('app_sync_data.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final cagrilar = json['cagrilar'] as List? ?? [];
  print('First 3 cagrilar:');
  for (var i = 0; i < (cagrilar.length > 3 ? 3 : cagrilar.length); i++) {
    final c = cagrilar[i];
    print('${c['id']} | durum: ${c['durum']} | usta_phone: ${c['usta_phone']} | created_at: ${c['created_at']}');
  }
}
