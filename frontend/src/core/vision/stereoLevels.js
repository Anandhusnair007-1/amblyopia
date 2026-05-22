/**
 * Progressive stereo screening levels → nominal arc-seconds (Dr. Sandra bands).
 * On-screen disparity proxy only — not clinical Titmus.
 */

export const STEREO_LEVELS = [
  { id: "coarse", arc_seconds: 2500, label: "Coarse depth", disparityPx: 0 },
  { id: "severe", arc_seconds: 1000, label: "Severe threshold", disparityPx: 4 },
  { id: "moderate", arc_seconds: 400, label: "Moderate threshold", disparityPx: 8 },
  { id: "mild", arc_seconds: 120, label: "Mild threshold", disparityPx: 14 },
  { id: "normal", arc_seconds: 50, label: "Fine depth", disparityPx: 22 },
];

/** Levels presented coarse → fine (stop at first failure). */
export const STEREO_LEVELS_ASCENDING = [...STEREO_LEVELS].sort(
  (a, b) => b.arc_seconds - a.arc_seconds
);

export function arcSecondsFromLevels(passedLevels) {
  if (!passedLevels.length) return 2500;
  const finest = passedLevels.reduce((a, b) =>
    a.arc_seconds < b.arc_seconds ? a : b
  );
  return finest.arc_seconds;
}

export function stereoGradeFromArcSeconds(arcSeconds) {
  const arc = Number(arcSeconds) || 2500;
  if (arc >= 40 && arc <= 60) return "normal";
  if (arc <= 200) return "mild_impairment";
  if (arc <= 800) return "moderate";
  if (arc <= 2000) return "severe";
  return "absence_stereo";
}

export const STEREO_GRADE_LABELS = {
  normal: "Normal stereopsis (proxy)",
  mild_impairment: "Mild impairment (proxy)",
  moderate: "Moderate impairment (proxy)",
  severe: "Severe impairment (proxy)",
  absence_stereo: "Absent stereopsis (proxy)",
};
