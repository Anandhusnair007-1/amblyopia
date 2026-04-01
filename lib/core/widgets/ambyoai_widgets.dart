import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:math' as math;
import 'dart:ui';

import '../theme/ambyoai_design_system.dart';
import '../theme/ambyo_theme.dart';

/// Standard card with optional left border (e.g. for risk coding) and tap.
class AmbyoCard extends StatelessWidget {
  const AmbyoCard({
    super.key,
    required this.child,
    this.borderLeftColor,
    this.onTap,
    this.padding,
  });

  final Widget child;
  final Color? borderLeftColor;
  final VoidCallback? onTap;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding ?? const EdgeInsets.all(AmbyoSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AmbyoColors.cardLight,
        borderRadius: BorderRadius.circular(AmbyoSpacing.cardRadius),
        border: borderLeftColor != null
            ? Border(
                left: BorderSide(width: 4, color: borderLeftColor!),
                top: const BorderSide(color: AmbyoTheme.borderLight),
                right: const BorderSide(color: AmbyoTheme.borderLight),
                bottom: const BorderSide(color: AmbyoTheme.borderLight),
              )
            : Border.all(color: AmbyoTheme.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120C1C38),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AmbyoSpacing.cardRadius),
          child: content,
        ),
      );
    }
    return content;
  }
}

/// Primary action button with optional icon.
class AmbyoPrimaryButton extends StatelessWidget {
  const AmbyoPrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.height,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final h = height ?? AmbyoSpacing.btnHeight;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: AmbyoSpacing.iconSm, color: Colors.white),
          const SizedBox(width: AmbyoSpacing.inlineGap),
        ],
        Text(label,
            style: AmbyoTextStyles.body(color: Colors.white, fontSize: 15)
                .copyWith(fontWeight: FontWeight.w600)),
      ],
    );
    return SizedBox(
      height: h,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AmbyoColors.royalBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AmbyoSpacing.cardRadius),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Section title with optional subtitle and action.
class AmbyoSectionHeader extends StatelessWidget {
  const AmbyoSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AmbyoSpacing.inlineGap),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AmbyoTextStyles.subtitle()),
                if (subtitle != null) ...[
                  const SizedBox(height: AmbyoSpacing.tinyGap),
                  Text(subtitle!, style: AmbyoTextStyles.caption()),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!,
                  style: AmbyoTextStyles.body(color: AmbyoColors.royalBlue)
                      .copyWith(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

/// Risk level badge (NORMAL / MILD / HIGH / URGENT).
class AmbyoRiskBadge extends StatelessWidget {
  const AmbyoRiskBadge({super.key, required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final color = AmbyoColors.riskColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        level.toUpperCase(),
        style: AmbyoTextStyles.caption(color: color)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Standard text field with label and optional prefix icon.
class AmbyoTextField extends StatelessWidget {
  const AmbyoTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.validator,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.obscureText = false,
    this.readOnly = false,
    this.minLines,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final bool readOnly;
  final int? minLines;
  final int? maxLines;
  final void Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: AmbyoTextStyles.caption()),
          const SizedBox(height: AmbyoSpacing.tinyGap),
        ],
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          minLines: minLines,
          maxLines: maxLines ?? 1,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon,
                    size: AmbyoSpacing.iconSm, color: const Color(0xFF546E7A))
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AmbyoTheme.borderLight, width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AmbyoTheme.borderLight, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AmbyoColors.royalBlue, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFC62828), width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFC62828), width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            hintStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Color(0xFFB0BEC5),
              fontWeight: FontWeight.w400,
            ),
          ),
          validator: validator,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          onChanged: onChanged,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF0A1628),
          ),
        ),
      ],
    );
  }
}

/// Shimmer placeholder for loading states. Use consistent height to match content.
class AmbyoShimmer extends StatelessWidget {
  const AmbyoShimmer(
      {super.key, required this.height, this.width, this.dark = false});

