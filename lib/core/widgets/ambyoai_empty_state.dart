import 'package:flutter/material.dart';

import '../theme/ambyoai_design_system.dart';
import 'ambyoai_widgets.dart';

/// Standard empty state: icon, title, subtitle, optional action button.
class AmbyoEmptyState extends StatelessWidget {
  const AmbyoEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButton,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButton;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AmbyoColors.royalBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: AmbyoColors.royalBlue.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AmbyoSpacing.sectionGap),
            Text(
              title,
              style: AmbyoTextStyles.subtitle(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AmbyoSpacing.tinyGap),
            Text(
              subtitle,
              style: AmbyoTextStyles.body(color: AmbyoColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (buttonLabel != null) ...[
              const SizedBox(height: AmbyoSpacing.sectionGap),
              AmbyoPrimaryButton(
                label: buttonLabel!,
                onTap: onButton,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
