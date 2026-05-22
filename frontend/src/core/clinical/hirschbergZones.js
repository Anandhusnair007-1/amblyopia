/** Hirschberg zone mapping: corneal reflex offset vs iris radius → discrete prism proxy (Δ). */

export const DEFAULT_ZONE_THRESHOLDS = {
  center_max_r: 0.35,
  pupil_edge_max_r: 0.85,
  mid_cornea_max_r: 1.35,
};

export const ZONE_PD = {
  center: 0,
  pupil_edge: 15,
  mid_cornea: 30,
  limbus: 45,
};

export const ZONE_LABELS = {
  center: "Center",
  pupil_edge: "Pupil edge",
  mid_cornea: "Between pupil and limbus",
  limbus: "At limbus",
};

/**
 * Normalized reflex offset: displacement from iris center in half-iris units.
 * @param {number} displacementPx
 * @param {number} irisDiameterPx
 */
export function normalizedOffsetR(displacementPx, irisDiameterPx) {
  if (!Number.isFinite(displacementPx) || !Number.isFinite(irisDiameterPx) || irisDiameterPx < 4) {
    return null;
  }
  const half = irisDiameterPx / 2;
  return displacementPx / half;
}

/**
 * Map normalized offset to Sandra zone grades (0, 15, 30, 45 Δ proxy).
 */
export function zoneFromNormalizedR(r, thresholds = DEFAULT_ZONE_THRESHOLDS) {
  if (!Number.isFinite(r) || r < 0) {
    return { zone: "center", predicted_pd: 0, hirschberg_zone: "center" };
  }
  if (r < thresholds.center_max_r) {
    return { zone: "center", predicted_pd: ZONE_PD.center, hirschberg_zone: "center" };
  }
  if (r < thresholds.pupil_edge_max_r) {
    return { zone: "pupil_edge", predicted_pd: ZONE_PD.pupil_edge, hirschberg_zone: "pupil_edge" };
  }
  if (r < thresholds.mid_cornea_max_r) {
    return { zone: "mid_cornea", predicted_pd: ZONE_PD.mid_cornea, hirschberg_zone: "mid_cornea" };
  }
  return { zone: "limbus", predicted_pd: ZONE_PD.limbus, hirschberg_zone: "limbus" };
}

/**
 * @param {{ displacementPx: number, irisDiameterPx: number }} eyeMeasure
 */
export function classifyEyeZone(eyeMeasure, thresholds = DEFAULT_ZONE_THRESHOLDS) {
  if (!eyeMeasure) return null;
  const r = normalizedOffsetR(eyeMeasure.displacementPx, eyeMeasure.irisDiameterPx);
  if (r == null) return null;
  return { normalized_offset_r: +r.toFixed(3), ...zoneFromNormalizedR(r, thresholds) };
}

/**
 * Worst eye = highest predicted_pd.
 */
export function aggregateHirschbergZones(leftZone, rightZone) {
  const zones = [leftZone, rightZone].filter(Boolean);
  if (!zones.length) {
    return { zone: "center", predicted_pd: 0, hirschberg_zone: "center", normalized_offset_r: 0 };
  }
  const worst = zones.reduce((a, b) => (b.predicted_pd > a.predicted_pd ? b : a));
  return {
    zone: worst.zone,
    predicted_pd: worst.predicted_pd,
    hirschberg_zone: worst.hirschberg_zone,
    normalized_offset_r: Math.max(...zones.map((z) => z.normalized_offset_r)),
  };
}