  final double height;
  final double? width;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final base = dark ? const Color(0xFF2A2A2A) : const Color(0xFFE6EDF7);
    final highlight = dark ? const Color(0xFF3A3A3A) : Colors.white;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(AmbyoSpacing.cardRadius),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 18,
    this.borderColor,
    this.backgroundColor,
    this.gradient,
    this.glowColor,
    this.blurSigma = 14,
    this.shadows,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets? padding;
  final double radius;
  final Color? borderColor;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? glowColor;
  final double blurSigma;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: gradient == null
                ? (backgroundColor ?? const Color(0x1417263F))
                : null,
            gradient: gradient ??
                LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (backgroundColor ?? const Color(0x1417263F))
                        .withValues(alpha: 0.92),
                    (backgroundColor ?? const Color(0x1417263F))
                        .withValues(alpha: 0.72),
                  ],
                ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? const Color(0x3A8BE9FF),
              width: 1,
            ),
            boxShadow: shadows ??
                [
                  BoxShadow(
                    color: (glowColor ?? AmbyoColors.cyanAccent)
                        .withValues(alpha: 0.12),
                    blurRadius: 24,
                    spreadRadius: -8,
                    offset: const Offset(0, 8),
                  ),
                  const BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 28,
                    spreadRadius: -10,
                    offset: Offset(0, 18),
                  ),
                ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -28,
                right: -24,
                child: IgnorePointer(
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          (glowColor ?? AmbyoColors.cyanAccent)
                              .withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.24),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

class ScoreRing3D extends StatefulWidget {
  const ScoreRing3D({
    super.key,
    required this.score,
    required this.size,
    required this.riskLevel,
  });

  final double score;
  final double size;
  final String riskLevel;

  @override
  State<ScoreRing3D> createState() => _ScoreRing3DState();
}

class _ScoreRing3DState extends State<ScoreRing3D>
    with TickerProviderStateMixin {
  late final AnimationController _ringController;
  late final AnimationController _pulseController;
  late final AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..forward();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _rotateController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 8000))
      ..repeat();
  }

  @override
  void dispose() {
    _ringController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  Color get _riskColor {
    switch (widget.riskLevel.toUpperCase()) {
      case 'NORMAL':
        return AmbyoColors.normalGreen;
      case 'MILD':
        return AmbyoColors.mildAmber;
      case 'HIGH':
        return AmbyoColors.highOrange;
      case 'URGENT':
        return AmbyoColors.urgentRed;
      default:
        return AmbyoColors.cyanAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final color = _riskColor;
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_ringController, _pulseController, _rotateController]),
      builder: (context, _) {
        final ringVal = Curves.easeOutCubic.transform(_ringController.value);
        final pulseVal = _pulseController.value;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 1.0 + pulseVal * 0.08,
                child: Opacity(
                  opacity: 0.3 - pulseVal * 0.2,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: size * 0.85,
                height: size * 0.85,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: size * 0.07,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(
                      Colors.white.withValues(alpha: 0.05)),
                ),
              ),
              Transform.rotate(
                angle: _rotateController.value * 2 * math.pi,
                child: SizedBox(
                  width: size * 0.85,
                  height: size * 0.85,
                  child: CustomPaint(
                    painter: _GradientArcPainter(
                      progress: ringVal *
                          (widget.score > 0 ? widget.score / 100 : 1.0),
                      color: color,
                      strokeWidth: size * 0.07,
                      isEmpty: widget.score == 0,
                    ),
                  ),
                ),
              ),
              if (widget.score > 0)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: widget.score),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (context, val, _) => Text(
                        '${val.round()}',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: size * 0.28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                    Text(
                      '/100',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: size * 0.11,
                        color: Colors.white38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: 0.3 + pulseVal * 0.4,
                      child: Icon(Icons.remove_red_eye_outlined,
                          color: AmbyoColors.cyanAccent, size: size * 0.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to\nbegin',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: size * 0.09,
                        color: Colors.white24,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GradientArcPainter extends CustomPainter {
  _GradientArcPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.isEmpty,
  });

  final double progress;
  final Color color;
  final double strokeWidth;
  final bool isEmpty;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    if (isEmpty) {
      final dashPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 12; i++) {
        final startAngle = (i * 30 - 90) * (math.pi / 180);
        canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
            startAngle, 0.35, false, dashPaint);
      }
      return;
    }

    final sweepAngle = progress * 2 * math.pi;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + sweepAngle,
      colors: [color.withValues(alpha: 0.5), color],
      tileMode: TileMode.clamp,
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, paint);

    if (progress > 0.02) {
      final endAngle = -math.pi / 2 + sweepAngle;
      final dotX = center.dx + radius * math.cos(endAngle);
      final dotY = center.dy + radius * math.sin(endAngle);
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth);
      canvas.drawCircle(Offset(dotX, dotY), strokeWidth / 2, glowPaint);
      final dotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(dotX, dotY), strokeWidth / 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GradientArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class TestCard3D extends StatefulWidget {
  const TestCard3D({
    super.key,
    required this.testName,
    required this.icon,
    required this.accentColor,
    required this.value,
    required this.date,
    required this.risk,
    required this.onTap,
    this.index = 0,
  });

  final String testName;
  final IconData icon;
  final Color accentColor;
  final String value;
  final String date;
  final String risk;
  final VoidCallback onTap;
  final int index;

  @override
  State<TestCard3D> createState() => _TestCard3DState();
}

