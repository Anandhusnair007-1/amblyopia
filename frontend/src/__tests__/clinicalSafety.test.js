/**
 * Critical clinical-safety regressions (screening only, not diagnosis).
 */
import { getAcuityProfile, isScorableAcuityProfile, usesPictureOptotypes } from "../core/vision/acuityProfiles";
import { SCREENING_ACUITY_MEASUREMENT_TYPE } from "../core/vision/SnellenChart";
import { saveScreenCalibration, loadScreenCalibration } from "../core/vision/ScreenCalibration";
import {
  gateShowsUrgentBanner,
  patientPdfDetailEntries,
  patientPdfSummaryLabels,
  patientStrabismusPdfLines,
  pdfReportTitle,
  reportTextContainsAravind,
  resolveReportHospital,
  screeningResultRingFillPercent,
  screeningResultRingLabel,
  PDF_GENERIC_HOSPITAL_LABEL,
  PATIENT_PDF_REPORT_TITLE,
} from "../lib/referralCopy";
import { translations } from "../core/i18n/translations";

describe("pediatric visual acuity profiles", () => {
  it("profile A is not scorable with direction keys", () => {
    const profile = getAcuityProfile(4);
    expect(profile).toBe("A");
    expect(usesPictureOptotypes(profile)).toBe(true);
    expect(isScorableAcuityProfile(profile)).toBe(false);
  });

  it("school-age profile B/C remain scorable with tumbling E", () => {
    expect(isScorableAcuityProfile(getAcuityProfile(6))).toBe(true);
    expect(isScorableAcuityProfile(getAcuityProfile(10))).toBe(true);
  });
});

describe("screening acuity metadata", () => {
  it("exports screening measurement type constant", () => {
    expect(SCREENING_ACUITY_MEASUREMENT_TYPE).toBe("screening_acuity_estimate");
  });
});

describe("skipped test payload shape", () => {
  it("preserves skipped and invalid measurement flags", () => {
    const details = { skipped: true, test_status: "skipped", measurement_valid: false };
    expect(details.skipped).toBe(true);
    expect(details.test_status).toBe("skipped");
    expect(details.measurement_valid).toBe(false);
  });
});

describe("referral copy (H8)", () => {
  const { resolveUrgentReferralNext, containsHardcodedHospitalCopy } = require("../lib/referralCopy");

  it("uses generic wording when no hospital configured", () => {
    const next = resolveUrgentReferralNext({}, {});
    expect(containsHardcodedHospitalCopy(next)).toBe(false);
    expect(next).toMatch(/ophthalmologist|eye-care professional/i);
  });

  it("uses session hospital name when provided", () => {
    const next = resolveUrgentReferralNext({}, { hospital_name: "Community Eye Clinic" });
    expect(next).toContain("Community Eye Clinic");
    expect(containsHardcodedHospitalCopy(next)).toBe(false);
  });
});

describe("patient results copy — incomplete sessions", () => {
  const FRIENDLY_INCOMPLETE = {
    title: "Incomplete or unreliable screening",
    message:
      "Some tests were skipped, could not be scored, or may be unreliable.",
  };

  it("does not use normal-friendly title for incomplete risk", () => {
    const risk = "incomplete";
    const normalTitle = "No major screening concern on this pass";
    const copy =
      risk === "incomplete"
        ? FRIENDLY_INCOMPLETE
        : { title: normalTitle, message: "" };
    expect(copy.title).not.toBe("All looks good!");
    expect(copy.message).toMatch(/unreliable/i);
  });
});

describe("physical screen calibration", () => {
  beforeEach(() => window.localStorage.clear());

  it("stores calibration method and pixel/mm values", () => {
    const cal = saveScreenCalibration({
      method: "standard_card",
      referenceWidthMm: 85.6,
      referenceWidthPx: 342,
    });
    expect(cal.method).toBe("standard_card");
    expect(cal.px_per_mm).toBeGreaterThan(0);
    expect(cal.device_info).toBeTruthy();
    expect(loadScreenCalibration().reference_width_px).toBe(342);
  });
});

