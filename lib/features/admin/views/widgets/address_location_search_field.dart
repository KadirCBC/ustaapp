import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ustaapp/core/services/location_lookup_service.dart';
import 'package:ustaapp/core/theme/app_theme.dart';

/// Admin paneli ve formlarda Google Haritalar benzeri adres arama ve otomatik koordinat seçim bileşeni.
/// Kullanıcının enlem/boylam yazma zorunluluğunu ortadan kaldırır; adres yazdıkça anında konum önerir.
class AddressLocationSearchField extends StatefulWidget {
  final String? initialAddress;
  final double? initialLat;
  final double? initialLng;
  final String labelText;
  final String hintText;
  final void Function(String address, double lat, double lng) onLocationChanged;

  const AddressLocationSearchField({
    super.key,
    this.initialAddress,
    this.initialLat,
    this.initialLng,
    this.labelText = 'Adres / Hizmet Konumu',
    this.hintText = 'Adres, semt veya ilçe ara (Örn: Kadıköy Moda, Sandıklı Afyon, Beşiktaş...)',
    required this.onLocationChanged,
  });

  @override
  State<AddressLocationSearchField> createState() => _AddressLocationSearchFieldState();
}

class _AddressLocationSearchFieldState extends State<AddressLocationSearchField> {
  late final TextEditingController _addressController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;

  Timer? _debounceTimer;
  bool _isSearching = false;
  List<LocationSuggestion> _suggestions = [];
  bool _showSuggestions = false;
  bool _showManualCoordinates = false;

  double? _selectedLat;
  double? _selectedLng;
  String? _selectedAddressLabel;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.initialAddress ?? '');
    _selectedLat = widget.initialLat ?? 40.9905;
    _selectedLng = widget.initialLng ?? 29.0270;
    _selectedAddressLabel = widget.initialAddress;

    _latController = TextEditingController(text: _selectedLat?.toStringAsFixed(6) ?? '40.990500');
    _lngController = TextEditingController(text: _selectedLng?.toStringAsFixed(6) ?? '29.027000');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isSearching = false;
      });
      return;
    }

    // Kullanıcı yazarken dahi geçerli adres ve koordinatı üst forma bildir
    widget.onLocationChanged(query.trim(), _selectedLat ?? 40.9905, _selectedLng ?? 29.0270);

    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final results = await LocationLookupService.searchAddress(query);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _showSuggestions = results.isNotEmpty;
        _isSearching = false;
      });

      // İlk eşleşen konum varsa otomatik koordinat ata
      if (results.isNotEmpty && _selectedAddressLabel == null) {
        final top = results.first;
        _selectedLat = top.lat;
        _selectedLng = top.lng;
        _latController.text = top.lat.toStringAsFixed(6);
        _lngController.text = top.lng.toStringAsFixed(6);
        widget.onLocationChanged(query.trim(), top.lat, top.lng);
      }
    });
  }

  void _selectSuggestion(LocationSuggestion suggestion) {
    setState(() {
      _addressController.text = suggestion.shortLabel;
      _selectedAddressLabel = suggestion.label;
      _selectedLat = suggestion.lat;
      _selectedLng = suggestion.lng;
      _latController.text = suggestion.lat.toStringAsFixed(6);
      _lngController.text = suggestion.lng.toStringAsFixed(6);
      _showSuggestions = false;
      _suggestions = [];
    });

    widget.onLocationChanged(suggestion.shortLabel, suggestion.lat, suggestion.lng);
  }

  void _onManualCoordinateChanged() {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat != null && lng != null) {
      _selectedLat = lat;
      _selectedLng = lng;
      widget.onLocationChanged(_addressController.text.trim(), lat, lng);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Arama Girişi
        TextField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0284C7)),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.ustaPrimary),
                    ),
                  )
                else if (_addressController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _addressController.clear();
                      setState(() {
                        _suggestions = [];
                        _showSuggestions = false;
                      });
                    },
                  ),
              ],
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onChanged: _onQueryChanged,
        ),

        // 2. Canlı Google Maps Tarzı Adres Önerileri Listesi
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final item = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.place_rounded, color: Color(0xFF0284C7), size: 18),
                  ),
                  title: Text(
                    item.shortLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  subtitle: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  trailing: Text(
                    '${item.lat.toStringAsFixed(3)}, ${item.lng.toStringAsFixed(3)}',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                  ),
                  onTap: () => _selectSuggestion(item),
                );
              },
            ),
          ),

        // 3. Seçili Konum Durum Kartı (Harita Pin Göstergesi)
        if (_selectedLat != null && _selectedLng != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              border: Border.all(color: const Color(0xFFBBF7D0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '📍 Konum Doğrulandı: ${_selectedAddressLabel ?? _addressController.text} (${_selectedLat!.toStringAsFixed(4)}, ${_selectedLng!.toStringAsFixed(4)})',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _showManualCoordinates = !_showManualCoordinates),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: Text(
                    _showManualCoordinates ? 'Gizle' : 'Koordinat',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7)),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 4. İsteğe Bağlı Manuel Koordinat İnce Ayar Alanı
        if (_showManualCoordinates) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latController,
                  decoration: const InputDecoration(
                    labelText: 'Enlem (Lat)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _onManualCoordinateChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _lngController,
                  decoration: const InputDecoration(
                    labelText: 'Boylam (Lng)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _onManualCoordinateChanged(),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
