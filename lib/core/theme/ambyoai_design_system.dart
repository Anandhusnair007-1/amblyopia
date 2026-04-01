import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AmbyoAI spacing constants. Use everywhere instead of hardcoded numbers.
class AmbyoSpacing {
  AmbyoSpacing._();

  static const double pagePadding = 16;
  static const double pageTop = 12;
  static const double pageBottom = 24;

  static const double cardPadding = 16;
  static const double cardRadius = 12;

  static const double itemGap = 12;
  static const double sectionGap = 24;
  static const double inlineGap = 8;
  static const double tinyGap = 4;

  static const double iconSm = 18;
  static const double iconMd = 24;
  static const double iconLg = 32;

  static const double avatarSm = 32;
  static const double avatarMd = 44;
  static const double avatarLg = 56;

  static const double btnHeight = 52;
  static const double btnHeightLg = 64;
  static const double btnHeightXl = 72;
}

/// Central color palette. Use instead of raw Colors or hex.
class AmbyoColors {
  AmbyoColors._();

  static const Color deepNavy = Color(0xFF060D1A);
  static const Color darkBg = Color(0xFF0A1628);
  static const Color darkCard = Color(0xFF0F1E33);
  static const Color darkCardHover = Color(0xFF162741);
  static const Color darkElevated = Color(0xFF1B2F4A);
  static const Color darkBorder = Color(0xFF223A5E);
  static const Color darkNav = Color(0xFF08111D);

  static const Color royalBlue = Color(0xFF1565C0);
  static const Color cyanAccent = Color(0xFF00B4D8);
  static const Color cyanDark = Color(0xFF0089A8);
  static const Color electricBlue = Color(0xFF3D8EFF);

  static const Color normalGreen = Color(0xFF00C080);
  static const Color mildAmber = Color(0xFFFFCC02);
  static const Color highOrange = Color(0xFFFF7A00);
  static const Color urgentRed = Color(0xFFFF2D55);
  static const Color unscreened = Color(0xFF4A6080);

  static const Color testGaze = Color(0xFF00D4FF);
  static const Color testReflex = Color(0xFFFFCC02);
  static const Color testRed = Color(0xFFFF2D55);
  static const Color testOrange = Color(0xFFFF7A00);
  static const Color testPurple = Color(0xFF8B5CF6);
  static const Color testGreen = Color(0xFF00F5A0);
  static const Color testBlue = Color(0xFF3D8EFF);

  static const Color glassWhite = Color(0x0DFFFFFF);
  static const Color glassBorder = Color(0x1AFFFFFF);

  static const Color navyColor = deepNavy;
  static const Color tealMedical = normalGreen;
  static const Color textPrimary = Color(0xFF0A1628);
  static const Color textSecondary = Color(0xFF52627A);
  static const Color textDisabled = Color(0xFF94A3B8);
  static const Color borderLight = Color(0xFFE3EAF2);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color backgroundColor = Color(0xFFF7F9FC);

  static Color riskColor(String level) {
    switch (level.toUpperCase()) {
      case 'URGENT':
      case 'HIGH':
        return urgentRed;
      case 'MILD':
      case 'MEDIUM':
        return mildAmber;
      case 'NORMAL':
      case 'LOW':
      default:
        return tealMedical;
    }
  }
}

/// Gradient presets. Use instead of inline LinearGradient definitions.
class AmbyoGradients {
  AmbyoGradients._();

