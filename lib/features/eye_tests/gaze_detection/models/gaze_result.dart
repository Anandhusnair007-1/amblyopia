import 'dart:math' as math;
import 'dart:ui';

class GazeDirectionResult {
  final String direction;
  final Offset leftEyeGaze;
  final Offset rightEyeGaze;
  final double deviationAngleDegrees;
  final double prismDiopters;
  final bool isAbnormal;
  final DateTime capturedAt;

  const GazeDirectionResult({
    required this.direction,
    required this.leftEyeGaze,
    required this.rightEyeGaze,
    required this.deviationAngleDegrees,
    required this.prismDiopters,
    required this.isAbnormal,
    required this.capturedAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'direction': direction,
        'leftEyeGaze': <String, double>{'dx': leftEyeGaze.dx, 'dy': leftEyeGaze.dy},
        'rightEyeGaze': <String, double>{'dx': rightEyeGaze.dx, 'dy': rightEyeGaze.dy},
        'deviationAngleDegrees': deviationAngleDegrees,
        'prismDiopters': prismDiopters,
        'isAbnormal': isAbnormal,
        'capturedAt': capturedAt.toIso8601String(),
      };
}

class GazeTestResult {
  final List<GazeDirectionResult> directions;
  final double maxDeviation;
  final double avgDeviation;
  final List<String> abnormalDirections;
  final String strabismusType;
  final double prismDiopterValue;
  final bool requiresUrgentReferral;

  const GazeTestResult({
    required this.directions,
    required this.maxDeviation,
    required this.avgDeviation,
    required this.abnormalDirections,
    required this.strabismusType,
    required this.prismDiopterValue,
    required this.requiresUrgentReferral,
  });

  factory GazeTestResult.fromDirections(List<GazeDirectionResult> dirs) {
    if (dirs.isEmpty) {
      return const GazeTestResult(
        directions: <GazeDirectionResult>[],
        maxDeviation: 0,
        avgDeviation: 0,
        abnormalDirections: <String>[],
        strabismusType: 'Normal',
        prismDiopterValue: 0,
        requiresUrgentReferral: false,
      );
    }

    final maxDeviation = dirs.map((e) => e.deviationAngleDegrees).reduce(math.max);
    final avgDeviation =
        dirs.map((e) => e.deviationAngleDegrees).reduce((a, b) => a + b) / dirs.length;
    final abnormalDirections = dirs.where((e) => e.isAbnormal).map((e) => e.direction).toList();
    final prismDiopterValue = dirs.map((e) => e.prismDiopters).reduce(math.max);

    String strabismusType = 'Normal';
    final horizontalBias = dirs.fold<double>(
      0,
      (sum, item) => sum + (item.leftEyeGaze.dx - item.rightEyeGaze.dx),
    );
    final verticalBias = dirs.fold<double>(
      0,
      (sum, item) => sum + (item.leftEyeGaze.dy - item.rightEyeGaze.dy),
    );

    if (horizontalBias.abs() >= verticalBias.abs() && horizontalBias.abs() > 0.1) {
      strabismusType = horizontalBias > 0 ? 'Esotropia' : 'Exotropia';
    } else if (verticalBias.abs() > 0.1) {
      strabismusType = verticalBias > 0 ? 'Hypertropia' : 'Hypotropia';
    }

    return GazeTestResult(
      directions: dirs,
      maxDeviation: maxDeviation,
      avgDeviation: avgDeviation,
      abnormalDirections: abnormalDirections,
      strabismusType: strabismusType,
      prismDiopterValue: prismDiopterValue,
      requiresUrgentReferral: prismDiopterValue > 20,
    );
  }
}
