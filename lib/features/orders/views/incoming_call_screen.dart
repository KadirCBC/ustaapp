import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ustaapp/core/services/app_data_service.dart';
import 'package:ustaapp/core/theme/app_theme.dart';
import 'package:ustaapp/features/orders/models/cagri_model.dart';
import 'package:ustaapp/features/orders/views/widgets/incoming_call_dialog.dart';

/// Ekran kilitli veya uygulama kapalıyken tam ekran açılan Usta Çağrı Ekranı
class IncomingCallScreen extends ConsumerStatefulWidget {
  final String cagriId;

  const IncomingCallScreen({super.key, required this.cagriId});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  CagriModel? _cagri;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCagri();
  }

  Future<void> _loadCagri() async {
    try {
      final allCalls = await AppDataService.instance.getCagrilar();
      final match = allCalls.where((c) => c.id == widget.cagriId).firstOrNull;

      if (match != null) {
        if (mounted) {
          setState(() {
            _cagri = match;
            _isLoading = false;
          });
        }
        return;
      }

      // Bulunamadıysa son çağrılardan veya bildirim geçmişinden bak
      final prefs = await SharedPreferences.getInstance();
      final notifsRaw = prefs.getString('ustam_saved_notifications');
      if (notifsRaw != null) {
        final list = jsonDecode(notifsRaw) as List;
        for (final item in list) {
          if (item is Map) {
            final data = item['data'];
            if (data is Map && data['cagri_id'] == widget.cagriId) {
              final syntheticCall = CagriModel(
                id: widget.cagriId,
                musteriId: 'musteri-direct',
                ustaId: 'me',
                musteriLat: 38.8507,
                musteriLng: 30.4689,
                adresTarifi: data['address']?.toString() ?? 'Acil Usta Hizmeti',
                durum: CagriDurumu.bekliyor,
                ustaHakedis: (data['price'] as num?)?.toDouble() ?? 750.0,
                komisyonTutari: ((data['price'] as num?)?.toDouble() ?? 750.0) * 0.15,
                toplamTutar: (data['price'] as num?)?.toDouble() ?? 862.5,
                createdAt: DateTime.now(),
                musteriFullName: data['customer_name']?.toString() ?? 'Müşteri',
                musteriPhone: '+90 532 999 88 77',
              );
              if (mounted) {
                setState(() {
                  _cagri = syntheticCall;
                  _isLoading = false;
                });
              }
              return;
            }
          }
        }
      }

      // Genel varsayılan çağrı modeli
      final fallbackCall = CagriModel(
        id: widget.cagriId,
        musteriId: 'musteri-direct',
        ustaId: 'me',
        musteriLat: 38.8507,
        musteriLng: 30.4689,
        adresTarifi: 'Acil Usta Hizmeti & Arıza Tespiti',
        durum: CagriDurumu.bekliyor,
        ustaHakedis: 750.0,
        komisyonTutari: 112.5,
        toplamTutar: 862.5,
        createdAt: DateTime.now(),
        musteriFullName: 'Müşteri',
        musteriPhone: '+90 532 999 88 77',
      );

      if (mounted) {
        setState(() {
          _cagri = fallbackCall;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.ustaDarkBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.ustaPrimary),
        ),
      );
    }

    if (_cagri == null) {
      return Scaffold(
        backgroundColor: AppTheme.ustaDarkBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.call_end, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Çağrı bulunamadı veya süresi doldu.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/usta/orders'),
                child: const Text('Siparişler Ekranına Dön'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.ustaDarkBackground,
      body: IncomingCallDialog(cagri: _cagri!),
    );
  }
}