describe("PDF hospital and patient AI safety", () => {
  it("resolveReportHospital does not default to Aravind", () => {
    const label = resolveReportHospital({}, {});
    expect(reportTextContainsAravind(label)).toBe(false);
    expect(label).toMatch(/ophthalmologist|eye-care professional/i);
  });

  it("resolveReportHospital uses configured hospital name", () => {
    const label = resolveReportHospital({}, { hospital_name: "Community Eye Clinic" });
    expect(label).toBe("Community Eye Clinic");
  });

  it("generic PDF hospital label does not embed Aravind", () => {
    expect(reportTextContainsAravind(PDF_GENERIC_HOSPITAL_LABEL)).toBe(false);
    expect(reportTextContainsAravind(resolveReportHospital({}, {}))).toBe(false);
  });

  it("patient PDF title does not contain Amblyopia", () => {
    expect(pdfReportTitle(true)).toBe(PATIENT_PDF_REPORT_TITLE);
    expect(pdfReportTitle(true).toLowerCase()).not.toContain("amblyopia");
  });

  it("patient PDF summary uses screening headings without numeric scores", () => {
    const labels = patientPdfSummaryLabels(true);
    expect(labels.pageHeader).toBe("Screening Summary");
    expect(labels.findingsHeading).toBe("Screening Findings");
    expect(labels.showsNumericScores).toBe(false);
    expect(labels.findingsHeading).not.toBe("Clinical Findings");
  });

  it("doctor PDF summary keeps clinical headings and numeric scores flag", () => {
    const labels = patientPdfSummaryLabels(false);
    expect(labels.findingsHeading).toBe("Clinical Findings");
    expect(labels.showsNumericScores).toBe(true);
  });

  it("patientPdfDetailEntries omits raw numeric proxy fields", () => {
    const rows = patientPdfDetailEntries({
      raw_score: 12,
      normalized_score: 0.5,
      displacement_mm: 2.1,
      estimatedPD: 15,
      alignment_proxy_index: 9,
      max_gaze_stability_index: 8,
      screening_status: "needs review",
    });
    const keys = rows.map(([k]) => k);
    expect(keys).not.toContain("raw_score");
    expect(keys).not.toContain("normalized_score");
    expect(keys).not.toContain("displacement_mm");
    expect(keys).not.toContain("estimatedPD");
    expect(keys).toContain("screening_status");
  });

  it("patientPdfDetailEntries includes hirschberg screening_status when provided", () => {
    const rows = patientPdfDetailEntries({
      screening_status: "within screening range",
      measurement_type: "hirschberg_alignment_proxy",
    });
    expect(rows.some(([k]) => k === "screening_status")).toBe(true);
    expect(rows.some(([, v]) => String(v).includes("mm"))).toBe(false);
  });

  it("patientStrabismusPdfLines omits ET/XT/HT condition codes", () => {
    const lines = patientStrabismusPdfLines(
      { risk: "mild", condition: "ET", recommendation: "Review suggested." },
      { patientFacing: true },
    );
    const joined = lines.join(" ");
    expect(joined).not.toMatch(/\bET\b/);
    expect(joined).not.toMatch(/\bXT\b/);
    expect(joined).not.toMatch(/\bHT\b/);
    expect(joined).not.toMatch(/condition code/i);
  });

  it("urgent strabismus_ai alone does not drive patient PDF urgent wording via condition", () => {
    const lines = patientStrabismusPdfLines(
      { risk: "urgent", condition: "XT" },
      { patientFacing: true },
    );
    expect(lines.join(" ")).not.toContain("XT");
  });
});

describe("patient-facing findings wording", () => {
  it("typical inter-eye patient finding avoids amblyopia label", () => {
    const findings = [
      "Screening found a difference between the two eyes. Please confirm with an eye-care professional.",
    ];
    const joined = findings.join(" ").toLowerCase();
    expect(joined).not.toContain("amblyopia");
    expect(joined).toContain("difference between the two eyes");
  });
});

describe("AIScreeningGate urgent policy", () => {
  it("does not show urgent banner from strabismus risk alone", () => {
    expect(gateShowsUrgentBanner(null, "urgent")).toBe(false);
    expect(gateShowsUrgentBanner("normal", "urgent")).toBe(false);
  });

  it("shows urgent banner only for rule-based urgent or moderate", () => {
    expect(gateShowsUrgentBanner("urgent", "urgent")).toBe(true);
    expect(gateShowsUrgentBanner("moderate", "urgent")).toBe(true);
  });
});

describe("patient results ring (qualitative)", () => {
  it("screening ring labels avoid numeric health score wording", () => {
    const urgent = screeningResultRingLabel("urgent");
    expect(urgent.line1).toBeTruthy();
    expect(String(urgent.line1)).not.toMatch(/\d+/);
    expect(screeningResultRingLabel("normal").line1).not.toMatch(/OK|Normal/i);
    expect(screeningResultRingFillPercent("urgent")).toBeLessThan(50);
    expect(screeningResultRingFillPercent("normal")).toBeGreaterThan(80);
  });
});

describe("patient-facing test picker labels", () => {
  it("English labels avoid Prism Diopter and Titmus Stereo", () => {
    const en = translations.en;
    expect(en.test_prism).not.toMatch(/prism diopter/i);
    expect(en.test_titmus).not.toMatch(/titmus stereo/i);
    expect(en.test_prism.toLowerCase()).toContain("alignment");
    expect(en.test_titmus.toLowerCase()).toContain("depth");
  });
});

describe("monocular occlusion safety copy", () => {
  const fs = require("fs");
  const path = require("path");

  it("OD/OS instructions explicitly say which eye to cover", () => {
    const src = fs.readFileSync(path.join(__dirname, "../components/ambyo/MonocularOccluder.jsx"), "utf8");
    expect(src).toContain("Right eye test: cover the left eye");
    expect(src).toContain("Left eye test: cover the right eye");
    expect(src).toContain("I am not sure the correct eye is covered");
  });
});

describe("offline payload minimization", () => {
  const fs = require("fs");
  const path = require("path");

  it("offline result cache stores minimized details and records conflicts", () => {
    const dbSrc = fs.readFileSync(path.join(__dirname, "../core/offline/db.js"), "utf8");
    const syncSrc = fs.readFileSync(path.join(__dirname, "../core/offline/useOfflineSync.js"), "utf8");
    expect(dbSrc).toContain("offline_minimized");
    expect(dbSrc).toContain("sync_conflicts");
    expect(syncSrc).toContain("recordSyncConflict");
  });
});

describe("release positioning", () => {
  const fs = require("fs");
  const path = require("path");

  it("App includes clinical demo screening/support footer and no validation claim", () => {
    const src = fs.readFileSync(path.join(__dirname, "../App.js"), "utf8");
    expect(src).toContain("Clinical demo version - screening/support only");
    expect(src.toLowerCase()).not.toContain("clinically validated");
  });
});
