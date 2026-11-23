import 'dart:io';
import 'dart:convert';

void main() {
  final file = File('app_sync_data.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final cagrilar = json['cagrilar'] as List? ?? [];
  final latest = cagrilar.first;
  print(jsonEncode(latest));
}
