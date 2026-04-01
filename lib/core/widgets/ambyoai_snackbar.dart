import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/ambyoai_design_system.dart';

enum SnackbarType { info, success, error, warning }

/// Enterprise snackbar: floating, rounded, Poppins 13, color/icon by type.
class AmbyoSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final (Color bg, IconData icon) = switch (type) {
      SnackbarType.success => (AmbyoColors.tealMedical, Icons.check_circle_outline),
      SnackbarType.error => (AmbyoColors.urgentRed, Icons.error_outline),
      SnackbarType.warning => (AmbyoColors.mildAmber, Icons.warning_amber_rounded),
      SnackbarType.info => (AmbyoColors.royalBlue, Icons.info_outline),
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AmbyoSpacing.cardRadius),
        ),
        duration: duration,
      ),
    );
  }
}
