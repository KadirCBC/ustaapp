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

    // Modalı kapat
    await tester.tap(find.text('Kapat'));
    await tester.pump(const Duration(milliseconds: 500));

    // 1. Düzenle (Edit) Modalı Testi
    final editButton = find.byTooltip('İşlemi & Hizmet Akışını Düzenle').first;
    expect(editButton, findsOneWidget);
    await tester.tap(editButton);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('demo_pay_1794610203985 — İşlemi & Akışı Düzenle'), findsOneWidget);
    expect(find.text('Değişiklikleri Kaydet'), findsOneWidget);
    await tester.tap(find.text('İptal'));
    await tester.pump(const Duration(milliseconds: 500));

    // 2. Tekil Silme Onay Penceresi Testi
    final deleteButton = find.byTooltip('İşlem Kaydını Sil').first;
    expect(deleteButton, findsOneWidget);
    await tester.tap(deleteButton);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('İşlem Kaydını Sil'), findsOneWidget);
    expect(find.text('Vazgeç'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pump(const Duration(milliseconds: 500));

    // 3. Checkbox ile Toplu Seçim ve Toplu İşlem Çubuğu Testi
    // İlk satırın checkbox'ına tıkla
    final rowCheckbox = find.byType(Checkbox).at(1);
    await tester.tap(rowCheckbox);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('1 işlem seçildi'), findsOneWidget);
    expect(find.text('Toplu Durum / Aşama Değiştir'), findsOneWidget);
    expect(find.text('Toplu Hakediş Onayla'), findsOneWidget);
    expect(find.text('Seçilenleri Sil (1)'), findsOneWidget);
    expect(find.text('Seçimi Kaldır'), findsOneWidget);

    // Seçimi kaldır
    await tester.tap(find.text('Seçimi Kaldır'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('1 işlem seçildi'), findsNothing);

    // 4. Tüm Kayıtları Temizle ve Kalıcı Silinme Doğrulaması
    final clearAllButton = find.text('Tüm Kayıtları Temizle');
    expect(clearAllButton, findsOneWidget);
    await tester.tap(clearAllButton);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Tüm Finans Masasını Temizle'), findsOneWidget);
    await tester.tap(find.text('Evet, Tümünü Temizle'));
    await tester.pump(const Duration(milliseconds: 500));

    // Silindikten sonra boş durum (empty state) görünmeli ve kayıtlar geri gelmemeli
    expect(find.text('demo_pay_1794610203985'), findsNothing);
    expect(find.text('Finans masasında kayıtlı işlem bulunmuyor'), findsOneWidget);
    expect(find.text('Varsayılan Demo Verileri Geri Yükle'), findsOneWidget);

    // Tekrar rebuild edilse dahi kayıtlar boş kalmalı (geri yüklenmemeli)
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('demo_pay_1794610203985'), findsNothing);

    // Varsayılan Demo Verileri Geri Yükle butonuna tıklayınca veriler tekrar yüklenmeli
    await tester.tap(find.text('Varsayılan Demo Verileri Geri Yükle'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('demo_pay_1794610203985'), findsOneWidget);
  });

  testWidgets('Admin Paneli Açık / Koyu Tema Geçişi ve Kalıcı Tercih Testi', (tester) async {
    SharedPreferences.setMockInitialValues({
      'is_admin_session_active': true,
      'admin_logged_in': true,
      'admin_is_dark_mode': false,
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

    // Başlangıçta Açık ve Koyu butonları bulunmalı
    expect(find.text('Açık'), findsOneWidget);
    expect(find.text('Koyu'), findsOneWidget);

    // Koyu seçeneğine tıkla -> Koyu Moda geçiş
    await tester.tap(find.text('Koyu'));
    await tester.pump(const Duration(milliseconds: 500));

    // Koyu Mod kaydedildiğini doğrula
    final prefs1 = await SharedPreferences.getInstance();
    expect(prefs1.getBool('admin_is_dark_mode'), isTrue);

    // Tekrar Açık seçeneğine tıkla -> Açık Moda dönüş
    await tester.tap(find.text('Açık'));
    await tester.pump(const Duration(milliseconds: 500));

    // Tekrar Açık Mod kaydedildiğini doğrula
    final prefs2 = await SharedPreferences.getInstance();
    expect(prefs2.getBool('admin_is_dark_mode'), isFalse);
  });
}
