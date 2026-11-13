import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ustaapp/features/admin/views/admin_dashboard_screen.dart';

void main() {
  testWidgets('Admin Dashboard Finansal Raporlar ve Hizmet Akışı Sekmesi Render Testi', (tester) async {
    SharedPreferences.setMockInitialValues({
      'is_admin_session_active': true,
      'admin_logged_in': true,
    });

    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Finansal Raporlar sekmesine tıkla
    final financialTab = find.text('Finansal Raporlar & Hizmet Akışı');
    expect(financialTab, findsOneWidget);
    await tester.tap(financialTab);
    await tester.pump(const Duration(milliseconds: 500));

    // Başlık ve KPI kartlarının görüntülendiğini doğrula
    expect(find.text('Hizmet Akışı & Finansal Raporlar Masası'), findsOneWidget);
    expect(find.text('Toplam Brüt İşlem Hacmi (GMV)'), findsOneWidget);
    expect(find.text('Platform Komisyon Kazancımız (%15)'), findsOneWidget);
    expect(find.text('Ustalara Aktarılacak / Ödenen Hakediş'), findsOneWidget);
    expect(find.text('Hizmet Akış & Tahsilat Durumu'), findsOneWidget);

    // Canlı işlemler ve Kadir Usta dekontunun tabloda olduğunu doğrula
    expect(find.text('demo_pay_1794610203985'), findsOneWidget);
    expect(find.text('Kadir Usta'), findsWidgets);
    expect(find.text('4. Tamamlandı & Tahsil Edildi'), findsWidgets);
    expect(find.text('+262.50 ₺'), findsWidgets);
    expect(find.text('2012.50 ₺'), findsWidgets);

    // Dekonta tıkla ve Dijital Dekont modalının açıldığını doğrula
    final receiptInk = find.text('demo_pay_1794610203985');
    await tester.tap(receiptInk);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Resmi Hizmet Özeti & Dijital Dekont'), findsOneWidget);
    expect(find.text('Canlı Hizmet Akış Durumu'), findsOneWidget);
    expect(find.text('UstamBurada Güvence & Platform Komisyonu (%15):'), findsOneWidget);
    expect(find.text('+262.50 ₺'), findsWidgets);
    expect(find.text('Müşteri Kartından Çekilen Toplam Tutar:'), findsOneWidget);
  });
}
