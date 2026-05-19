import jsPDF from "jspdf";
import {
  PDF_GENERIC_HOSPITAL_LABEL,
  patientPdfDetailEntries,
  patientStrabismusPdfLines,
  pdfReportTitle,
  resolveReportHospital,
} from "@/lib/referralCopy";

export {
  PDF_GENERIC_HOSPITAL_LABEL,
  PATIENT_PDF_REPORT_TITLE,
  patientPdfDetailEntries,
  patientStrabismusPdfLines,
  pdfReportTitle,
  reportTextContainsAravind,
  resolveReportHospital,
} from "@/lib/referralCopy";

// Minimal 6-page PDF report (no external fonts; uses jsPDF defaults)
export function generateReport({
  patient,
  session,
  results,
  prediction,
  hospital,
  strabismus_ai = null,
  patientFacing = false,
}) {
  const hospitalLabel =
    hospital != null && String(hospital).trim()
      ? String(hospital).trim()
      : resolveReportHospital(patient, session);
  const doc = new jsPDF({ unit: "pt", format: "a4" });
  const W = doc.internal.pageSize.getWidth();
  const M = 48;
  let y = 0;

  const header = (title, subtitle) => {
    doc.setFillColor(10, 37, 64); // #0A2540
    doc.rect(0, 0, W, 80, "F");
    doc.setTextColor(255, 255, 255);
    doc.setFont("helvetica", "bold"); doc.setFontSize(22);
    doc.text("AmbyoAI", M, 38);
    doc.setFontSize(10); doc.setFont("helvetica", "normal");
    doc.text(hospitalLabel, M, 58);
    if (title) {
      doc.setFontSize(9); doc.setTextColor(200, 220, 240);
      doc.text(title.toUpperCase(), W - M, 38, { align: "right" });
      if (subtitle) doc.text(subtitle, W - M, 58, { align: "right" });
    }
    doc.setTextColor(0, 0, 0);
    y = 110;
  };

  const h2 = (txt) => {
    doc.setFont("helvetica", "bold"); doc.setFontSize(16); doc.setTextColor(10, 37, 64);
    doc.text(txt, M, y); y += 24;
    doc.setDrawColor(220, 228, 239); doc.line(M, y - 8, W - M, y - 8);
  };

  const kv = (k, v) => {
    doc.setFont("helvetica", "bold"); doc.setFontSize(10); doc.setTextColor(100, 116, 139);
    doc.text(String(k).toUpperCase(), M, y);
    doc.setFont("helvetica", "normal"); doc.setFontSize(12); doc.setTextColor(15, 23, 42);
    doc.text(String(v ?? "—"), M + 160, y);
    y += 22;
  };

  const para = (txt) => {
    doc.setFont("helvetica", "normal"); doc.setFontSize(11); doc.setTextColor(51, 65, 85);
    const lines = doc.splitTextToSize(txt, W - 2 * M);
    doc.text(lines, M, y);
    y += lines.length * 14 + 6;
  };

  // Page 1 — Cover
  header(pdfReportTitle(patientFacing), `Session ${session?.id?.slice(0, 8) || ""}`);
  h2("Patient");
  kv("Name", patient?.name);
  kv("Age", patient?.age);
  kv("Gender", patient?.gender);
  kv("Date of Birth", patient?.date_of_birth);
  kv("Guardian", patient?.guardian_name || "—");
  y += 10;
  h2("Session");
  kv("Session ID", session?.id);
  kv("Created", session?.created_at);
  kv("Completed", session?.completed_at || "—");
  kv("Status", session?.status);
  kv("Hospital", hospitalLabel);

  // Page 2 — Summary
  doc.addPage(); header(patientFacing ? "Screening Summary" : "Summary & AI Risk");
  const risk = prediction?.risk_level || "normal";
  const riskLabel =
    risk === "urgent"
      ? "Prompt follow-up recommended"
      : risk === "moderate"
        ? "Eye-care visit recommended"
        : risk === "mild"
          ? "Routine follow-up suggested"
          : risk === "incomplete"
            ? "Screening incomplete"
            : "No major screening concern on this pass";
  if (patientFacing) {
    h2("Screening result");
    doc.setFont("helvetica", "bold"); doc.setFontSize(14); doc.setTextColor(10, 37, 64);
    doc.text(riskLabel, M, y);
    y += 28;
    para(
      "This app provides screening and support only. It does not diagnose lazy eye, prescribe glasses, determine patching treatment, or replace an eye doctor. If screening is abnormal, incomplete, or if a child has eye turning, white pupil, poor vision, eye pain, trauma, or parent concern, consult a pediatric ophthalmologist or qualified eye-care professional."
    );
    y += 6;
  } else {
    h2("Overall Health");
    const score = prediction?.health_score ?? 0;
    doc.setFont("helvetica", "bold"); doc.setFontSize(44);
    const color = risk === "urgent" ? [239, 68, 68] : risk === "moderate" ? [249, 115, 22] : risk === "mild" ? [245, 158, 11] : [16, 185, 129];
    doc.setTextColor(...color);
    doc.text(`${score}`, M, y + 40);
    doc.setFontSize(12); doc.setTextColor(71, 85, 105);
    doc.text("/ 100 Health Score", M + 110, y + 40);
    y += 80;
    kv("Risk Level", risk.toUpperCase());
    kv("Risk Score", (prediction?.risk_score ?? 0).toFixed(3));
    kv("Model", prediction?.model_version || "clinical-fallback-v1");
    y += 10;
  }
  h2(patientFacing ? "Screening Findings" : "Clinical Findings");
  (prediction?.findings || []).forEach((f) => para("• " + f));

  const aiLines = patientStrabismusPdfLines(strabismus_ai, { patientFacing });
  if (aiLines.length > 0) {
    y += 14;
    h2(patientFacing ? "AI Screening Review" : "AI Eye Analysis");
    aiLines.forEach((line) => para(line));
    if (!patientFacing && typeof strabismus_ai?.confidence === "number") {
      kv("Confidence", `${(strabismus_ai.confidence * 100).toFixed(0)}%`);
    }
    if (!patientFacing && strabismus_ai?.all_scores && typeof strabismus_ai.all_scores === "object") {
      kv(
        "Class scores",
        Object.entries(strabismus_ai.all_scores)
          .map(([k, v]) => `${k}: ${Number(v).toFixed(2)}`)
          .join(", ")
      );
    }
  }

  // Page 3-5 — Per-test details
  const byName = Object.fromEntries((results || []).map((r) => [r.test_name, r]));
  const TESTS = patientFacing
    ? [
        ["visual_acuity", "Visual acuity (screening)"],
        ["gaze", "Gaze stability screening"],
        ["hirschberg", "Hirschberg alignment estimate"],
        ["prism", "Alignment screening proxy"],
        ["titmus", "Depth screening"],
        ["red_reflex", "Red reflex"],
      ]
    : [
        ["visual_acuity", "Visual Acuity"],
        ["gaze", "Gaze stability screening"],
        ["hirschberg", "Hirschberg alignment estimate"],
        ["prism", "Alignment screening proxy"],
        ["titmus", "Depth screening"],
        ["red_reflex", "Red Reflex"],
      ];
  TESTS.forEach(([key, label], i) => {
    if (i % 2 === 0) { doc.addPage(); header(`Test Detail ${i + 1}`); }
    h2(label);
    const r = byName[key];
    if (!r) { para("Not performed."); return; }
    const details = r.details || {};
    if (patientFacing) {
      const rows = patientPdfDetailEntries(details);
      if (rows.length === 0) {
        para("Screening recorded — confirm details with an eye-care professional.");
      } else {
        rows.forEach(([k, txt]) => kv(k, txt));
      }
    } else {
      kv("Raw Score", r.raw_score);
      kv("Normalized", r.normalized_score);
      Object.entries(details).slice(0, 8).forEach(([k, v]) => {
        const txt = typeof v === "object" ? JSON.stringify(v).slice(0, 100) : String(v);
        kv(k, txt);
      });
    }
    y += 10;
  });

  // Last page — Doctor diagnosis slot
  doc.addPage(); header("Doctor's Review");
  h2("Diagnosis");
  para("[                                                                                                  ]");
  para("[                                                                                                  ]");
  y += 10;
  h2("Treatment & Follow-up");
  para("[                                                                                                  ]");
  para("[                                                                                                  ]");
  y += 30;
  doc.setFont("helvetica", "normal"); doc.setFontSize(9); doc.setTextColor(148, 163, 184);
  doc.text("Reviewed by ____________________________     Date ____________", M, y);

  return doc;
}

