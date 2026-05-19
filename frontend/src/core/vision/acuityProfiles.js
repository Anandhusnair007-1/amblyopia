/** Age-based visual acuity optotype profiles. */

export function getAcuityProfile(ageYears) {
  const age = Number(ageYears) || 8;
  if (age <= 4) return "A"; // pictures
  if (age <= 7) return "B"; // tumbling E (simplified)
  return "C"; // tumbling E full lines
}

export function usesPictureOptotypes(profile) {
  return profile === "A";
}

/** Profile A (young child pictures) cannot be scored reliably on-device. */
export function isScorableAcuityProfile(profile) {
  return profile !== "A";
}
