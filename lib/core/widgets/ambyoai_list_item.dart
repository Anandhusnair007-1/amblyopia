import 'package:flutter/material.dart';

import '../theme/ambyoai_design_system.dart';
import 'ambyoai_widgets.dart';

/// Standard list row: leading (avatar/icon), title, subtitle, caption, trailing, optional left border.
class AmbyoListItem extends StatelessWidget {
  const AmbyoListItem({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.caption,
    this.trailing,
    this.borderLeftColor,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final String? caption;
  final Widget? trailing;
  final Color? borderLeftColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AmbyoCard(
      borderLeftColor: borderLeftColor,
      onTap: onTap,
      padding: const EdgeInsets.all(AmbyoSpacing.cardPadding),
      child: Row(
        children: [
          leading,
          const SizedBox(width: AmbyoSpacing.inlineGap + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AmbyoTextStyles.body(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AmbyoSpacing.tinyGap),
                  Text(
                    subtitle!,
                    style: AmbyoTextStyles.caption(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (caption != null) ...[
                  const SizedBox(height: AmbyoSpacing.tinyGap),
                  Text(
                    caption!,
                    style: AmbyoTextStyles.caption(color: AmbyoColors.textDisabled),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AmbyoSpacing.inlineGap),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Avatar circle with initials.
Widget ambyoAvatar({
  required String initials,
  Color? color,
  double size = AmbyoSpacing.avatarMd,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: (color ?? AmbyoColors.royalBlue).withValues(alpha: 0.1),
      shape: BoxShape.circle,
    ),
    child: Center(
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: size * 0.35,
          fontWeight: FontWeight.w600,
          color: color ?? AmbyoColors.royalBlue,
        ),
      ),
    ),
  );
}

/// Icon in rounded box.
Widget ambyoIconBox({
  required IconData icon,
  Color? color,
  double size = 44,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: (color ?? AmbyoColors.royalBlue).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(
      icon,
      size: size * 0.5,
      color: color ?? AmbyoColors.royalBlue,
    ),
  );
}
