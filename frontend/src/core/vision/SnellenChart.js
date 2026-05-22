/** ISO 8596-style Snellen optotype sizing at a known test distance (screening proxy only). */

export const SCREENING_ACUITY_MEASUREMENT_TYPE = "screening_acuity_estimate";
export const SCREENING_ACUITY_DISCLAIMER =
  "uncalibrated near-screen estimate; not equivalent to clinic Snellen";

const ARCMIN_6_6 = 5; // whole letter subtends 5 arcmin at 6/6

/**
 * Letter height in millimeters for Snellen 6/X at distance D (cm).
 */
export function optotypeHeightMm(distanceCm, snellenDenominator) {
  const dM = distanceCm / 100;
  const den = Math.max(6, Number(snellenDenominator) || 60);
  const height6_6 = dM * Math.tan((ARCMIN_6_6 / 60) * (Math.PI / 180));
  return height6_6 * 1000 * (den / 6);
}

/**
 * Estimate device PPI from screen width and device pixel ratio.
 */
export function estimatePpi() {
  if (typeof window === "undefined") return 160;
  const w = window.screen?.width || 390;
  const dpr = window.devicePixelRatio || 1;
  // Heuristic: phone ~5–6" width in logical px maps to ~400–450 physical px width
  const logicalW = w;
  const assumedInches = logicalW < 500 ? 5.5 : 13;
  return Math.max(120, Math.min(500, (logicalW * dpr) / assumedInches));
}

/**
 * Optotype size in CSS pixels for rendering.
 */
export function getOptotypePx(distanceCm, snellenDenominator, ppi = null) {
  const p = ppi ?? estimatePpi();
  const mm = optotypeHeightMm(distanceCm, snellenDenominator);
  return Math.max(12, Math.round((mm / 25.4) * p));
}

export const DEFAULT_TEST_DISTANCE_CM = 40;
