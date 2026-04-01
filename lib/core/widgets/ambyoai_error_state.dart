import 'package:flutter/material.dart';

import '../theme/ambyoai_design_system.dart';
import 'ambyoai_widgets.dart';

/// Standard error state: icon, title, message, optional retry/settings button.
class AmbyoErrorState extends StatelessWidget {
  const AmbyoErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.isPermissionError = false,
    this.dark = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool isPermissionError;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final titleColor = dark ? Colors.white : AmbyoColors.textPrimary;
    final messageColor = dark ? Colors.white70 : AmbyoColors.textSecondary;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isPermissionError ? Icons.lock_outline : Icons.error_outline,
          size: 48,
          color: AmbyoColors.urgentRed.withValues(alpha: 0.75),
        ),
        const SizedBox(height: 16),
        Text(
          isPermissionError ? 'Permission Required' : 'Something went wrong',
          style: AmbyoTextStyles.subtitle(color: titleColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AmbyoSpacing.inlineGap),
        Text(
          message,
          style: AmbyoTextStyles.body(color: messageColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (onRetry != null)
          AmbyoPrimaryButton(
            label: isPermissionError ? 'Open Settings' : 'Try Again',
            icon: isPermissionError ? Icons.settings_outlined : Icons.refresh,
            onTap: onRetry,
          ),
      ],
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: dark
            ? GlassCard(
                radius: 28,
                blurSigma: 20,
                glowColor: AmbyoColors.urgentRed,
                borderColor: Colors.white.withValues(alpha: 0.10),
                backgroundColor: const Color(0xCC101827),
                padding: const EdgeInsets.all(24),
                child: content,
              )
            : content,
      ),
    );
  }
}