class _TestCard3DState extends State<TestCard3D> {
  bool _pressed = false;
  double _tiltX = 0;
  double _tiltY = 0;

  void _onPanUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    final w = box.size.width;
    final h = box.size.height;
    setState(() {
      _tiltY = ((local.dx / w) - 0.5) * 0.2;
      _tiltX = -((local.dy / h) - 0.5) * 0.2;
    });
  }

  void _resetTilt() {
    setState(() {
      _tiltX = 0;
      _tiltY = 0;
    });
  }

  Color get _riskColor {
    switch (widget.risk.toUpperCase()) {
      case 'NORMAL':
        return AmbyoColors.normalGreen;
      case 'MILD':
        return AmbyoColors.mildAmber;
      case 'HIGH':
        return AmbyoColors.highOrange;
      case 'URGENT':
        return AmbyoColors.urgentRed;
      default:
        return Colors.white24;
    }
  }

  double get _progressVal {
    switch (widget.risk.toUpperCase()) {
      case 'NORMAL':
        return 0.92;
      case 'MILD':
        return 0.62;
      case 'HIGH':
        return 0.35;
      case 'URGENT':
        return 0.12;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onPanUpdate: _onPanUpdate,
      onPanEnd: (_) => _resetTilt(),
      onPanCancel: _resetTilt,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(_tiltX)
          ..rotateY(_tiltY)
          ..multiply(
            Matrix4.diagonal3Values(
              _pressed ? 0.95 : 1,
              _pressed ? 0.95 : 1,
              1,
            ),
          ),
        decoration: BoxDecoration(
          color: AmbyoColors.darkCard,
          borderRadius: BorderRadius.circular(20),
          border:
              Border(left: BorderSide(color: widget.accentColor, width: 3.5)),
          boxShadow: [
            BoxShadow(
              color: widget.accentColor.withValues(
                alpha: _pressed ? 0.3 : 0.12,
              ),
              blurRadius: _pressed ? 24 : 16,
              offset: Offset(0, _pressed ? 4 : 8),
              spreadRadius: _pressed ? -2 : -4,
            ),
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      widget.accentColor.withValues(alpha: 0.3),
                      widget.accentColor.withValues(alpha: 0.1)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(widget.icon, size: 20, color: widget.accentColor),
              ),
              const Spacer(),
              Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: _riskColor)),
            ]),
            const SizedBox(height: 14),
            Text(
              widget.value.isEmpty ? '—' : widget.value,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                shadows: widget.value.isNotEmpty
                    ? [
                        Shadow(
                            color: widget.accentColor.withValues(alpha: 0.3),
                            blurRadius: 8)
                      ]
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(widget.testName,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            const SizedBox(height: 2),
            Text(widget.date.isEmpty ? 'Not tested yet' : widget.date,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: Colors.white30)),
            if (widget.value.isNotEmpty) ...[
              const SizedBox(height: 12),
              Stack(children: [
                Container(
                    height: 3,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(2))),
                FractionallySizedBox(
                  widthFactor: _progressVal,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        widget.accentColor,
                        widget.accentColor.withValues(alpha: 0.4)
                      ]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ]),
            ],
            const Spacer(),
            Row(children: [
              Text('Run Test',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: widget.accentColor,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded,
                  size: 14, color: widget.accentColor),
            ]),
          ],
        ),
      ),
    );
  }
}

