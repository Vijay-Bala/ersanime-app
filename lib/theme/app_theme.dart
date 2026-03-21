import 'package:flutter/material.dart';

class AppTheme {
  // ── Colors (matching website CSS variables) ────────────────────────────────
  static const primary = Color(0xFFBF00FF);
  static const primaryLight = Color(0xFFD44DFF);
  static const primaryDark = Color(0xFF8C00CC);
  static const accentCyan = Color(0xFF00F5FF);
  static const accentPink = Color(0xFFFF007A);
  static const accentGreen = Color(0xFF00FF88);
  static const accentYellow = Color(0xFFFFE600);
  static const accentOrange = Color(0xFFFF6200);
  static const darkBg = Color(0xFF050508);
  static const darkSurface = Color(0xFF0A0A0F);
  static const darkCard = Color(0xFF0F0F18);
  static const darkCardElev = Color(0xFF16162A);
  static const darkBorder = Color(0xFF2A1F3D);
  static const textPrimary = Color(0xFFEEEEFF);
  static const textSecondary = Color(0xFF7A7A9A);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: accentCyan,
      surface: darkCard,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: darkBorder, width: 1),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: primary,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      hintStyle: const TextStyle(color: textSecondary),
      prefixIconColor: textSecondary,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w900),
      displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
      titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textSecondary),
      labelSmall: TextStyle(color: textSecondary),
    ),
  );
}

// Neon glow box decoration helper
BoxDecoration neonCard({
  Color glowColor = AppTheme.primary,
  double glowIntensity = 0.2,
}) {
  return BoxDecoration(
    color: AppTheme.darkCard,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: glowColor.withOpacity(0.3), width: 1),
    boxShadow: [
      BoxShadow(
        color: glowColor.withOpacity(glowIntensity),
        blurRadius: 20,
        spreadRadius: 0,
      ),
    ],
  );
}
