class DisputeModel {
  final String id;
  final String cagriId;
  final String customerName;
  final String customerPhone;
  final String ustaName;
  final String ustaPhone;
  final double amount;
  final String reason;
  final String status; // 'bekliyor', 'musteriye_iade', 'ustaya_odendi', 'reddedildi'
  final String? resolutionNote;
  final DateTime createdAt;
  final List<String> proofPhotos;

  const DisputeModel({
    required this.id,
    required this.cagriId,
    required this.customerName,
    required this.customerPhone,
    required this.ustaName,
    required this.ustaPhone,
    required this.amount,
    required this.reason,
    this.status = 'bekliyor',
    this.resolutionNote,
    required this.createdAt,
    this.proofPhotos = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'cagri_id': cagriId,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'usta_name': ustaName,
    'usta_phone': ustaPhone,
    'amount': amount,
    'reason': reason,
    'status': status,
    'resolution_note': resolutionNote,
    'created_at': createdAt.toIso8601String(),
    'proof_photos': proofPhotos,
  };

  factory DisputeModel.fromJson(Map<String, dynamic> json) {
    return DisputeModel(
      id: json['id']?.toString() ?? 'dispute_${DateTime.now().millisecondsSinceEpoch}',
      cagriId: json['cagri_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? 'Müşteri',
      customerPhone: json['customer_phone']?.toString() ?? '',
      ustaName: json['usta_name']?.toString() ?? 'Usta',
      ustaPhone: json['usta_phone']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'bekliyor',
      resolutionNote: json['resolution_note']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      proofPhotos: (json['proof_photos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  DisputeModel copyWith({
    String? id,
    String? cagriId,
    String? customerName,
    String? customerPhone,
    String? ustaName,
    String? ustaPhone,
    double? amount,
    String? reason,
    String? status,
    String? resolutionNote,
    DateTime? createdAt,
    List<String>? proofPhotos,
  }) {
    return DisputeModel(
      id: id ?? this.id,
      cagriId: cagriId ?? this.cagriId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      ustaName: ustaName ?? this.ustaName,
      ustaPhone: ustaPhone ?? this.ustaPhone,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      resolutionNote: resolutionNote ?? this.resolutionNote,
      createdAt: createdAt ?? this.createdAt,
      proofPhotos: proofPhotos ?? this.proofPhotos,
    );
  }
}
