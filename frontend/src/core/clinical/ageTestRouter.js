import VisualAcuityTest from "@/tests/VisualAcuityTest";
import GazeTest from "@/tests/GazeTest";
import HirschbergTest from "@/tests/HirschbergTest";
import PrismDiopterTest from "@/tests/PrismDiopterTest";
import TitmusTest from "@/tests/TitmusTest";
import RedReflexTest from "@/tests/RedReflexTest";

/** Full catalog — Heidelberg excluded from default flows. */
export const TEST_CATALOG = {
  visual_acuity: { id: "visual_acuity", labelKey: "test_visual_acuity", comp: VisualAcuityTest, distance: [35, 45] },
  gaze: { id: "gaze", labelKey: "test_gaze", comp: GazeTest, distance: [40, 60] },
  hirschberg: { id: "hirschberg", labelKey: "test_hirschberg", comp: HirschbergTest, distance: [30, 45] },
  prism: { id: "prism", labelKey: "test_prism", comp: PrismDiopterTest, distance: [0, 0] },
  titmus: { id: "titmus", labelKey: "test_titmus", comp: TitmusTest, distance: [40, 60] },
  red_reflex: { id: "red_reflex", labelKey: "test_red_reflex", comp: RedReflexTest, distance: [25, 35] },
};

const BANDS = [
  { id: "infant", min: 0, max: 1, tests: ["red_reflex"] },
  { id: "toddler", min: 1, max: 3, tests: ["red_reflex", "visual_acuity", "gaze"] },
  { id: "child", min: 3, max: 12, tests: ["visual_acuity", "gaze", "hirschberg", "prism", "titmus", "red_reflex"] },
  { id: "teen", min: 13, max: 17, tests: ["visual_acuity", "gaze", "hirschberg", "prism", "titmus", "red_reflex"] },
  { id: "adult", min: 18, max: 64, tests: ["visual_acuity", "gaze", "hirschberg", "prism", "titmus"] },
  { id: "senior", min: 65, max: 99, tests: ["visual_acuity", "red_reflex"] },
];

export function getAgeBand(ageYears) {
  const age = Number(ageYears);
  if (!Number.isFinite(age) || age < 0) return BANDS.find((b) => b.id === "child");
  for (const band of BANDS) {
    if (age >= band.min && age <= band.max) return band;
  }
  return BANDS.find((b) => b.id === "adult");
}

export function getTestFlowForAge(ageYears) {
  const band = getAgeBand(ageYears);
  return band.tests.map((id) => TEST_CATALOG[id]).filter(Boolean);
}

export function isTestAllowedForAge(testId, ageYears) {
  const band = getAgeBand(ageYears);
  return band.tests.includes(testId);
}
