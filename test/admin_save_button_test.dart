import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ustaapp/features/admin/views/admin_dashboard_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'is_admin_session_active': true,
      'app_shared_active_ustalar': '[]',
      'app_shared_jobs': '[]',
    });
  });

  testWidgets('Test Add Usta dialog save button', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Find and switch to Usta Üye Listesi tab
    final ustaTab = find.text('Usta Üye Listesi');
    expect(ustaTab, findsOneWidget);
    await tester.tap(ustaTab);
    await tester.pumpAndSettle();

    // Click "İlk Ustayı Ekle" or "Yeni Usta Ekle"
    final addBtn = find.text('İlk Ustayı Ekle');
    final newBtn = find.text('Yeni Usta Ekle');
    if (addBtn.evaluate().isNotEmpty) {
      await tester.tap(addBtn);
    } else {
      await tester.tap(newBtn);
    }
    await tester.pumpAndSettle();

    // Verify dialog is open
    expect(find.text('Yeni Usta Ekle'), findsWidgets);

    // Enter name "Kadir Usta"
    final nameField = find.widgetWithText(TextField, 'Usta Adı Soyadı');
    expect(nameField, findsOneWidget);
    await tester.enterText(nameField, 'Kadir Usta');

    // Click "Ustayı Kaydet"
    final saveBtn = find.text('Ustayı Kaydet');
    expect(saveBtn, findsOneWidget);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // If save succeeded and dialog closed, 'Ustayı Kaydet' should not be found
    expect(find.text('Ustayı Kaydet'), findsNothing);
    expect(find.text('Kadir Usta'), findsOneWidget);
  });
}
