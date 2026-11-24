import 'package:flutter/material.dart';

class BannerModel {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String? deepLink;
  final String badge;
  final String bgGradient;
  final bool isActive;
  final int clickCount;
  final int impressionCount;
  final DateTime createdAt;

  const BannerModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.deepLink,
    this.badge = 'KAMPANYA',
    this.bgGradient = 'orange',
    this.isActive = true,
    this.clickCount = 0,
    this.impressionCount = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'image_url': imageUrl,
    'deep_link': deepLink,
    'badge': badge,
    'bg_gradient': bgGradient,
    'is_active': isActive,
    'click_count': clickCount,
    'impression_count': impressionCount,
    'created_at': createdAt.toIso8601String(),
  };

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id']?.toString() ?? 'banner_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      deepLink: json['deep_link']?.toString(),
      badge: json['badge']?.toString() ?? 'KAMPANYA',
      bgGradient: json['bg_gradient']?.toString() ?? 'orange',
      isActive: json['is_active'] == true,
      clickCount: (json['click_count'] as num?)?.toInt() ?? 0,
      impressionCount: (json['impression_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  List<Color> get gradientColors {
    switch (bgGradient) {
      case 'blue':
        return [const Color(0xFF0284C7), const Color(0xFF38BDF8)];
      case 'emerald':
        return [const Color(0xFF059669), const Color(0xFF10B981)];
      case 'purple':
        return [const Color(0xFF7C3AED), const Color(0xFFA855F7)];
      case 'orange':
      default:
        return [const Color(0xFFEA580C), const Color(0xFFF97316)];
    }
  }

  BannerModel copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? imageUrl,
    String? deepLink,
    String? badge,
    String? bgGradient,
    bool? isActive,
    int? clickCount,
    int? impressionCount,
    DateTime? createdAt,
  }) {
    return BannerModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl ?? this.imageUrl,
      deepLink: deepLink ?? this.deepLink,
      badge: badge ?? this.badge,
      bgGradient: bgGradient ?? this.bgGradient,
      isActive: isActive ?? this.isActive,
      clickCount: clickCount ?? this.clickCount,
      impressionCount: impressionCount ?? this.impressionCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