export function generateReferralLetter({ patient, prediction, branch }) {
  const branchLabel =
    branch != null && String(branch).trim()
      ? String(branch).trim()
      : PDF_GENERIC_HOSPITAL_LABEL;
  const doc = new jsPDF({ unit: "pt", format: "a4" });
  const W = doc.internal.pageSize.getWidth();
  const M = 48;

  doc.setFillColor(239, 68, 68); doc.rect(0, 0, W, 80, "F");
  doc.setTextColor(255, 255, 255); doc.setFont("helvetica", "bold"); doc.setFontSize(22);
  doc.text("URGENT REFERRAL", M, 50);
  doc.setFontSize(10); doc.setTextColor(255, 220, 220); doc.text("AmbyoAI Pediatric Screening", W - M, 50, { align: "right" });

  let y = 130;
  doc.setTextColor(15, 23, 42); doc.setFont("helvetica", "normal"); doc.setFontSize(11);
  doc.text(`To: The Chief Ophthalmologist`, M, y); y += 16;
  doc.text(branchLabel, M, y); y += 30;

  doc.setFont("helvetica", "bold"); doc.text("Re: Pediatric Amblyopia Screening — URGENT", M, y); y += 24;
  doc.setFont("helvetica", "normal");
  doc.text(doc.splitTextToSize(
    `This is to refer ${patient?.name} (age ${patient?.age}, DOB ${patient?.date_of_birth}) for an urgent in-person ophthalmology review. An AmbyoAI screening session indicated findings that exceed clinical thresholds.`,
    W - 2 * M
  ), M, y);
  y += 60;

  doc.setFont("helvetica", "bold"); doc.text("Clinical findings:", M, y); y += 20;
  doc.setFont("helvetica", "normal");
  (prediction?.findings || []).forEach((f) => {
    const lines = doc.splitTextToSize("• " + f, W - 2 * M);
    doc.text(lines, M, y); y += lines.length * 14;
  });

  y += 30;
  doc.text(`Risk Level: ${String(prediction?.risk_level || "").toUpperCase()}`, M, y); y += 16;
  doc.text(`Health Score: ${prediction?.health_score ?? ""} / 100`, M, y); y += 16;
  doc.text(`Model: ${prediction?.model_version || "clinical-fallback-v1"}`, M, y); y += 40;

  doc.text("Kindly arrange an urgent examination at the earliest.", M, y); y += 30;
  doc.text("Regards,", M, y); y += 40;
  doc.text("AmbyoAI Screening Team", M, y);

  return doc;
}
