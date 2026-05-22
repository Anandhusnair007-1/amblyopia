/** Red reflex screening: per-eye HSV + red-dominance on phone camera after white flash. */

export const DEFAULT_RED_REFLEX_THRESHOLDS = {
  patch_size: 21,
  red_ratio_min: 0.38,
  hue_red_max: 40,
  hue_red_min: 320,
  saturation_min: 0.35,
  value_absent_max: 0.1,
  value_leuko_min: 0.85,
  saturation_leuko_max: 0.2,
  value_dim_max: 0.35,
  value_normal_min: 0.3,
};

export function rgbToHsv(r, g, b) {
  r /= 255;
  g /= 255;
  b /= 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const d = max - min;
  let h = 0;
  if (d !== 0) {
    if (max === r) h = 60 * (((g - b) / d) % 6);
    else if (max === g) h = 60 * ((b - r) / d + 2);
    else h = 60 * ((r - g) / d + 4);
    if (h < 0) h += 360;
  }
  return { h, s: max === 0 ? 0 : d / max, v: max };
}

export function averageRgbFromImageData(data) {
  let r = 0;
  let g = 0;
  let b = 0;
  let n = 0;
  for (let i = 0; i < data.length; i += 4) {
    r += data[i];
    g += data[i + 1];
    b += data[i + 2];
    n++;
  }
  if (!n) return null;
  return [r / n, g / n, b / n];
}

export function redRatio(r, g, b) {
  const sum = r + g + b;
  return sum > 0 ? r / sum : 0;
}

export function isRedHue(h, thresholds = DEFAULT_RED_REFLEX_THRESHOLDS) {
  return h < thresholds.hue_red_max || h > thresholds.hue_red_min;
}

/**
 * Classify one eye patch (RGB averages).
 */
export function classifyRedReflexEye(rgb, thresholds = DEFAULT_RED_REFLEX_THRESHOLDS) {
  if (!rgb) return { classification: "indeterminate", hsv: null, red_ratio: 0 };
  const [lr, lg, lb] = rgb;
  const hsv = rgbToHsv(lr, lg, lb);
  const rr = redRatio(lr, lg, lb);
  const { h, s, v } = hsv;

  if (v < thresholds.value_absent_max) {
    return { classification: "absent", hsv, red_ratio: rr };
  }
  if (v > thresholds.value_leuko_min && s < thresholds.saturation_leuko_max) {
    return { classification: "leukocoria", hsv, red_ratio: rr };
  }
  if (
    isRedHue(h, thresholds) &&
    s > thresholds.saturation_min &&
    v > thresholds.value_normal_min &&
    rr >= thresholds.red_ratio_min
  ) {
    return { classification: "normal", hsv, red_ratio: rr };
  }
  if (v < thresholds.value_dim_max) {
    return { classification: "dim", hsv, red_ratio: rr };
  }
  return { classification: "media_opacity", hsv, red_ratio: rr };
}

const SEVERITY_ORDER = {
  leukocoria: 5,
  absent: 4,
  media_opacity: 3,
  dim: 2,
  indeterminate: 1,
  normal: 0,
};

/** Worst-eye aggregate for session scoring. */
export function aggregateRedReflex(left, right) {
  const pick = (a, b) => {
    if (!a) return b;
    if (!b) return a;
    return (SEVERITY_ORDER[a.classification] ?? 0) >= (SEVERITY_ORDER[b.classification] ?? 0) ? a : b;
  };
  const worst = pick(left, right) || { classification: "indeterminate" };
  const asymmetric =
    left &&
    right &&
    left.classification !== right.classification &&
    left.classification !== "indeterminate" &&
    right.classification !== "indeterminate";
  return { classification: worst.classification, asymmetric };
}
