class CouponModel {
  final String id;
  final String code;
  final String title;
  final String discountType; // 'percentage' or 'fixed'
  final double discountAmount;
  final double minOrderAmount;
  final int maxUses;
  final int usedCount;
  final bool isActive;
  final DateTime? validUntil;

  const CouponModel({
    required this.id,
    required this.code,
    required this.title,
    this.discountType = 'fixed',
    required this.discountAmount,
    this.minOrderAmount = 0.0,
    this.maxUses = 100,
    this.usedCount = 0,
    this.isActive = true,
    this.validUntil,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code.toUpperCase().trim(),
    'title': title,
    'discount_type': discountType,
    'discount_amount': discountAmount,
    'min_order_amount': minOrderAmount,
    'max_uses': maxUses,
    'used_count': usedCount,
    'is_active': isActive,
    'valid_until': validUntil?.toIso8601String(),
  };

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id']?.toString() ?? 'coupon_${DateTime.now().millisecondsSinceEpoch}',
      code: (json['code'] ?? '').toString().toUpperCase().trim(),
      title: json['title']?.toString() ?? '',
      discountType: json['discount_type']?.toString() ?? 'fixed',
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 50.0,
      minOrderAmount: (json['min_order_amount'] as num?)?.toDouble() ?? 0.0,
      maxUses: (json['max_uses'] as num?)?.toInt() ?? 100,
      usedCount: (json['used_count'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] == true,
      validUntil: json['valid_until'] != null
          ? DateTime.tryParse(json['valid_until'].toString())
          : null,
    );
  }

  CouponModel copyWith({
    String? id,
    String? code,
    String? title,
    String? discountType,
    double? discountAmount,
    double? minOrderAmount,
    int? maxUses,
    int? usedCount,
    bool? isActive,
    DateTime? validUntil,
  }) {
    return CouponModel(
      id: id ?? this.id,
      code: code ?? this.code,
      title: title ?? this.title,
      discountType: discountType ?? this.discountType,
      discountAmount: discountAmount ?? this.discountAmount,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      maxUses: maxUses ?? this.maxUses,
      usedCount: usedCount ?? this.usedCount,
      isActive: isActive ?? this.isActive,
      validUntil: validUntil ?? this.validUntil,
    );
  }

  /// Verilen sipariş tutarı için indirim miktarını hesaplar
  double calculateDiscount(double orderTotal) {
    if (!isActive || orderTotal < minOrderAmount) return 0.0;
    if (discountType == 'percentage') {
      return (orderTotal * discountAmount / 100).clamp(0.0, orderTotal);
    } else {
      return discountAmount.clamp(0.0, orderTotal);
    }
  }
}
