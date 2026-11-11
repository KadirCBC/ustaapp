import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ustaapp/features/map/models/nearby_usta_model.dart';
import 'package:ustaapp/features/map/views/widgets/category_filter_bar.dart';
import 'package:ustaapp/features/map/views/widgets/custom_marker.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';

void main() {
  group('CagriDurumu & CagriModel Tests', () {
    test('DB string conversions map bekliyor, kabul_edildi and iptal correctly', () {
      expect(CagriDurumu.fromDbValue('bekliyor'), CagriDurumu.bekliyor);
      expect(CagriDurumu.fromDbValue('kabul_edildi'), CagriDurumu.kabulEdildi);
      expect(CagriDurumu.fromDbValue('yolda'), CagriDurumu.yolda);
      expect(CagriDurumu.fromDbValue('tamamlandi'), CagriDurumu.tamamlandi);
      expect(CagriDurumu.fromDbValue('iptal'), CagriDurumu.iptal);

      expect(CagriDurumu.bekliyor.toDbValue(), 'bekliyor');
      expect(CagriDurumu.kabulEdildi.toDbValue(), 'kabul_edildi');
      expect(CagriDurumu.iptal.toDbValue(), 'iptal');
    });

    test('CagriModel.fromJson parses coordinates, earnings and address', () {
      final model = CagriModel.fromJson({
        'id': 'cagri-101',
        'musteri_id': 'musteri-1',
        'usta_id': 'usta-1',
        'musteri_lat': 41.0082,
        'musteri_lng': 28.9784,
        'adres_tarifi': 'Moda Cd. No:14 Kadıköy/İstanbul',
        'durum': 'bekliyor',
        'usta_hakedis': 750.0,
        'komisyon_tutari': 150.0,
        'toplam_tutar': 900.0,
        'musteri_full_name': 'Ahmet Yılmaz',
      });

      expect(model.id, 'cagri-101');
      expect(model.isPending, isTrue);
      expect(model.ustaHakedis, 750.0);
      expect(model.adresTarifi, 'Moda Cd. No:14 Kadıköy/İstanbul');
      expect(model.distanceInMetersFrom(41.0082, 28.9784), closeTo(0.0, 0.1));
      expect(model.formattedDistanceFrom(41.0082, 28.9784), '0 metre');
      expect(model.formattedDistanceFrom(41.0200, 28.9900), contains('km'));
    });

    test('DemoCallRepository handles accept and reject/timeout transitions', () {
      final call = CagriModel(
        id: 'demo-cagri-1',
        musteriId: 'musteri-demo',
        ustaId: 'usta-demo',
        musteriLat: 41.01,
        musteriLng: 28.98,
        adresTarifi: 'Bağdat Cd. No:42',
        durum: CagriDurumu.bekliyor,
        ustaHakedis: 850.0,
        createdAt: DateTime.now(),
      );

      DemoCallRepository.save(call);
      expect(DemoCallRepository.get('demo-cagri-1')?.durum, CagriDurumu.bekliyor);

      DemoCallRepository.updateStatus('demo-cagri-1', CagriDurumu.kabulEdildi);
      expect(DemoCallRepository.get('demo-cagri-1')?.isAccepted, isTrue);

      DemoCallRepository.updateStatus('demo-cagri-1', CagriDurumu.iptal);
      expect(DemoCallRepository.get('demo-cagri-1')?.isCancelled, isTrue);
    });

    test('DemoWorkflowState tracks arrival, completion request, receipt and rating', () {
      const cagriId = 'demo-workflow-1';
      DemoCallRepository.saveWorkflow(
        cagriId,
        DemoWorkflowState(
          ustaArrived: true,
          arrivedAt: DateTime(2026, 11, 11, 21, 0),
          completionRequested: true,
        ),
      );

      final arrivedWf = DemoCallRepository.getWorkflow(cagriId);
      expect(arrivedWf.ustaArrived, isTrue);
      expect(arrivedWf.completionRequested, isTrue);

      DemoCallRepository.saveWorkflow(
        cagriId,
        arrivedWf.copyWith(
          completionRequested: false,
          receiptId: 'PAY-123456',
          ustaAverageRating: 4.92,
        ),
      );

      final doneWf = DemoCallRepository.getWorkflow(cagriId);
      expect(doneWf.completionRequested, isFalse);
      expect(doneWf.receiptId, 'PAY-123456');
      expect(doneWf.ustaAverageRating, 4.92);
    });
  });

  group('Modern Customer Map Widgets', () {
    testWidgets('CustomMarker renders rating, short name and formatted price',
        (tester) async {
      final usta = NearbyUstaModel(
        ustaId: 'usta-1',
        fullName: 'Ahmet Yılmaz',
        phone: '+905321112233',
        kategori: 'elektrik',
        puan: 4.9,
        tamamlananIsSayisi: 142,
        latitude: 41.01,
        longitude: 28.98,
        mesafeMetre: 2400,
        ustaHakedis: 800,
        komisyonOrani: 0.15,
        komisyonTutari: 120,
        toplamTutar: 920,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CustomMarker(
                usta: usta,
                isSelected: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('4.9'), findsOneWidget);
      expect(find.text('Ahmet Y.'), findsOneWidget);
      expect(find.text('920 ₺'), findsOneWidget);
    });

    testWidgets('CategoryFilterBar triggers category selection callback',
        (tester) async {
      String selected = 'elektrik';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryFilterBar(
              selectedCategory: selected,
              onCategorySelected: (cat) => selected = cat,
            ),
          ),
        ),
      );

      expect(find.text('Elektrik'), findsOneWidget);
      expect(find.text('Çilingir'), findsOneWidget);
      expect(find.text('Tesisat'), findsOneWidget);

      await tester.tap(find.text('Tesisat'));
      expect(selected, 'tesisat');
    });
  });
}
