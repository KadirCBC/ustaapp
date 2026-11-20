class AppNotificationModel {
  final String id;
  final String title;
  final String message;
  final String type; // 'arrived', 'update', 'feature', 'warning', 'pricing', 'general'
  final String target; // 'all', 'ustalar', 'musteriler', 'user'
  final String? targetPhone;
  final DateTime createdAt;
  final bool isRead;
  final bool isUrgent;
  final Map<String, dynamic>? data;

  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.type = 'general',
    this.target = 'all',
    this.targetPhone,
    required this.createdAt,
    this.isRead = false,
    this.isUrgent = false,
    this.data,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: json['id'] as String? ?? 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'UstaGelio Bildirimi',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'general',
      target: json['target'] as String? ?? 'all',
      targetPhone: json['target_phone'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['is_read'] as bool? ?? false,
      isUrgent: json['is_urgent'] as bool? ?? false,
      data: json['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'target': target,
      'target_phone': targetPhone,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'is_urgent': isUrgent,
      if (data != null) 'data': data,
    };
  }

  AppNotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    String? target,
    String? targetPhone,
    DateTime? createdAt,
    bool? isRead,
    bool? isUrgent,
    Map<String, dynamic>? data,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      target: target ?? this.target,
      targetPhone: targetPhone ?? this.targetPhone,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      isUrgent: isUrgent ?? this.isUrgent,
      data: data ?? this.data,
    );
  }
}
