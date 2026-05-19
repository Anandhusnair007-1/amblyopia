/** Patient-facing referral wording — no hardcoded facility names. */

const GENERIC_URGENT_NEXT =
  "Next: consult an ophthalmologist or eye-care professional promptly.";

export function resolveUrgentReferralNext(patient, session) {
  const name =
    (session && session.hospital_name) ||
    (patient && patient.hospital_name) ||
    null;
  if (name && String(name).trim()) {
    return `Next: visit ${String(name).trim()} or another eye-care professional promptly.`;
  }
  return GENERIC_URGENT_NEXT;
}

export function containsHardcodedHospitalCopy(text) {
  return /aravind\s+eye\s+hospital/i.test(String(text || ""));
}

export const PDF_GENERIC_HOSPITAL_LABEL =
  "Refer to ophthalmologist or eye-care professional";

/** Resolve hospital line for PDF header — never hardcode a facility. */
export function resolveReportHospital(patient, session) {
  const name =
    (session && session.hospital_name) ||
    (patient && patient.hospital_name) ||
    null;
  if (name && String(name).trim()) {
    return String(name).trim();
  }
  return PDF_GENERIC_HOSPITAL_LABEL;
}

export function reportTextContainsAravind(text) {
  return containsHardcodedHospitalCopy(text);
}

/** Patient-facing AI strabismus lines — no ET/XT/HT condition codes. */
export const PATIENT_PDF_REPORT_TITLE = "Pediatric Vision Screening Report";
export const DOCTOR_PDF_REPORT_TITLE = "Pediatric Amblyopia Screening Report";

const PATIENT_PDF_BLOCKED_DETAIL_KEYS = new Set([
  "raw_score",
  "normalized_score",
  "displacement_mm",
  "estimatedPD",
  "alignment_proxy_index",
  "max_gaze_stability_index",
  "max_deviation_pd",
  "max_prism_diopters",
  "leftDisplacementMM",
  "rightDisplacementMM",
  "per_direction",
  "all_scores",
  "sample_preview",
]);

const PATIENT_PDF_ALLOWED_DETAIL_KEYS = new Set([
  "skipped",
  "test_status",
  "measurement_valid",
  "measurement_type",
  "screening_status",
  "passed",
  "total",
  "stereo_screening_proxy",
  "true_stereopsis_test",
  "od_label",
  "os_label",
  "inter_eye_lines_diff",
  "test_distance_cm",
  "calibrated",
  "notation_disclaimer",
  "occlusion_verified",
  "note",
  "confidence",
  "quality_gate",
  "classification",
]);

export function pdfReportTitle(patientFacing) {
  return patientFacing ? PATIENT_PDF_REPORT_TITLE : DOCTOR_PDF_REPORT_TITLE;
}

/** Patient PDF detail rows — qualitative fields only. */
export function patientPdfDetailEntries(details = {}) {
  const out = [];
  for (const [k, v] of Object.entries(details || {})) {
    if (PATIENT_PDF_BLOCKED_DETAIL_KEYS.has(k)) continue;
    if (!PATIENT_PDF_ALLOWED_DETAIL_KEYS.has(k)) continue;
    if (v === null || v === undefined) continue;
    const txt = typeof v === "object" ? JSON.stringify(v).slice(0, 100) : String(v);
    out.push([k, txt]);
  }
  return out;
}

export function patientPdfTextIsSafe(text) {
  const s = String(text || "");
  if (/amblyopia/i.test(s)) return false;
  if (/\b(raw_score|normalized_score|displacement_mm|estimatedPD|alignment_proxy_index)\b/i.test(s)) {
    return false;
  }
  if (/\b(ET|XT|HT)\b/.test(s)) return false;
  if (/condition code/i.test(s)) return false;
  return true;
}

/** Short center labels for patient results ring (no numeric health score). */
export function screeningResultRingLabel(riskLevel) {
  const risk = riskLevel || "normal";
  const map = {
    normal: { line1: "No major", line2: "concern" },
    mild: { line1: "Routine", line2: "follow-up" },
    moderate: { line1: "Eye-care", line2: "visit" },
    urgent: { line1: "Prompt", line2: "follow-up" },
    incomplete: { line1: "Repeat", line2: "screening" },
  };
  return map[risk] || map.normal;
}

/** Decorative ring fill % by level — not tied to health_score (patient UI only). */
export function screeningResultRingFillPercent(riskLevel) {
  const map = {
    normal: 88,
    mild: 68,
    moderate: 48,
    urgent: 32,
    incomplete: 40,
  };
  return map[riskLevel] ?? map.normal;
}

/** Labels used on patient-facing PDF summary (no numeric health/risk scores). */
export function patientPdfSummaryLabels(patientFacing) {
  if (!patientFacing) {
    return {
      pageHeader: "Summary & AI Risk",
      findingsHeading: "Clinical Findings",
      showsNumericScores: true,
    };
  }
  return {
    pageHeader: "Screening Summary",
    findingsHeading: "Screening Findings",
    showsNumericScores: false,
  };
}

/** Urgent UI only when rule-based session risk warrants it — never from AI strabismus risk alone. */
export function gateShowsUrgentBanner(ruleBasedRiskLevel, strabismusRisk) {
  void strabismusRisk;
  return ruleBasedRiskLevel === "urgent" || ruleBasedRiskLevel === "moderate";
}

export function patientStrabismusPdfLines(strabismus_ai, { patientFacing = true } = {}) {
  if (!strabismus_ai || !strabismus_ai.risk || strabismus_ai.risk === "normal") {
    return [];
  }
  if (!patientFacing) {
    const lines = [];
    if (strabismus_ai.condition) {
      lines.push(`Condition code: ${strabismus_ai.condition}`);
    }
    lines.push(`AI risk: ${String(strabismus_ai.risk).toUpperCase()}`);
    if (strabismus_ai.recommendation) {
      lines.push(strabismus_ai.recommendation);
    }
    return lines;
  }
  return [
    strabismus_ai.recommendation ||
      "AI screening output suggests this should be reviewed by an eye-care professional.",
    "AI-assisted screening. Not a medical diagnosis.",
  ];
}
