import 'package:flutter/material.dart';

class AppTheme {
  static const Color accentBlue = Color(0xFF12397A);
  static const Color accentBlueDark = Color(0xFF0A1F44);
  static const Color accentBlueLight = Color(0xFF1F4EB8);
  static const Color canvas = Color(0xFFF5F6FA);
  static const Color panel = Colors.white;
  static const Color muted = Color(0xFF475467);

  static ThemeData theme() {
    final base = ThemeData(
      colorScheme: ColorScheme.light(
        primary: accentBlue,
        secondary: accentBlueLight,
        surface: panel,
      ),
      useMaterial3: true,
    );

    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      textTheme: base.textTheme.apply(
        bodyColor: accentBlueDark,
        displayColor: accentBlueDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: panel,
        foregroundColor: accentBlueDark,
        elevation: 0,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: accentBlueDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.hardEdge,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlueLight,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentBlue,
          side: BorderSide(color: accentBlue.withOpacity(0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: accentBlue.withOpacity(0.08),
        selectedColor: accentBlue,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: accentBlueLight, width: 2),
        ),
      ),
    );
  }
}
