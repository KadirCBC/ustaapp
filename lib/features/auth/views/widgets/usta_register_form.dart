import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ustaapp/core/utils/phone_formatter.dart';
import 'package:ustaapp/features/auth/controllers/auth_controller.dart';

class UstaRegisterForm extends ConsumerStatefulWidget {
  final VoidCallback onSwitchToLogin;
  final VoidCallback onSwitchToCustomer;

  const UstaRegisterForm({
    super.key,
    required this.onSwitchToLogin,
    required this.onSwitchToCustomer,
  });

  @override
  ConsumerState<UstaRegisterForm> createState() => _UstaRegisterFormState();
}

class _UstaRegisterFormState extends ConsumerState<UstaRegisterForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _vergiNoController;
  late final TextEditingController _cityDistrictController;
  late final TextEditingController _addressController;
  late final TextEditingController _ibanController;
  late final TextEditingController _baseFeeController;

  String _selectedCategory = 'Elektrik & Aydınlatma';
  int _experienceYears = 5;
  bool _hasMyk = true;
  final double _workRadiusKm = 15.0;
  bool _contractAccepted = true;

  static const List<Map<String, String>> _categories = [
    {'name': 'Elektrik & Aydınlatma', 'icon': '⚡'},
    {'name': 'Sıhhi Tesisat & Su', 'icon': '🔧'},
    {'name': 'Çilingir & Kilit', 'icon': '🔑'},
    {'name': 'Boya & Badana', 'icon': '🎨'},
    {'name': 'Kombi & Isıtma', 'icon': '❄️'},
    {'name': 'Mobilya & Marangoz', 'icon': '🪑'},
  ];

  static const List<int> _experienceOptions = [2, 5, 8, 12, 15];

  @override
  void initState() {
    super.initState();
    final authState = ref.read(phoneAuthControllerProvider);
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController(text: authState.formattedPhone);
    _emailController = TextEditingController();
    _vergiNoController = TextEditingController();
    _cityDistrictController = TextEditingController(text: 'Sandıklı, Afyonkarahisar');
    _addressController = TextEditingController();
    _ibanController = TextEditingController(text: 'TR');
    _baseFeeController = TextEditingController(text: '750');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _vergiNoController.dispose();
    _cityDistrictController.dispose();
    _addressController.dispose();
    _ibanController.dispose();
    _baseFeeController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_contractAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen Usta Hizmet ve İş Ortaklığı Sözleşmesi\'ni onaylayınız.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final controller = ref.read(phoneAuthControllerProvider.notifier);
    final baseFee = double.tryParse(_baseFeeController.text.trim()) ?? 750.0;

    final ok = await controller.registerUsta(
      phone: _phoneController.text.trim(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      category: _selectedCategory,
      cityDistrict: _cityDistrictController.text.trim(),
      address: _addressController.text.trim(),
      vergiNo: _vergiNoController.text.trim().isNotEmpty ? _vergiNoController.text.trim() : null,
      experienceYears: _experienceYears,
      hasMykCertificate: _hasMyk,
      iban: _ibanController.text.trim().isNotEmpty ? _ibanController.text.trim() : null,
      baseServiceFee: baseFee,
      workRadiusKm: _workRadiusKm,
    );

    if (ok && mounted) {
      final hasTax = _vergiNoController.text.trim().isNotEmpty;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasTax
                ? 'Tebrikler! Vergi numaranızla Onaylı Usta olarak kaydınız oluşturuldu.'
                : 'Usta hesabınız başarıyla oluşturuldu! Hoş geldiniz.',
          ),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);
    final hasVergiNo = _vergiNoController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFED7AA)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withValues(alpha: 0.08),
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
                    color: const Color(0xFFFFEDD5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.handyman_rounded,
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
                        'Usta & Esnaf Kayıt Başvurusu',
                        style: TextStyle(
                          fontSize: 18.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Kendi ücretini belirle, acil çağrıları al ve kazan',
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
                          hint: 'Kadir',
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
                          hint: 'Usta',
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

            _buildFieldLabel('E-posta Adresi (İş Bildirimleri İçin)'),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: _buildInputDecoration(
                hint: 'kadir.usta@esnaf.com',
                prefixIcon: Icons.alternate_email_rounded,
              ),
            ),
            const SizedBox(height: 16),

            // 3. UZMANLIK & KATEGORİ SEÇİMİ
            _buildFieldLabel('Ana Uzmanlık / Hizmet Alanınız *'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['name'];
                return ChoiceChip(
                  label: Text('${cat['icon']} ${cat['name']}'),
                  selected: isSelected,
                  selectedColor: const Color(0xFFFFEDD5),
                  backgroundColor: const Color(0xFFF8FAFC),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFFC2410C) : const Color(0xFF475569),
                  ),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1,
                  ),
                  onSelected: (_) => setState(() => _selectedCategory = cat['name']!),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Deneyim Yılı
            _buildFieldLabel('Mesleki Deneyiminiz'),
            Row(
              children: _experienceOptions.map((yrs) {
                final isSelected = _experienceYears == yrs;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('$yrs+ Yıl'),
                    selected: isSelected,
                    selectedColor: const Color(0xFFFFEDD5),
                    backgroundColor: const Color(0xFFF1F5F9),
                    checkmarkColor: const Color(0xFFEA580C),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF475569),
                    ),
                    onSelected: (_) => setState(() => _experienceYears = yrs),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ===============================================================
            // 4. ⭐ VERGİ NO / TC KİMLİK NO (İSTEĞE BAĞLI - ÖZEL GÜVENCE)
            // ===============================================================
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Vergi No / TC Kimlik No (İsteğe Bağlı)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '⭐ Onaylı Usta',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vergi numaranızı veya TC no girdiğinizde profilinize yeşil "Onaylı & Kurumsal Usta" rozeti tanımlanır ve haritada müşterilere öncelikli gösterilirsiniz.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF78350F),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _vergiNoController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Vergi No / TC Kimlik No (10-11 Hane)',
                      prefixIcon: const Icon(Icons.account_balance_outlined, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFFCD34D)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFFDE68A)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 5. ADRES VE HİZMET BÖLGESİ
            _buildFieldLabel('Hizmet Verilen Şehir ve İlçe *'),
            TextFormField(
              controller: _cityDistrictController,
              textInputAction: TextInputAction.next,
              decoration: _buildInputDecoration(
                hint: 'Örn: Sandıklı, Afyonkarahisar veya Kadıköy, İstanbul',
                prefixIcon: Icons.location_on_outlined,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Hizmet bölgesini belirtiniz' : null,
            ),
            const SizedBox(height: 14),

            _buildFieldLabel('Atölye / Dükkan / Sabit Açık Adres *'),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              textInputAction: TextInputAction.next,
              decoration: _buildInputDecoration(
                hint: 'Dükkan veya ikametgah açık adresi',
                prefixIcon: Icons.storefront_outlined,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Açık adres belirtiniz' : null,
            ),
            const SizedBox(height: 14),

            // 6. FİNANSAL BİLGİLER (Taban Ücret + IBAN)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Taban Servis Ücreti (₺) *'),
                      TextFormField(
                        controller: _baseFeeController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: _buildInputDecoration(
                          hint: '750',
                          prefixIcon: Icons.payments_outlined,
                        ),
                        validator: (v) {
                          final fee = double.tryParse(v ?? '');
                          if (fee == null || fee <= 0) return 'Geçerli ücret girin';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Hakediş IBAN (TR...)'),
                      TextFormField(
                        controller: _ibanController,
                        textInputAction: TextInputAction.done,
                        decoration: _buildInputDecoration(
                          hint: 'TR00 0000 0000...',
                          prefixIcon: Icons.credit_card_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // MYK Sertifikası Checkbox
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _hasMyk,
                    activeColor: const Color(0xFFEA580C),
                    onChanged: (val) => setState(() => _hasMyk = val ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      'Mesleki Yeterlilik (MYK) Belgesi veya Ustalık Sertifikam Var',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Sözleşme Onayı Checkbox
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _contractAccepted,
                    activeColor: const Color(0xFFEA580C),
                    onChanged: (val) => setState(() => _contractAccepted = val ?? true),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'UstamBurada ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEA580C),
                      ),
                      children: [
                        TextSpan(
                          text: 'Usta Hizmet Sözleşmesi ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: 'şartlarını kabul ediyorum.',
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

            // 7. USTA BAŞVURUSUNU TAMAMLA BUTONU
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(hasVergiNo ? Icons.verified_rounded : Icons.check_circle_outline_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            hasVergiNo
                                ? 'Onaylı Usta Olarak Kaydol & Başla'
                                : 'Usta Olarak Kayıt Ol ve Paneli Aç',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Alt Yönlendirmeler
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Zaten kayıtlı mısınız? ',
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
                onPressed: widget.onSwitchToCustomer,
                icon: const Icon(Icons.person_search_rounded, size: 16, color: Color(0xFF1E3A8A)),
                label: const Text(
                  'Müşteriyim, Hizmet Almak İstiyorum →',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A8A),
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
