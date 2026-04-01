import 'package:shared_preferences/shared_preferences.dart';

/// One-time per-device calibration: A4 paper (21 cm wide) held at arm's length.
/// Stores paper width in pixels; distance calculation uses this when available.
class DistanceCalibrationService {
  DistanceCalibrationService._();
  static final DistanceCalibrationService instance = DistanceCalibrationService._();

  static const _keyRefPaperWidthPx = 'ambyoai_distance_cal_ref_paper_width_px';
  static const _keyRefDistanceCm = 'ambyoai_distance_cal_ref_distance_cm';

  /// A4 short edge in cm (paper held in portrait: width = 21 cm).
  static const double refPaperWidthCm = 21.0;

  /// Default arm's length in cm when user holds the paper.
  static const double defaultRefDistanceCm = 55.0;

  double? _refPaperWidthPx;
  double? _refDistanceCm;
  bool _loaded = false;

  /// Paper width in pixels at calibration (image coordinates).
  double? get refPaperWidthPx => _refPaperWidthPx;

  /// Distance (cm) at which calibration was done (arm's length).
  double get refDistanceCm => _refDistanceCm ?? defaultRefDistanceCm;

  bool get hasCalibration => _refPaperWidthPx != null && (_refPaperWidthPx ?? 0) > 0;

  /// Load calibration from SharedPreferences. Call at app start or before first distance use.
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final px = prefs.getDouble(_keyRefPaperWidthPx);
    final d = prefs.getDouble(_keyRefDistanceCm);
    _refPaperWidthPx = px;
    _refDistanceCm = d ?? defaultRefDistanceCm;
    _loaded = true;
  }

  /// Save calibration (paper width in pixels at ref distance). One-time per device.
  Future<void> save({
    required double paperWidthPx,
    double refDistanceCm = defaultRefDistanceCm,
  }) async {
    if (paperWidthPx <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyRefPaperWidthPx, paperWidthPx);
    await prefs.setDouble(_keyRefDistanceCm, refDistanceCm);
    _refPaperWidthPx = paperWidthPx;
    _refDistanceCm = refDistanceCm;
    _loaded = true;
  }

  /// Clear calibration (e.g. for re-calibration).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRefPaperWidthPx);
    await prefs.remove(_keyRefDistanceCm);
    _refPaperWidthPx = null;
    _refDistanceCm = defaultRefDistanceCm;
  }
}
