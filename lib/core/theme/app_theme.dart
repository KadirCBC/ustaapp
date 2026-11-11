import 'package:flutter/material.dart';
import 'package:ustaapp/features/auth/models/user_role.dart';

class AppTheme {
  // ===========================================================================
  // MÜŞTERİ TEMASI (Modern Lacivert / Temiz Beyaz)
  // ===========================================================================
  static const Color customerPrimary = Color(0xFF1E3A8A); // Deep Navy
  static const Color customerSecondary = Color(0xFF3B82F6); // Vibrant Blue
  static const Color customerAccent = Color(0xFF0284C7); // Sky Blue
  static const Color customerBackground = Color(0xFFF8FAFC); // Clean Slate-50
  static const Color customerSurface = Colors.white;
  static const Color customerTextDark = Color(0xFF0F172A); // Slate-900
  static const Color customerTextMuted = Color(0xFF64748B); // Slate-500

  static ThemeData get customerTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: customerPrimary,
      scaffoldBackgroundColor: customerBackground,
      colorScheme: const ColorScheme.light(
        primary: customerPrimary,
        secondary: customerSecondary,
        tertiary: customerAccent,
        surface: customerSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: customerTextDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: customerTextDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: customerTextDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: customerPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: customerPrimary,
          side: const BorderSide(color: customerPrimary, width: 1.5),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: customerPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        hintStyle: const TextStyle(color: customerTextMuted, fontSize: 15),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // ===========================================================================
  // USTA TEMASI (Endüstriyel Turuncu / Koyu Gri)
  // ===========================================================================
  static const Color ustaPrimary = Color(0xFFEA580C); // Safety Orange
  static const Color ustaSecondary = Color(0xFFF97316); // Bright Orange
  static const Color ustaDarkBackground = Color(0xFF18181B); // Zinc-900
  static const Color ustaSurface = Color(0xFF27272A); // Zinc-800
  static const Color ustaSurfaceBorder = Color(0xFF3F3F46); // Zinc-700
  static const Color ustaTextLight = Color(0xFFF4F4F5); // Zinc-100
  static const Color ustaTextMuted = Color(0xFFA1A1AA); // Zinc-400

  static ThemeData get ustaTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: ustaPrimary,
      scaffoldBackgroundColor: ustaDarkBackground,
      colorScheme: const ColorScheme.dark(
        primary: ustaPrimary,
        secondary: ustaSecondary,
        surface: ustaSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: ustaTextLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ustaDarkBackground,
        foregroundColor: ustaTextLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: ustaTextLight,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ustaPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ustaSecondary,
          side: const BorderSide(color: ustaSecondary, width: 1.5),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ustaSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ustaSurfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ustaSurfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ustaPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        hintStyle: const TextStyle(color: ustaTextMuted, fontSize: 15),
      ),
      cardTheme: CardThemeData(
        color: ustaSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: ustaSurfaceBorder, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // Dinamik Rol Seçimine Göre Tema Döndürücü
  static ThemeData themeForRole(UserRole? role) {
    if (role == UserRole.usta) {
      return ustaTheme;
    }
    return customerTheme;
  }
}
