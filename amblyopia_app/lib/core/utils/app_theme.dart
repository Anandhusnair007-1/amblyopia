// lib/core/utils/app_theme.dart
// High-contrast, large-font theme for rural nurse usability

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Brand Colours ──────────────────────────────────────────────────────────
  static const Color primary    = Color(0xFF1565C0); // deep blue
  static const Color onPrimary  = Colors.white;
  static const Color secondary  = Color(0xFF2E7D32); // forest green
  static const Color accent     = Color(0xFFF57C00); // amber
  static const Color error      = Color(0xFFC62828);
  static const Color surface    = Color(0xFFF5F7FA);
  static const Color cardBg     = Colors.white;

  // ── Test Colours ───────────────────────────────────────────────────────────
  static const Color gazeActive  = Color(0xFF1565C0);
  static const Color gazeCapture = Color(0xFF2E7D32);
  static const Color redStimulus = Color(0xFFD32F2F);
  static const Color greenStimulus = Color(0xFF388E3C);

  // ── Typography sizes (large for low-literacy users) ───────────────────────
  static const double fontTitle    = 28.0;
  static const double fontHeading  = 22.0;
  static const double fontBody     = 18.0;
  static const double fontCaption  = 15.0;
  static const double fontButton   = 20.0;

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: 'Nunito',
    colorScheme: const ColorScheme(
      brightness:       Brightness.light,
      primary:          primary,
      onPrimary:        onPrimary,
      secondary:        secondary,
      onSecondary:      Colors.white,
      error:            error,
      onError:          Colors.white,
      surface:          surface,
      onSurface:        Color(0xFF1A1A2E),
    ),
    scaffoldBackgroundColor: surface,

    // ── AppBar ──────────────────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor:   primary,
      foregroundColor:   Colors.white,
      elevation:         0,
      centerTitle:       true,
      titleTextStyle: TextStyle(
        fontFamily: 'Nunito',
        fontSize:   fontHeading,
        fontWeight: FontWeight.w800,
        color:      Colors.white,
      ),
    ),

    // ── ElevatedButton ──────────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor:    primary,
        foregroundColor:    Colors.white,
        minimumSize:        const Size(double.infinity, 64),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize:   fontButton,
          fontWeight: FontWeight.w700,
        ),
        elevation: 4,
      ),
    ),

    // ── OutlinedButton ──────────────────────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        minimumSize:     const Size(double.infinity, 64),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        side: const BorderSide(color: primary, width: 2),
        textStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize:   fontButton,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // ── InputDecoration ─────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled:      true,
      fillColor:   Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: Color(0xFFB0BEC5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: primary, width: 2),
      ),
      labelStyle: const TextStyle(fontSize: fontBody),
      hintStyle:  const TextStyle(fontSize: fontBody, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    ),

    // ── Card ────────────────────────────────────────────────────────────────
    cardTheme: CardTheme(
      color:     cardBg,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: fontTitle, fontWeight: FontWeight.w800),
      titleLarge:   TextStyle(fontSize: fontHeading, fontWeight: FontWeight.w700),
      bodyLarge:    TextStyle(fontSize: fontBody, fontWeight: FontWeight.w400),
      bodyMedium:   TextStyle(fontSize: fontCaption),
      labelLarge:   TextStyle(fontSize: fontButton, fontWeight: FontWeight.w700),
    ),
  );
}
