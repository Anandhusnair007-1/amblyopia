import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { api } from "@/core/auth/AuthStore";
import { toast } from "sonner";
import ScoreRing from "@/components/ambyo/ScoreRing";
import RiskBadge from "@/components/ambyo/RiskBadge";
import UrgentBanner from "@/components/ambyo/UrgentBanner";
import PageHeader from "@/components/shell/PageHeader";
import DashboardCard from "@/components/shell/DashboardCard";
import { generateReport, generateReferralLetter } from "@/reports/PDFGenerator";
import MedicalDisclaimer from "@/components/MedicalDisclaimer";
import { ArrowLeft, FileDown, Mail, Save, ChevronDown, ChevronUp, Activity, Microscope, Info } from "lucide-react";
import { motion } from "framer-motion";
import PatientContextBar from "@/components/clinical/PatientContextBar";
import AuditActionNotice from "@/components/clinical/AuditActionNotice";
import { maskPhone } from "@/lib/maskPhone";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";

const SEV_STYLE = {
  normal: "bg-emerald-50 text-emerald-800 border-emerald-200",
  mild: "bg-amber-50 text-amber-900 border-amber-200",
  moderate: "bg-orange-50 text-orange-900 border-orange-200",
  high: "bg-orange-50 text-orange-950 border-orange-300",
  urgent: "bg-red-50 text-red-800 border-red-300 animate-pulse",
};

const TESTS = {
  visual_acuity: "Visual Acuity",
  gaze: "Gaze stability screening",
  hirschberg: "Hirschberg alignment estimate",
  prism: "Alignment screening proxy",
  titmus: "Depth screening",
  red_reflex: "Red Reflex",
  heidelberg: "Heidelberg (Proxy)",
};

function followUpDateIsPast(value) {
  if (!value) return false;
  const selected = new Date(`${value}T00:00:00`);
  if (Number.isNaN(selected.getTime())) return true;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return selected < today;
}

const STRABISMUS_SCORE_ORDER = ["Normal", "XT", "ET", "HT"];