  static const LinearGradient primaryBtn = LinearGradient(
    colors: [Color(0xFF1565C0), Color(0xFF00B4D8)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient heroCard = LinearGradient(
    colors: [Color(0xFF0D1F3C), Color(0xFF0A1628)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient cyanGlow = RadialGradient(
    colors: [Color(0x3300B4D8), Color(0x0000B4D8)],
    radius: 1.0,
  );

  static const RadialGradient blueGlow = RadialGradient(
    colors: [Color(0x331565C0), Color(0x001565C0)],
    radius: 1.0,
  );

  static const RadialGradient urgentGlow = RadialGradient(
    colors: [Color(0x33FF2D55), Color(0x00FF2D55)],
    radius: 1.0,
  );

  static const RadialGradient normalGlow = RadialGradient(
    colors: [Color(0x3300F5A0), Color(0x0000F5A0)],
    radius: 1.0,
  );

  static const LinearGradient navBar = LinearGradient(
    colors: [Color(0xFF080E1A), Color(0xFF0A1220)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient forRisk(String risk) {
    switch (risk.toUpperCase()) {
      case 'NORMAL':
        return const LinearGradient(
            colors: [Color(0xFF00F5A0), Color(0xFF00C080)]);
      case 'MILD':
        return const LinearGradient(
            colors: [Color(0xFFFFCC02), Color(0xFFFF9500)]);
      case 'HIGH':
        return const LinearGradient(
            colors: [Color(0xFFFF7A00), Color(0xFFFF3B00)]);
      case 'URGENT':
        return const LinearGradient(
            colors: [Color(0xFFFF2D55), Color(0xFFAA0030)]);
      default:
        return const LinearGradient(
            colors: [Color(0xFF4A6080), Color(0xFF2A3F5F)]);
    }
  }

  static const LinearGradient primary = primaryBtn;
  static const LinearGradient profileCard = heroCard;
  static const LinearGradient success = LinearGradient(
    colors: [Color(0xFF00F5A0), Color(0xFF00C080)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient urgent = LinearGradient(
    colors: [Color(0xFFFF2D55), Color(0xFFAA0030)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient cardShimmer = LinearGradient(
    colors: [Color(0xFF111827), Color(0xFF1F2B3E), Color(0xFF111827)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Shadow presets. Use instead of inline BoxShadow lists.
class AmbyoShadows {
  AmbyoShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 20,
      offset: Offset(0, 8),
      spreadRadius: -4,
    ),
  ];

  static List<BoxShadow> get buttonGlow => [
        BoxShadow(
          color: const Color(0xFF1565C0).withValues(alpha: 0.5),
          blurRadius: 24,
          offset: const Offset(0, 6),
          spreadRadius: -2,
        ),
        BoxShadow(
          color: const Color(0xFF00B4D8).withValues(alpha: 0.2),
          blurRadius: 48,
          offset: const Offset(0, 16),
          spreadRadius: -8,
        ),
      ];

  static List<BoxShadow> get cyanGlow => [
        BoxShadow(
          color: const Color(0xFF00B4D8).withValues(alpha: 0.4),
          blurRadius: 20,
          spreadRadius: -2,
        ),
      ];

  static List<BoxShadow> get urgentGlow => [
        BoxShadow(
          color: const Color(0xFFFF2D55).withValues(alpha: 0.4),
          blurRadius: 20,
          spreadRadius: -2,
        ),
      ];

  static List<BoxShadow> get normalGlow => [
        BoxShadow(
          color: const Color(0xFF00C080).withValues(alpha: 0.3),
          blurRadius: 16,
          spreadRadius: -2,
        ),
      ];

  static const List<BoxShadow> cardShadow = card;
  static List<BoxShadow> get primaryButtonShadow => buttonGlow;
  static List<BoxShadow> get urgentShadow => urgentGlow;
  static const List<BoxShadow> elevatedCard = card;
}

/// Central text styles. Use instead of raw TextStyle or theme copyWith.
class AmbyoTextStyles {
  AmbyoTextStyles._();

  static TextStyle subtitle({Color? color}) {
    return GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: color ?? AmbyoColors.textPrimary,
    );
  }

  static TextStyle body({Color? color, double? fontSize}) {
    return GoogleFonts.poppins(
      fontSize: fontSize ?? 14,
      fontWeight: FontWeight.w400,
      color: color ?? AmbyoColors.textPrimary,
    );
  }

  static TextStyle caption({Color? color}) {
    return GoogleFonts.poppins(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: color ?? AmbyoColors.textSecondary,
    );
  }

  static TextStyle data(
      {double size = 18,
      Color? color,
      FontWeight fontWeight = FontWeight.w600}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: fontWeight,
      color: color ?? AmbyoColors.textPrimary,
    );
  }
}
