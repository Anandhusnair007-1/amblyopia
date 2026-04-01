import 'package:flutter/material.dart';

import '../theme/ambyo_theme.dart';
import '../services/distance_calculator.dart' show DistanceStatus, DistanceZone, distanceStatus;

/// Real-time distance indicator: text badge (Too close / X cm Good / Move closer)
/// and a bar (20cm — 40cm — 60cm+). Optimal zone is configurable per test.
class DistanceIndicator extends StatelessWidget {
  const DistanceIndicator({
    super.key,
    required this.distanceCm,
    required this.zone,
    this.compact = false,
  });

  /// Current distance in cm (0 = no face).
  final double distanceCm;

  /// Optimal range for this test.
  final DistanceZone zone;

  /// If true, show only the text badge without the bar.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final status = distanceStatus(distanceCm, zone);

    final (Color bg, Color border, String text, IconData icon) = switch (status) {
      DistanceStatus.noFace => (
          const Color(0xFF374151),
          const Color(0xFF6B7280),
          'Face the camera',
          Icons.face_retouching_natural_rounded,
        ),
      DistanceStatus.tooClose => (
          AmbyoTheme.dangerColor.withValues(alpha: 0.2),
          AmbyoTheme.dangerColor,
          '←← Too close',
          Icons.arrow_back_rounded,
        ),
      DistanceStatus.good => (
          AmbyoTheme.successColor.withValues(alpha: 0.2),
          AmbyoTheme.successColor,
          '✓ ${distanceCm.round()}cm  Good',
          Icons.check_circle_rounded,
        ),
      DistanceStatus.tooFar => (
          AmbyoTheme.warningColor.withValues(alpha: 0.2),
          AmbyoTheme.warningColor,
          '→→ Move closer',
          Icons.arrow_forward_rounded,
        ),
    };

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: border),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: border,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );

    if (compact) {
      return badge;
    }

    // Bar: 20 — 40 — 60+ with thumb at current distance (clamped to bar range)
    const barMin = 20.0;
    const barMax = 65.0;
    final t = (distanceCm.clamp(barMin, barMax) - barMin) / (barMax - barMin);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              SizedBox(
                height: 8,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Track
                        Container(
                          width: w,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF374151),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // Thumb
                        Positioned(
                          left: (w - 16) * t.clamp(0.0, 1.0),
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: status == DistanceStatus.good
                                  ? AmbyoTheme.successColor
                                  : (status == DistanceStatus.tooClose
                                      ? AmbyoTheme.dangerColor
                                      : AmbyoTheme.warningColor),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '20cm',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '40cm',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '60cm+',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Returns true when distance is in the optimal zone (for gating test start).
bool isInOptimalZone(double distanceCm, DistanceZone zone) {
  return distanceStatus(distanceCm, zone) == DistanceStatus.good;
}
