import 'package:flutter/material.dart';

import '../theme/ambyo_theme.dart';
import '../theme/ambyoai_design_system.dart';

enum EnterpriseSurfaceStyle {
  gradient,
  plain,
}

enum EnterpriseAppBarStyle {
  light,
  brand,
}

class EnterpriseScaffold extends StatelessWidget {
  const EnterpriseScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.appBarStyle = EnterpriseAppBarStyle.light,
    this.surfaceStyle = EnterpriseSurfaceStyle.gradient,
    this.backgroundColor,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.padding = const EdgeInsets.all(20),
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final EnterpriseAppBarStyle appBarStyle;
  final EnterpriseSurfaceStyle surfaceStyle;

  /// When set, overrides scaffold background (e.g. doctor portal #F5F7FA).
  final Color? backgroundColor;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final appBar = title == null
        ? null
        : AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: appBarStyle == EnterpriseAppBarStyle.light
                              ? Colors.white70
                              : Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
              ],
            ),
            actions: actions,
            backgroundColor: appBarStyle == EnterpriseAppBarStyle.light
                ? AmbyoColors.darkCard
                : AmbyoTheme.primaryColor,
            foregroundColor: appBarStyle == EnterpriseAppBarStyle.light
                ? Colors.white
                : Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            bottom: appBarStyle == EnterpriseAppBarStyle.light
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Container(
                      height: 1,
                      color: AmbyoColors.darkBorder,
                    ),
                  )
                : null,
          );

    final body = SafeArea(
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    Widget content = surfaceStyle == EnterpriseSurfaceStyle.gradient
        ? EnterpriseGradientBackground(child: body)
        : body;
    if (backgroundColor != null) {
      content = ColoredBox(color: backgroundColor!, child: content);
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: content,
    );
  }
}

enum EnterpriseBannerTone {
  info,
  warning,
  danger,
  success,
}

class EnterpriseBanner extends StatelessWidget {
  const EnterpriseBanner({
    super.key,
    required this.tone,
    required this.title,
    required this.message,
    this.icon,
  });

  final EnterpriseBannerTone tone;
  final String title;
  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = switch (tone) {
      EnterpriseBannerTone.info => (
          AmbyoTheme.primaryColor.withValues(alpha: 0.12),
          AmbyoTheme.primaryColor.withValues(alpha: 0.35),
          AmbyoTheme.primaryColor,
        ),
      EnterpriseBannerTone.warning => (
          AmbyoTheme.warningColor.withValues(alpha: 0.12),
          AmbyoTheme.warningColor.withValues(alpha: 0.35),
          AmbyoTheme.warningColor,
        ),
      EnterpriseBannerTone.danger => (
          AmbyoTheme.dangerColor.withValues(alpha: 0.12),
          AmbyoTheme.dangerColor.withValues(alpha: 0.35),
          AmbyoTheme.dangerColor,
        ),
      EnterpriseBannerTone.success => (
          AmbyoTheme.successColor.withValues(alpha: 0.12),
          AmbyoTheme.successColor.withValues(alpha: 0.35),
          AmbyoTheme.successColor,
        ),
    };

    final resolvedIcon = icon ??
        switch (tone) {
          EnterpriseBannerTone.info => Icons.info_outline_rounded,
          EnterpriseBannerTone.warning => Icons.warning_amber_rounded,
          EnterpriseBannerTone.danger => Icons.error_outline_rounded,
          EnterpriseBannerTone.success => Icons.verified_rounded,
        };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(resolvedIcon, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: fg.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EnterpriseGradientBackground extends StatelessWidget {
  const EnterpriseGradientBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF0A1628),
            Color(0xFF091321),
            Color(0xFF060D1A),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AmbyoColors.cyanAccent.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            left: -60,
            bottom: -100,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AmbyoColors.royalBlue.withValues(alpha: 0.08),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class EnterprisePanel extends StatelessWidget {
  const EnterprisePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AmbyoColors.darkCard.withValues(alpha: 0.98),
            AmbyoColors.darkElevated,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AmbyoColors.darkBorder),
        boxShadow: [
          const BoxShadow(
            color: Color(0x140C1C38),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
          BoxShadow(
            color: AmbyoColors.cyanAccent.withValues(alpha: 0.10),
            blurRadius: 26,
            spreadRadius: -12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class EnterpriseMetricCard extends StatelessWidget {
  const EnterpriseMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.tint = AmbyoTheme.primaryColor,
    this.caption,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tint;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 152),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AmbyoColors.darkCard.withValues(alpha: 0.98),
            tint.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tint.withValues(alpha: 0.16)),
        boxShadow: [
          const BoxShadow(
            color: Color(0x120C1C38),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: tint.withValues(alpha: 0.10),
            blurRadius: 24,
            spreadRadius: -14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: tint),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: AmbyoTheme.dataTextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(
              caption!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class EnterpriseEmptyState extends StatelessWidget {
  const EnterpriseEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: EnterprisePanel(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AmbyoTheme.primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: AmbyoTheme.primaryColor),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                      height: 1.45,
                    ),
              ),
              if (buttonLabel != null && onPressed != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onPressed,
                    child: Text(buttonLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EnterpriseSectionHeader extends StatelessWidget {
  const EnterpriseSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
        ),
      ],
    );
  }
}

/// Wraps a widget and scales to 0.97 on tap (100ms). Use for buttons per UI spec.
class ScalePressWidget extends StatefulWidget {
  const ScalePressWidget({
    super.key,
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<ScalePressWidget> createState() => _ScalePressWidgetState();
}

class _ScalePressWidgetState extends State<ScalePressWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

/// Themed thin royal blue spinner for loading states (no default Material spinner).
class EnterpriseSpinner extends StatelessWidget {
  const EnterpriseSpinner({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(AmbyoTheme.primaryColor),
      ),
    );
  }
}