class NeonGradientButton extends StatefulWidget {
  const NeonGradientButton({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.onTap,
    this.height = 64,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback onTap;
  final double height;

  @override
  State<NeonGradientButton> createState() => _NeonGradientButtonState();
}

class _NeonGradientButtonState extends State<NeonGradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: AmbyoGradients.primaryBtn,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AmbyoShadows.buttonGlow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(children: [
              AnimatedBuilder(
                animation: _shimmerController,
                builder: (context, _) {
                  final val = _shimmerController.value;
                  return Positioned(
                    left: -100 + val * 500,
                    top: 0,
                    bottom: 0,
                    width: 80,
                    child: Transform(
                      transform: Matrix4.skewX(-0.3),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.12),
                            Colors.transparent
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Row(children: [
                const SizedBox(width: 20),
                if (widget.icon != null)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle),
                    child: Icon(widget.icon!, color: Colors.white, size: 22),
                  ),
                if (widget.icon != null) const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      if (widget.subtitle != null)
                        Text(widget.subtitle!,
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: Colors.white70)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white60, size: 14),
                const SizedBox(width: 16),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class FloatingStatCard extends StatelessWidget {
  const FloatingStatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.index = 0,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final int index;

  @override
  Widget build(BuildContext context) {
    final numeric =
        double.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AmbyoColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4)),
            const BoxShadow(
                color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.1),
                ]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 10),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: numeric),
              duration: Duration(milliseconds: 800 + index * 100),
              curve: Curves.easeOutCubic,
              builder: (context, val, _) => Text(
                value.contains(RegExp(r'[^0-9]')) ? value : '${val.round()}',
                style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    color: Colors.white38,
                    letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }
}

class NeonRiskBadge extends StatelessWidget {
  const NeonRiskBadge({super.key, required this.level});

  final String level;

  Color get _color {
    switch (level.toUpperCase()) {
      case 'NORMAL':
        return AmbyoColors.normalGreen;
      case 'MILD':
        return AmbyoColors.mildAmber;
      case 'HIGH':
        return AmbyoColors.highOrange;
      case 'URGENT':
        return AmbyoColors.urgentRed;
      default:
        return AmbyoColors.unscreened;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
              color: _color.withValues(alpha: 0.2),
              blurRadius: 8,
              spreadRadius: -2)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _color,
                  boxShadow: [BoxShadow(color: _color, blurRadius: 4)])),
          const SizedBox(width: 6),
          Text(level.toUpperCase(),
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _color,
                  letterSpacing: 0.8)),
        ],
      ),
    );
  }
}

class DarkShimmer extends StatelessWidget {
  const DarkShimmer(
      {super.key, required this.height, this.width, this.radius = 12});

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF111827),
      highlightColor: const Color(0xFF1F2B3E),
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}
