/** Snellen line progression and scoring helpers. */

export const SNELLEN_DENOMINATORS = [60, 36, 24, 18, 12, 9, 6];

export function lineIndexForDenominator(den) {
  const d = Number(den) || 60;
  const idx = SNELLEN_DENOMINATORS.indexOf(d);
  if (idx >= 0) return idx;
  for (let i = 0; i < SNELLEN_DENOMINATORS.length; i++) {
    if (d >= SNELLEN_DENOMINATORS[i]) return i;
  }
  return SNELLEN_DENOMINATORS.length - 1;
}

export function interEyeLinesDiff(odDen, osDen) {
  return Math.abs(lineIndexForDenominator(odDen) - lineIndexForDenominator(osDen));
}

export function worseDenominator(odDen, osDen) {
  return Math.max(Number(odDen) || 60, Number(osDen) || 60);
}

export function snellenLabel(den) {
  return `6/${Math.round(den)}`;
}

/** Patient-safe label — not clinic Snellen. */
export function screeningLineLabel(den) {
  return `~6/${Math.round(den)} screening`;
}

/**
 * After 2 errors on current line, acuity = previous line (or current if first line).
 */
export function acuityFromStaircase(lineIdx, errors) {
  if (errors >= 2) {
    const prev = Math.max(0, lineIdx - 1);
    return SNELLEN_DENOMINATORS[prev];
  }
  return SNELLEN_DENOMINATORS[lineIdx];
}

export function normalizedScoreFromDen(den) {
  return Math.max(0, Math.min(1, 6 / (Number(den) || 60)));
}
