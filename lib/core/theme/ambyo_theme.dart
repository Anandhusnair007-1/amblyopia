import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ambyoai_design_system.dart';

class AmbyoTheme {
  static const navyColor = AmbyoColors.darkBg;
  static const primaryColor = AmbyoColors.royalBlue;
  static const secondaryColor = AmbyoColors.electricBlue;
  static const accentColor = AmbyoColors.cyanAccent;
  static const successColor = AmbyoColors.tealMedical;
  static const warningColor = AmbyoColors.mildAmber;
  static const dangerColor = AmbyoColors.urgentRed;
  static const backgroundColor = AmbyoColors.backgroundColor;
  static const surfaceTint = Color(0xFFE9F1FB);
  static const infoColor = AmbyoColors.royalBlue;

  static const cardLight = AmbyoColors.cardLight;
  static const cardDark = AmbyoColors.darkCard;
  static const glassSurface = AmbyoColors.glassWhite;
  static const borderLight = AmbyoColors.borderLight;
  static const borderDark = AmbyoColors.darkBorder;

  static TextStyle dataTextStyle({
    Color? color,
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    final poppins = GoogleFonts.poppinsTextTheme(base);
    return poppins.copyWith(
      displayLarge: poppins.displayLarge
          ?.copyWith(fontSize: 32, fontWeight: FontWeight.w700),
      displayMedium: poppins.displayMedium
          ?.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
      titleLarge: poppins.titleLarge
          ?.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
      titleMedium: poppins.titleMedium
          ?.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      bodyLarge: poppins.bodyLarge
          ?.copyWith(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: poppins.bodyMedium
          ?.copyWith(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: poppins.bodySmall
          ?.copyWith(fontSize: 12, fontWeight: FontWeight.w400),
      labelSmall: poppins.labelSmall
          ?.copyWith(fontSize: 11, fontWeight: FontWeight.w400),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: cardLight,
        error: dangerColor,
      ),
      textTheme: _buildTextTheme(base.textTheme),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: cardLight,
        foregroundColor: navyColor,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          color: navyColor,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: borderLight),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dangerColor, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dangerColor, width: 1.5),
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: Color(0xFFB0BEC5),
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: Color(0xFF546E7A),
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          color: primaryColor,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: const Color(0xFF546E7A),
        suffixIconColor: const Color(0xFF546E7A),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: cardDark,
        error: dangerColor,
      ),
      textTheme: _buildTextTheme(base.textTheme.apply(bodyColor: Colors.white)),
      scaffoldBackgroundColor: navyColor,
      appBarTheme: AppBarTheme(
        backgroundColor: cardDark,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accentColor, width: 2),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
