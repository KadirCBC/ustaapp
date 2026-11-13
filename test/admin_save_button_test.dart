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
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      FlutterError.presentError(details);
    };

    await tester.binding.setSurfaceSize(const Size(1600, 1000));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );

    // Initial pump
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Find and switch to Usta Üye Listesi tab
    final ustaTab = find.text('Usta Üye Listesi');
    expect(ustaTab, findsOneWidget);
    await tester.tap(ustaTab);
    await tester.pump(const Duration(milliseconds: 300));

    // Click "İlk Ustayı Ekle" or "Yeni Usta Ekle"
    final addBtn = find.text('İlk Ustayı Ekle');
    final newBtn = find.text('Yeni Usta Ekle');
    if (addBtn.evaluate().isNotEmpty) {
      await tester.tap(addBtn);
    } else {
      await tester.tap(newBtn);
    }
    await tester.pump(const Duration(milliseconds: 300));

    // Verify dialog is open (Ustayı Kaydet button is visible)
    expect(find.text('Ustayı Kaydet'), findsOneWidget);

    // Enter name "Kadir Usta"
    final nameField = find.widgetWithText(TextField, 'Usta Adı Soyadı');
    expect(nameField, findsOneWidget);
    await tester.enterText(nameField, 'Kadir Usta');
    await tester.pump(const Duration(milliseconds: 100));

    // Click "Ustayı Kaydet"
    final saveBtn = find.text('Ustayı Kaydet');
    expect(saveBtn, findsOneWidget);
    await tester.tap(saveBtn);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));

    // If save succeeded and dialog closed:
    // 1. 'Ustayı Kaydet' button should be gone (dialog closed)
    expect(find.text('Ustayı Kaydet'), findsNothing);
    // 2. 'Kadir Usta' should now be in the list table!
    expect(find.text('Kadir Usta'), findsWidgets);
  });
}