function AIStrabismusDoctorCard({ strabismus_ai: sa }) {
  const confidence = typeof sa.confidence === "number" && Number.isFinite(sa.confidence)
    ? Math.min(1, Math.max(0, sa.confidence))
    : null;
  const scores = sa.all_scores && typeof sa.all_scores === "object" ? sa.all_scores : {};
  const condition = sa.condition ?? "—";
  const aiRisk = sa.risk || "normal";

  return (
    <div
      data-testid="doctor-strabismus-ai-card"
      className="overflow-hidden rounded-2xl border border-border bg-card shadow-sm"
    >
      <div className="border-b border-border bg-muted/40 px-5 py-4">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="flex items-center gap-3">
            <span className="text-2xl leading-none" aria-hidden>
              🤖
            </span>
            <div>
              <h3 className="text-base font-bold tracking-tight text-[#0A2540]">AI Strabismus Screening</h3>
              <p className="mt-0.5 font-mono text-[11px] text-muted-foreground">
                Model: {sa.model_version || "—"}
              </p>
            </div>
          </div>
        </div>
      </div>

      <div className="space-y-5 px-5 py-5">
        <div className="flex flex-wrap items-center gap-3">
          <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Condition:</span>
          <span className="inline-flex items-center rounded-md border border-teal-200 bg-teal-50 px-3 py-1 text-sm font-bold text-teal-900">
            {condition}
          </span>
        </div>

        {confidence !== null && (
          <div>
            <div className="flex items-center justify-between text-xs font-medium text-muted-foreground">
              <span>Confidence</span>
              <span className="font-mono text-teal-800">{(confidence * 100).toFixed(0)}%</span>
            </div>
            <div className="mt-2 h-2.5 w-full overflow-hidden rounded-full bg-muted">
              <div
                className="h-full rounded-full bg-teal-600 transition-[width]"
                style={{ width: `${confidence * 100}%` }}
              />
            </div>
          </div>
        )}

        <div className="flex flex-wrap items-center gap-3">
          <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">AI Risk:</span>
          <RiskBadge level={aiRisk} />
        </div>

        {sa.recommendation && (
          <p className="text-sm leading-relaxed text-foreground/90 border-t border-border pt-4">
            {sa.recommendation}
          </p>
        )}

        <div className="border-t border-border pt-4">
          <p className="text-xs font-bold uppercase tracking-widest text-muted-foreground">All Class Scores</p>
          <div className="mt-3 space-y-3">
            {STRABISMUS_SCORE_ORDER.map((label) => {
              const raw = scores[label];
              const val = typeof raw === "number" && Number.isFinite(raw) ? Math.min(1, Math.max(0, raw)) : 0;
              const pct = Math.round(val * 100);
              const isPredicted = condition !== "—" && label === condition;
              return (
                <div
                  key={label}
                  className={`rounded-lg px-3 py-2 ${
                    isPredicted ? "bg-teal-50 ring-2 ring-teal-500/60" : "bg-muted/30"
                  }`}
                >
                  <div className="flex items-center justify-between gap-3 text-sm">
                    <span className={`font-mono font-semibold ${isPredicted ? "text-teal-900" : "text-foreground"}`}>
                      {label}
                    </span>
                    <span className="font-mono text-xs text-muted-foreground">{pct}%</span>
                  </div>
                  <div className="mt-2 h-2 w-full overflow-hidden rounded-full bg-white/80 dark:bg-background">
                    <div
                      className={`h-full rounded-full ${isPredicted ? "bg-teal-600" : "bg-slate-400/70"}`}
                      style={{ width: `${pct}%` }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}

function ResultCard({ name, result }) {
  const [open, setOpen] = useState(false);
  const base = "border border-input bg-background text-foreground rounded-xl p-4";
  if (!result) {
    return (
      <div className={base}>
        <div className="text-xs uppercase tracking-widest text-muted-foreground font-bold">{TESTS[name] || name}</div>
        <div className="mt-2 text-sm text-muted-foreground">Not performed</div>
      </div>
    );
  }
  const details = result.details || {};
  const skipped = details.skipped;
  return (
    <div className={base}>
      <div className="flex items-center justify-between">
        <div className="text-xs uppercase tracking-widest text-muted-foreground font-bold">{TESTS[name] || name}</div>
        {skipped && <span className="text-xs text-amber-700 font-semibold">SKIPPED</span>}
      </div>
      <div className="mt-2 grid grid-cols-2 gap-2 text-sm">
        <div><span className="text-muted-foreground">Raw:</span> <span className="font-mono font-medium">{Number(result.raw_score).toFixed(2)}</span></div>
        <div><span className="text-muted-foreground">Norm:</span> <span className="font-mono font-medium">{Number(result.normalized_score).toFixed(3)}</span></div>
      </div>
      <button type="button" onClick={() => setOpen(!open)} className="mt-3 inline-flex items-center gap-1 text-xs text-teal-700 hover:text-teal-800 font-medium">
        {open ? <ChevronUp size={12} /> : <ChevronDown size={12} />} {open ? "Hide" : "Show"} raw details
      </button>
      {open && (
        <pre className="mt-2 text-[11px] text-foreground/80 bg-muted/50 border border-border rounded-md p-2 overflow-x-auto font-mono">
{JSON.stringify(details, null, 2)}
        </pre>
      )}
    </div>
  );
}

export default function DoctorReport() {
  const nav = useNavigate();
  const { sessionId } = useParams();
  const [data, setData] = useState(null);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    diagnosis: "",
    treatment: "",
    risk_label: "",
    follow_up_date: "",
    referred_to: "",
    override_reason: "",
  });
  const [wrongPatientOpen, setWrongPatientOpen] = useState(false);
  const [patientVerified, setPatientVerified] = useState(false);
  const [exportConfirm, setExportConfirm] = useState(null);

  const load = async () => {
    const r = await api.get(`/sessions/${sessionId}`);
    setData(r.data);
    if (r.data.diagnosis) {
      setForm({
        diagnosis: r.data.diagnosis.diagnosis || "",
        treatment: r.data.diagnosis.treatment || "",
        risk_label: r.data.diagnosis.risk_label || "",
        follow_up_date: r.data.diagnosis.follow_up_date || "",
        referred_to: r.data.diagnosis.referred_to || "",
        override_reason: r.data.diagnosis.override_reason || "",
      });
    }
  };
  useEffect(() => {
    setPatientVerified(false);
    load().catch(() => toast.error("Could not load session"));
    /* eslint-disable-next-line */
  }, [sessionId]);

  if (!data) {
    return (
      <div className="flex min-h-[40vh] items-center justify-center text-muted-foreground" data-testid="doctor-report">
        Loading…
      </div>
    );
  }
  const {
    patient,
    session,
    results = [],
    result_history = [],
    prediction = {},
    strabismus_ai: strabismusFromPayload,
  } = data;
  const strabismus_ai = strabismusFromPayload ?? session?.strabismus_ai ?? null;
  const risk = prediction.risk_level || "normal";
  const urgent = risk === "urgent";
  const medical = prediction.medical_findings || [];

  const saveDiagnosis = async (opts = { skipPatientVerify: false }) => {
    const diagnosis = form.diagnosis.trim();
    if (diagnosis.length < 5) return toast.error("Diagnosis must be at least 5 characters");
    if (followUpDateIsPast(form.follow_up_date)) return toast.error("Follow-up date cannot be in the past");
    if (!opts.skipPatientVerify && !data?.diagnosis && !patientVerified) {
      setWrongPatientOpen(true);
      return;
    }
    setSaving(true);
    try {
      await api.post("/doctor/diagnoses", {
        session_id: sessionId,
        ...form,
        diagnosis,
        confirmed_by_doctor: true,
        ai_agreement: "not_reviewed",
      });
      toast.success("Diagnosis saved");
      load();
    } catch (e) {
      toast.error(e?.response?.data?.detail || "Failed");
    } finally {
      setSaving(false);
    }
  };

  const recordExportAudit = (exportType) => {
    api.post(`/sessions/${sessionId}/export-audit`, { export_type: exportType }).catch(() => {});
  };

  const downloadPdf = () => {
    recordExportAudit("medical_pdf");
    const d = generateReport({ patient, session, results, prediction, strabismus_ai });
    d.save(`AmbyoAI-Medical-${patient?.name?.replace(/\s+/g, "_")}.pdf`);
    toast.success("Medical PDF exported");
  };
  const downloadReferral = () => {
    recordExportAudit("referral_letter");
    const d = generateReferralLetter({ patient, prediction });
    d.save(`Referral-${patient?.name?.replace(/\s+/g, "_")}.pdf`);
    toast.success("Referral exported");
  };

  const confirmExport = (type) => {
    setExportConfirm(type);
  };

  const runConfirmedExport = () => {
    const type = exportConfirm;
    setExportConfirm(null);
    if (type === "referral") downloadReferral();
    else downloadPdf();
  };

  const sessionEyebrow = `Session #${session?.id?.slice(0, 8)} · ${session?.created_at ? new Date(session.created_at).toLocaleString() : "—"}`;

  const fieldCls =
    "mt-2 w-full rounded-xl border border-input bg-background px-3 py-3 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-teal-600/20 focus:border-teal-600 transition-colors";

  return (
    <div className="page-enter space-y-8" data-testid="doctor-report">
      <PageHeader
        eyebrow={sessionEyebrow}
        title={patient?.name || "Patient"}
        actions={
          <>
            <button
              type="button"
              onClick={() => nav(-1)}
              data-testid="back-btn"
              className="inline-flex items-center gap-1.5 rounded-xl border border-input bg-background px-3 py-2 text-sm font-medium text-foreground shadow-sm hover:bg-muted/50"
            >
              <ArrowLeft size={16} /> Back
            </button>
            <button
              type="button"
              data-testid="download-pdf"
              onClick={() => confirmExport("pdf")}
              className="inline-flex items-center gap-1.5 rounded-xl bg-teal-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-teal-700"
            >
              <FileDown size={14} /> Medical PDF
            </button>
            {urgent && (
              <button
                type="button"
                data-testid="download-referral"
                onClick={() => confirmExport("referral")}
                className="inline-flex items-center gap-1.5 rounded-xl bg-red-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-red-700"
              >
                <Mail size={14} /> Referral
              </button>
            )}
          </>
        }
      />
      <div className="px-1">
        <AuditActionNotice />
      </div>

      <MedicalDisclaimer />
      <PatientContextBar patient={patient} session={session} prediction={prediction} consentSummary="On file" />
      {urgent && <UrgentBanner findings={prediction.findings || []} />}

      {session?.screening_history && Object.keys(session.screening_history).length > 0 && (
        <section data-testid="screening-history">
          <DashboardCard className="p-5">
            <h2 className="text-lg font-bold tracking-tight text-[#0A2540]">Screening history (patient-reported)</h2>
            <ul className="mt-3 grid gap-2 sm:grid-cols-2 text-sm">
              {Object.entries(session.screening_history).map(([key, val]) => (
                <li key={key} className="flex justify-between gap-2 rounded-lg border border-border bg-muted/30 px-3 py-2">
                  <span className="text-muted-foreground">{key.replace(/_/g, " ")}</span>
                  <span className="font-semibold text-foreground">{val ? "Yes" : "No"}</span>
                </li>
              ))}
            </ul>
          </DashboardCard>
        </section>
      )}

      <Dialog open={wrongPatientOpen} onOpenChange={setWrongPatientOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Confirm correct patient</DialogTitle>
          </DialogHeader>
          <p className="text-sm text-muted-foreground">
            Before the first save, confirm this record matches the child in front of you:{" "}
            <span className="font-semibold text-foreground">{patient?.name}</span> · DOB{" "}
            {patient?.date_of_birth}.
          </p>
          <DialogFooter className="gap-2 sm:justify-end">
            <Button type="button" variant="outline" onClick={() => setWrongPatientOpen(false)}>
              Cancel
            </Button>
            <Button
              type="button"
              onClick={() => {
                setPatientVerified(true);
                setWrongPatientOpen(false);
                saveDiagnosis({ skipPatientVerify: true });
              }}
            >
              Correct patient — continue save
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={!!exportConfirm} onOpenChange={(open) => !open && setExportConfirm(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Export patient report?</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 text-sm text-muted-foreground">
            <p>
              This export contains identifiable patient information and clinical screening data.
              Confirm this is the correct patient before continuing.
            </p>
            <div className="rounded-xl border border-amber-200 bg-amber-50 p-3 text-amber-900">
              <AuditActionNotice className="text-amber-900" />
            </div>
            <p className="font-medium text-foreground">
              {patient?.name} · DOB {patient?.date_of_birth} · Phone {maskPhone(patient?.phone)}
            </p>
          </div>
          <DialogFooter className="gap-2 sm:justify-end">
            <Button type="button" variant="outline" onClick={() => setExportConfirm(null)}>
              Cancel
            </Button>
            <Button type="button" onClick={runConfirmedExport}>
              Continue export
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <motion.section
        initial={{ y: 8, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
      >
        <DashboardCard className="p-6 sm:p-8">
          <div className="grid items-center gap-8 md:grid-cols-[auto_1fr]">
            <ScoreRing score={prediction.health_score ?? 0} level={risk} size={180} stroke={14} />
            <div>
              <div className="flex flex-wrap items-center gap-3">
                <p className="text-xs font-bold uppercase tracking-widest text-teal-700">Clinical Risk</p>
                <RiskBadge level={risk} />
                <span className="font-mono text-xs text-muted-foreground">
                  score {prediction.risk_score} · rule {prediction.clinical_rule_version || "—"}
                </span>
              </div>
              <h2 className="mt-2 text-2xl font-bold tracking-tight text-[#0A2540] sm:text-3xl">
                Patient: {patient?.name}{" "}
                <span className="text-base font-normal text-muted-foreground">
                  ({patient?.age}y, {patient?.gender})
                </span>
              </h2>
              <p className="mt-2 text-sm text-muted-foreground">
                DOB {patient?.date_of_birth} · Phone {maskPhone(patient?.phone)}
                {patient?.guardian_name ? ` · Guardian ${patient.guardian_name}` : ""}
              </p>
              <div className="mt-4 grid gap-3 sm:grid-cols-3">
                {[
                  ["Session started", session?.created_at ? new Date(session.created_at).toLocaleString() : "—"],
                  ["Completed", session?.completed_at ? new Date(session.completed_at).toLocaleString() : "—"],
                  ["Health score", `${prediction.health_score} / 100`],
                ].map(([k, v]) => (
                  <div key={k} className="rounded-lg border border-border bg-muted/30 px-3 py-2 text-xs">
                    <div className="uppercase tracking-wider text-muted-foreground">{k}</div>
                    <div className="mt-0.5 font-mono font-medium text-foreground">{v}</div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </DashboardCard>
      </motion.section>

      <section>
        <div className="mb-3 flex items-center gap-2">
          <Microscope size={16} className="text-teal-700" />
          <h2 className="text-lg font-bold tracking-tight text-[#0A2540]">Medical Findings</h2>
        </div>
        <div className="grid gap-4 md:grid-cols-2">
          {medical.length === 0 ? (
            <DashboardCard className="p-5 md:col-span-2">
              <p className="text-sm text-muted-foreground">
                No major screening concern was flagged in the completed measurements. Confirm clinically before reassurance.
              </p>
            </DashboardCard>
          ) : (
            medical.map((f, i) => (
              <motion.div
                key={i}
                data-testid={`medical-finding-${i}`}
                initial={{ y: 6, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                transition={{ delay: i * 0.05 }}
              >
                <DashboardCard className="p-5">
                  <div className="flex items-center justify-between gap-3">
                    <div>
                      <div className="text-xs font-bold uppercase tracking-widest text-muted-foreground">{f.test}</div>
                      <div className="mt-1 font-mono text-2xl font-bold text-[#0A2540]">{f.value}</div>
                    </div>
                    <span className={`inline-flex rounded-md border px-2.5 py-1 text-xs font-bold uppercase tracking-wider ${SEV_STYLE[f.severity] || SEV_STYLE.normal}`}>
                      {f.severity}
                    </span>
                  </div>
                  <div className="mt-3 text-xs text-muted-foreground">
                    <span className="uppercase tracking-wider">Threshold:</span>{" "}
                    <span className="font-mono text-foreground">{f.threshold}</span>
                  </div>
                  <p className="mt-2 text-sm leading-relaxed text-foreground">{f.interpretation}</p>
                </DashboardCard>
              </motion.div>
            ))
          )}
        </div>
      </section>

      <section data-testid="ai-deviation-insights">
        <DashboardCard className="border border-amber-200/80 bg-amber-50/30 p-6">
          <div className="mb-2 flex items-center gap-2">
            <Info size={16} className="text-amber-700" />
            <h2 className="text-lg font-bold tracking-tight text-[#0A2540]">AI-assisted camera screening (doctor-only)</h2>
          </div>
          <p className="mb-4 text-xs text-muted-foreground">
            Supplementary AI screening outputs only. Not a diagnosis. Confirm clinically.
          </p>

          {strabismus_ai ? (
            <AIStrabismusDoctorCard strabismus_ai={strabismus_ai} />
          ) : (
            <p className="text-sm text-muted-foreground" data-testid="doctor-strabismus-unavailable">
              AI strabismus analysis not available for this session.
            </p>
          )}
        </DashboardCard>
      </section>

      <section>
        <div className="mb-3 flex items-center gap-2">
          <Activity size={16} className="text-teal-700" />
          <h2 className="text-lg font-bold tracking-tight text-[#0A2540]">Test-by-test raw data</h2>
        </div>
        <div className="grid gap-4 md:grid-cols-3">
          {Object.keys(TESTS).map((k) => (
            <ResultCard key={k} name={k} result={results.find((r) => r.test_name === k)} />
          ))}
        </div>
      </section>

      <section>
        <div className="mb-3 flex items-center gap-2">
          <Activity size={16} className="text-teal-700" />
          <h2 className="text-lg font-bold tracking-tight text-[#0A2540]">Result revision history</h2>
        </div>
        <DashboardCard className="p-5">
          {result_history.length === 0 ? (
            <p className="text-sm text-muted-foreground">No previous attempts recorded for this session.</p>
          ) : (
            <div className="space-y-3">
              {result_history.slice(0, 12).map((r) => (
                <div key={r.id} className="rounded-xl border border-border bg-muted/30 p-3 text-sm">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <span className="font-mono font-semibold text-[#0A2540]">
                      {r.test_name} · rev {r.revision || 1} · {r.result_state || r.details?.test_status || "completed"}
                    </span>
                    <span className="text-xs text-muted-foreground">{r.created_at ? new Date(r.created_at).toLocaleString() : "—"}</span>
                  </div>
                  <div className="mt-2 grid gap-2 text-xs text-muted-foreground sm:grid-cols-3">
                    <span>Age at test: {r.age_at_test ?? "—"}</span>
                    <span>Rule: {r.rule_version || "—"}</span>
                    <span>Calibrated: {r.calibration_info?.px_per_mm ? "yes" : "no"}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </DashboardCard>
      </section>

      <DashboardCard className="p-6 sm:p-8">
        <h2 className="text-lg font-bold tracking-tight text-[#0A2540]">Doctor&apos;s Review & Diagnosis</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          Your notes will be saved to the medical record and appear on the final PDF report.
        </p>

        <div className="mt-5 space-y-4">
          <div>
            <label className="text-xs font-semibold uppercase tracking-widest text-muted-foreground">Diagnosis *</label>
            <textarea
              data-testid="diagnosis-input"
              value={form.diagnosis}
              onChange={(e) => setForm({ ...form, diagnosis: e.target.value })}
              rows={3}
              placeholder="E.g. Right-eye amblyopia with mild esotropia. Rule out refractive amblyopia."
              className={`${fieldCls} resize-none`}
            />
          </div>
          <div>
            <label className="text-xs font-semibold uppercase tracking-widest text-muted-foreground">Treatment plan</label>
            <textarea
              data-testid="treatment-input"
              value={form.treatment}
              onChange={(e) => setForm({ ...form, treatment: e.target.value })}
              rows={3}
              placeholder="Clinician plan only. Example: glasses/refraction review, patching only if prescribed, follow-up timing."
              className={`${fieldCls} resize-none`}
            />
            <p className="mt-1 text-xs text-amber-700">
              Use patching only as prescribed by an eye-care professional. The app must not generate patching dose automatically.
            </p>
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <div>
              <label className="text-xs font-semibold uppercase tracking-widest text-muted-foreground">Clinical label</label>
              <input
                data-testid="risk-label-input"
                value={form.risk_label}
                onChange={(e) => setForm({ ...form, risk_label: e.target.value })}
                placeholder="e.g. Anisometropic amblyopia"
                className={fieldCls}
              />
            </div>
            <div>
              <label className="text-xs font-semibold uppercase tracking-widest text-muted-foreground">Follow-up</label>
              <input
                type="date"
                data-testid="followup-input"
                value={form.follow_up_date}
                onChange={(e) => setForm({ ...form, follow_up_date: e.target.value })}
                className={fieldCls}
              />
            </div>
            <div>
              <label className="text-xs font-semibold uppercase tracking-widest text-muted-foreground">Referred to</label>
              <select
                data-testid="referred-input"
                value={form.referred_to}
                onChange={(e) => setForm({ ...form, referred_to: e.target.value })}
                className={fieldCls}
              >
                <option value="">—</option>
                <option>Aravind Coimbatore</option>
                <option>Aravind Madurai</option>
                <option>Aravind Chennai</option>
                <option>Aravind Tirunelveli</option>
                <option>Aravind Pondicherry</option>
              </select>
            </div>
          </div>
          <div className="rounded-xl border border-teal-200 bg-teal-50/40 p-4">
            <div className="mb-2 flex items-center gap-2">
              <Info size={14} className="text-teal-700" />
              <label className="text-xs font-bold uppercase tracking-widest text-teal-800">Clinician Override Reason</label>
            </div>
            <textarea
              data-testid="override-input"
              value={form.override_reason || ""}
              onChange={(e) => setForm({ ...form, override_reason: e.target.value })}
              placeholder="Required if your diagnosis differs significantly from the AI risk score."
              className="h-16 w-full resize-none border-0 bg-transparent p-0 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-0"
            />
          </div>
        </div>

        <div className="mt-4">
          <AuditActionNotice />
        </div>
        <div className="mt-6 flex items-center justify-end">
          <button
            type="button"
            data-testid="save-diagnosis"
            onClick={() => saveDiagnosis()}
            disabled={saving}
            className="inline-flex items-center gap-2 rounded-xl bg-teal-600 px-5 py-2.5 font-bold text-white shadow-md transition-all hover:bg-teal-700 disabled:opacity-60"
          >
            <Save size={16} /> {saving ? "Saving…" : "Save diagnosis"}
          </button>
        </div>

        {data.diagnosis && (
          <div className="mt-5 font-mono text-xs text-muted-foreground">
            Last saved {new Date(data.diagnosis.created_at).toLocaleString()} by {data.diagnosis.doctor_name || "Doctor"}
          </div>
        )}
      </DashboardCard>
    </div>
  );
}
