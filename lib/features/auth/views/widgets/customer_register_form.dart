import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaapp/core/utils/phone_formatter.dart';
import 'package:ustaapp/features/auth/controllers/auth_controller.dart';

class CustomerRegisterForm extends ConsumerStatefulWidget {
  final VoidCallback onSwitchToLogin;
  final VoidCallback onSwitchToUsta;

  const CustomerRegisterForm({
    super.key,
    required this.onSwitchToLogin,
    required this.onSwitchToUsta,
  });

  @override
  ConsumerState<CustomerRegisterForm> createState() => _CustomerRegisterFormState();
}

class _CustomerRegisterFormState extends ConsumerState<CustomerRegisterForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _cityDistrictController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;

  String _selectedAddressTitle = 'Ev';
  bool _kvkkAccepted = true;

  static const List<String> _addressTitles = ['Ev', 'İş Yeri', 'Yazlık', 'Diğer'];

  @override
  void initState() {
    super.initState();
    final authState = ref.read(phoneAuthControllerProvider);
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController(text: authState.formattedPhone);
    _emailController = TextEditingController();
    _cityDistrictController = TextEditingController();
    _addressController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cityDistrictController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_kvkkAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen Kullanım Koşulları ve KVKK metnini onaylayınız.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final controller = ref.read(phoneAuthControllerProvider.notifier);
    final ok = await controller.registerCustomer(
      phone: _phoneController.text.trim(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      cityDistrict: _cityDistrictController.text.trim(),
      address: _addressController.text.trim(),
      addressTitle: _selectedAddressTitle,
      addressNotes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Müşteri hesabınız başarıyla oluşturuldu! Hoş geldiniz.'),
          backgroundColor: Color(0xFF15803D),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Üst Başlık & Rozet
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Color(0xFFEA580C),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Müşteri Hesabı Aç',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'En yakın ustayı anında çağır, güvenli öde',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 1. KİŞİSEL BİLGİLER (Ad + Soyad)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Adınız *'),
                      TextFormField(
                        controller: _firstNameController,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        decoration: _buildInputDecoration(
                          hint: 'Adınız',
                          prefixIcon: Icons.badge_outlined,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Ad gerekli' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Soyadınız *'),
                      TextFormField(
                        controller: _lastNameController,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        decoration: _buildInputDecoration(
                          hint: 'Soyadınız',
                          prefixIcon: Icons.badge_outlined,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Soyad gerekli' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. İLETİŞİM BİLGİLERİ (Telefon + E-posta)
            _buildFieldLabel('Cep Telefonu Numarası *'),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: _buildInputDecoration(
                hint: '5XX XXX XX XX',
                prefixIcon: Icons.phone_android_rounded,
                prefixText: '+90 ',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Telefon numarası gerekli';
                final clean = PhoneFormatter.clean(v);
                if (clean.length < 10) return 'Geçerli 10 haneli cep telefonu giriniz';
                return null;
              },
            ),
            const SizedBox(height: 14),

            _buildFieldLabel('E-posta Adresi (İsteğe Bağlı)'),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: _buildInputDecoration(
                hint: 'E-posta adresiniz',
                prefixIcon: Icons.alternate_email_rounded,
              ),
            ),
            const SizedBox(height: 14),

            // 3. ADRES BİLGİLERİ (Şehir/İlçe + Adres Başlığı + Açık Adres)
            _buildFieldLabel('Şehir ve İlçe *'),
            TextFormField(
              controller: _cityDistrictController,
              textInputAction: TextInputAction.next,
              decoration: _buildInputDecoration(
                hint: 'Şehir ve İlçe (Örn: Kadıköy, İstanbul)',
                prefixIcon: Icons.location_city_rounded,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Lütfen şehir ve ilçe belirtiniz' : null,
            ),
            const SizedBox(height: 14),

            _buildFieldLabel('Adres Başlığı'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _addressTitles.map((title) {
                final isSelected = _selectedAddressTitle == title;
                return FilterChip(
                  label: Text(title),
                  selected: isSelected,
                  selectedColor: const Color(0xFFDBEAFE),
                  backgroundColor: const Color(0xFFF1F5F9),
                  checkmarkColor: const Color(0xFFEA580C),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF475569),
                  ),
                  onSelected: (_) => setState(() => _selectedAddressTitle = title),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            _buildFieldLabel('Açık Adres (Ev/Hizmet Konumu) *'),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              textInputAction: TextInputAction.next,
              decoration: _buildInputDecoration(
                hint: 'Mahalle, Cadde, Sokak, Bina No, Daire No',
                prefixIcon: Icons.home_outlined,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Açık adres belirtiniz' : null,
            ),
            const SizedBox(height: 12),

            _buildFieldLabel('Adres Tarifi / Not (İsteğe Bağlı)'),
            TextFormField(
              controller: _notesController,
              textInputAction: TextInputAction.done,
              decoration: _buildInputDecoration(
                hint: 'Örn: Zili çalışmıyor, gelince lütfen arayınız',
                prefixIcon: Icons.notes_rounded,
              ),
            ),
            const SizedBox(height: 16),

            // 4. GÜVENCE ROZETLERİ
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: Color(0xFF15803D), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Müşteri Güvencesi & Provizyon Koruması',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF166534),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'İş bitmeden ve siz fotoğraflı kanıtı onaylamadan ustanıza ödeme aktarılmaz.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF15803D),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // KVKK Onayı
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _kvkkAccepted,
                    activeColor: const Color(0xFFEA580C),
                    onChanged: (val) => setState(() => _kvkkAccepted = val ?? true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Kullanım Koşulları ',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEA580C),
                      ),
                      children: const [
                        TextSpan(
                          text: 've ',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        TextSpan(
                          text: 'KVKK Aydınlatma Metni',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: '\'ni okudum, onaylıyorum.',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Hata mesajı varsa göster
            if (state.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(fontSize: 12.5, color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 5. KAYIT OL BUTONU
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: state.isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                child: state.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 20),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Müşteri Hesabı Oluştur',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Alt yönlendirmeler (Giriş Yap & Usta Kaydı)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Zaten bir hesabınız var mı? ',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                InkWell(
                  onTap: widget.onSwitchToLogin,
                  child: const Text(
                    'Giriş Yap',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: widget.onSwitchToUsta,
                icon: const Icon(Icons.handyman_rounded, size: 16, color: Color(0xFFEA580C)),
                label: const Text(
                  'Ustayım, Hizmet Vermek İstiyorum →',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEA580C),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData prefixIcon,
    String? prefixText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: Color(0xFF94A3B8),
      ),
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0F172A),
      ),
      prefixIcon: Icon(prefixIcon, size: 19, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }
}
