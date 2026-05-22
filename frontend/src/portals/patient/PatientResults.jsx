import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { api } from "@/core/auth/AuthStore";
import { generateReport } from "@/reports/PDFGenerator";
import { toast } from "sonner";
import { FileDown, Home, ArrowLeft, CheckCircle2, HeartPulse, CalendarCheck, Share2, Eye } from "lucide-react";
import MedicalDisclaimer from "@/components/MedicalDisclaimer";
import PageHeader from "@/components/shell/PageHeader";
import OfflineBadge from "@/components/ambyo/OfflineBadge";
import LanguageSwitcher from "@/components/ambyo/LanguageSwitcher";
import RiskBadge from "@/components/ambyo/RiskBadge";
import ScoreRing from "@/components/ambyo/ScoreRing";
import UrgentBanner from "@/components/ambyo/UrgentBanner";
import { motion } from "framer-motion";
import { Skeleton } from "@/components/ui/skeleton";
import { useI18n } from "@/core/i18n/translations";
import { resolveUrgentReferralNext } from "@/lib/referralCopy";

// Simple patient-facing copy (no medical jargon)
const FRIENDLY = {
  normal: {
    title: "All looks good!",
    tone: "text-emerald-700",
    bg: "from-emerald-50 to-white",
    message: "No concerning signs were detected in this screening. Keep an eye on your vision and screen again in 6–12 months.",
    next: "Next: routine screening in 6-12 months.",
  },
  mild: {
    title: "Mild note",
    tone: "text-amber-700",
    bg: "from-amber-50 to-white",
    message: "We noticed a small thing worth checking. It's not an emergency, but a routine eye exam is a good idea.",
    next: "Next: book a routine eye check-up when convenient.",
  },
  moderate: {
    title: "Please see a doctor",
    tone: "text-orange-700",
    bg: "from-orange-50 to-white",
    message: "Your screening shows patterns we recommend a doctor review. Please schedule an appointment within the next 2 weeks.",
    next: "Next: visit an ophthalmologist within 2 weeks.",
  },
  urgent: {
    title: "Please see a doctor soon",
    tone: "text-red-700",
    bg: "from-red-50 to-white",
    message:
      "The screening found signs that need prompt attention. Please consult an ophthalmologist or eye-care professional promptly. Show this report to your clinician.",
    next: null,
  },
  incomplete: {
    title: "Screening incomplete",
    tone: "text-slate-700",
    bg: "from-slate-50 to-white",
    message:
      "Some tests were skipped, could not be scored, or need to be repeated. This is not a normal result — please complete screening or see an eye-care professional.",
    next: "Next: repeat screening or book an in-person eye check.",
  },
};

const TEST_ORDER = ["visual_acuity", "gaze", "hirschberg", "prism", "titmus", "red_reflex", "heidelberg"];

const STRABISMUS_CARD_BORDER = {
  urgent: "border-l-[6px] border-l-red-500",
  moderate: "border-l-[6px] border-l-amber-500",
  mild: "border-l-[6px] border-l-yellow-400",
};

function nextTestIndex(results = []) {
  const done = new Set(results.map((r) => r.test_name));
  const idx = TEST_ORDER.findIndex((id) => !done.has(id));
  return idx >= 0 ? idx : 0;
}

export default function PatientResults() {
  const nav = useNavigate();
  const { sessionId } = useParams();
  const { t } = useI18n();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      try {
        const r = await api.get(`/sessions/${sessionId}`);
        const session = r.data.session || {};
        if (session.status !== "completed" || !r.data.prediction) {
          toast.message("This screening is not complete yet. Continue the next test.");
          nav(`/patient/session/${sessionId}/test/${nextTestIndex(r.data.results || [])}`, { replace: true });
          return;
        }
        setData(r.data);
      } catch { toast.error("Could not load results"); }
      finally { setLoading(false); }
    })();
  }, [nav, sessionId]);

  if (loading || !data) {
    return (
      <div className="min-h-screen bg-background page-enter" data-testid="patient-results-loading">
        <header className="sticky top-0 z-20 border-b border-border bg-card/95 backdrop-blur">
          <div className="mx-auto max-w-4xl px-4 py-4 sm:px-6 lg:px-8">
            <div className="flex items-end justify-between gap-4">
              <div className="min-w-0">
                <div className="text-xs uppercase tracking-widest text-teal-700 font-bold">Screening</div>
                <Skeleton className="mt-2 h-8 w-[220px]" />
              </div>
              <div className="flex items-center gap-2">
                <OfflineBadge /><LanguageSwitcher />
              </div>
            </div>
          </div>
        </header>
        <main className="mx-auto max-w-4xl space-y-6 px-4 py-8 sm:px-6 lg:px-8">
          <div className="grid items-center gap-8 overflow-hidden rounded-3xl border border-border bg-card p-6 shadow-sm sm:p-10 md:grid-cols-[auto_1fr]">
            <Skeleton className="h-[180px] w-[180px] rounded-full" />
            <div className="space-y-3">
              <Skeleton className="h-6 w-[240px]" />
              <Skeleton className="h-10 w-[320px]" />
              <Skeleton className="h-4 w-full max-w-[520px]" />
              <Skeleton className="h-4 w-full max-w-[460px]" />
              <Skeleton className="h-9 w-[260px] rounded-full" />
            </div>
          </div>
          <div className="space-y-3">
            <Skeleton className="h-4 w-[180px]" />
            <div className="grid gap-4 md:grid-cols-2">
              {Array.from({ length: 4 }).map((_, i) => (
                <div key={i} className="rounded-2xl border border-border bg-card p-5 shadow-sm space-y-3">
                  <Skeleton className="h-3 w-[160px]" />
                  <Skeleton className="h-8 w-[120px]" />
                  <Skeleton className="h-4 w-full" />
                  <Skeleton className="h-2 w-full rounded-full" />
                </div>
              ))}
            </div>
          </div>
        </main>
      </div>
    );
  }

  const {
    patient,
    session,
    results = [],
    prediction = {},
    ai_deviation_insights = [],
    strabismus_ai: strabismusFromPayload,
  } = data;
  const strabismus_ai = strabismusFromPayload ?? session?.strabismus_ai ?? null;
  const risk = prediction.risk_level || "normal";
  const baseCopy = FRIENDLY[risk] || FRIENDLY.normal;
  const copy = {
    ...baseCopy,
    next:
      risk === "urgent"
        ? resolveUrgentReferralNext(patient, session)
        : baseCopy.next,
  };
  const isHighRisk = risk === "urgent" || risk === "moderate";

  const byTest = (name) => results.find((r) => r.test_name === name);

  const testCards = [
    {
      key: "visual_acuity",
      name: "Visual acuity",
      value: (r) => {
        if (!r) return "—";
        const d = r.details || {};
        if (d.skipped || d.test_status === "skipped") return "Skipped";
        if (d.measurement_valid === false || d.test_status === "incomplete") return "Not available";
        const odL = d.od_label || d.od?.screening_line_label || d.od?.snellen_label;
        const osL = d.os_label || d.os?.screening_line_label || d.os?.snellen_label;
        if (odL && osL) return `OD ${odL} · OS ${osL}`;
        if (odL || osL) return [odL && `OD ${odL}`, osL && `OS ${osL}`].filter(Boolean).join(" · ");
        return d.snellen_label || `~6/${d.snellen_denominator || r.raw_score} screening`;
      },
      explain: () =>
        "Uncalibrated near-screen acuity estimate at ~40 cm — not equivalent to clinic Snellen or a full eye exam.",
    },
    {
      key: "gaze",
      name: "Gaze alignment (screening)",
      value: (r) => {
        if (!r) return "—";
        const status = r.details?.screening_status;
        if (status) return String(status).replace(/_/g, " ");
        return "Recorded";
      },
      explain: () => "Uncalibrated gaze-stability screening while following a dot — not a prism measurement.",
    },
    {
      key: "hirschberg",
      name: "Corneal reflex (screening)",
      value: (r) => {
        if (!r) return "—";
        const d = r.details || {};
        if (d.test_status === "incomplete" || d.measurement_valid === false) return "Not available";
        if (d.screening_status) return String(d.screening_status).replace(/_/g, " ");
        return "Recorded";
      },
      explain: () => "Screening proxy using corneal light reflex — confirm with an in-person exam.",
    },
    {
      key: "prism",
      name: "Alignment (screening proxy)",
      value: (r) => {
        if (!r) return "—";
        const d = r.details || {};
        if (d.test_status === "incomplete") return "Not available";
        return "Alignment proxy recorded";
      },
      explain: () =>
        "Alignment screening estimate only — occlusion is not verified on camera; not a clinical cover test.",
    },
    {
      key: "titmus",
      name: "Depth perception (screening)",
      value: (r) => {
        if (!r) return "—";
        const d = r.details || {};
        if (d.stereo_grade_label) return String(d.stereo_grade_label);
        if (d.stereo_grade) return String(d.stereo_grade).replace(/_/g, " ");
        if (d.passed != null && d.total != null) return `${d.passed}/${d.total}`;
        return "Recorded";
      },
      explain: () => "On-screen depth screening proxy — not a validated clinical stereo test.",
    },
    {
      key: "red_reflex",
      name: "Red reflex",
      value: (r) => (r ? String(r.details?.classification || "—").replace(/_/g, " ") : "—"),
      explain: () => "Looks for abnormal pupil reflection patterns that may need a doctor’s review.",
    },
    {
      key: "heidelberg",
      name: "Heidelberg (proxy)",
      value: (r) => (r ? String(r.details?.classification || "—").replace(/_/g, " ") : "—"),
      explain: () => "A proxy retina check using brightness patterns; not the same as an OCT scan.",
    },
  ];

  const clamp01 = (x) => Math.max(0, Math.min(1, x));
  const confidenceFor = (r) => {
    if (!r) return 0;
    const d = r.details || {};
    if (typeof d.confidence === "number") return clamp01(d.confidence);
    const n = Number(r.normalized_score);
    if (!Number.isFinite(n)) return 0.55;
    // Heuristic: lower normalized risk-ish score => higher confidence.
    return clamp01(0.45 + 0.55 * (1 - n));
  };

  const download = () => {
    const d = generateReport({
      patient,
      session,
      results,
      prediction,
      strabismus_ai,
      patientFacing: true,
    });
    api.post(`/sessions/${sessionId}/export-audit`, { export_type: "patient_pdf" }).catch(() => {});
    d.save(`AmbyoAI-${patient?.name?.replace(/\s+/g, "_") || "patient"}.pdf`);
    toast.success("Report downloaded");
  };

  const share = async () => {
    try {
      const d = generateReport({
        patient,
        session,
        results,
        prediction,
        strabismus_ai,
        patientFacing: true,
      });
      const filename = `AmbyoAI-${patient?.name?.replace(/\s+/g, "_") || "patient"}.pdf`;
      const file = new File([d.output("blob")], filename, { type: "application/pdf" });
      api.post(`/sessions/${sessionId}/export-audit`, { export_type: "patient_share_pdf" }).catch(() => {});
      if (navigator.canShare?.({ files: [file] })) {
        await navigator.share({
          title: "AmbyoAI screening report",
          text: "AmbyoAI pediatric eye-screening report",
          files: [file],
        });
        return;
      }
      d.save(filename);
      toast.message("Sharing is not available in this browser, so the report was downloaded.");
    } catch (e) {
      toast.error("Could not share report");
    }
  };

  return (
    <div className="min-h-screen bg-background page-enter" data-testid="patient-results">
      <header className="sticky top-0 z-20 border-b border-border bg-card/95 backdrop-blur">
        <div className="mx-auto max-w-4xl px-4 py-4 sm:px-6 lg:px-8">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
            <PageHeader
              eyebrow={session?.id ? `Session #${session.id.slice(0, 6)}` : "Screening"}
              title="Your screening"
              className="sm:flex-1"
              actions={
                <div className="flex flex-wrap items-center gap-2">
                  <button onClick={() => nav("/patient")} type="button" className="inline-flex items-center gap-1 rounded-xl border border-input bg-background px-3 py-2 text-sm shadow-sm hover:bg-muted/50">
                    <ArrowLeft size={16} /> Home
                  </button>
                  <OfflineBadge /><LanguageSwitcher />
                </div>
              }
            />
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-4xl space-y-6 px-4 py-8 sm:px-6 lg:px-8">
        <motion.section
          initial={{ y: 8, opacity: 0 }} animate={{ y: 0, opacity: 1 }}
          className={`relative grid items-center gap-8 overflow-hidden rounded-3xl border border-border bg-gradient-to-br ${copy.bg} p-6 shadow-sm sm:p-10 md:grid-cols-[auto_1fr]`}
        >
          <ScoreRing level={risk} size={180} stroke={14} qualitative />
          <div>
            <div className="flex items-center gap-3 flex-wrap">
              <p className="text-xs uppercase tracking-[0.3em] text-teal-700 font-bold">Result</p>
              <RiskBadge level={risk} className="scale-110 origin-left" />
            </div>
            <h1 className={`mt-2 text-3xl sm:text-4xl font-bold tracking-tight ${copy.tone}`}>
              {copy.title}
            </h1>
            <p className="mt-3 text-slate-700 leading-relaxed max-w-xl">{copy.message}</p>
            {(() => {
              const va = byTest("visual_acuity");
              const d = va?.details;
              const linesDiff = d?.inter_eye_lines_diff ?? 0;
              if (linesDiff >= 2 && d?.measurement_valid !== false) {
                const od = d.od_label || d.od?.snellen_label || "OD";
                const os = d.os_label || d.os?.snellen_label || "OS";
                return (
                  <p className="mt-3 text-sm text-amber-800 bg-amber-50 border border-amber-200 rounded-xl px-4 py-3 max-w-xl">
                    {t("va_inter_eye_note")}{" "}
                    {t("va_od_os_summary", { od, os })}
                    <span className="block mt-1 text-xs text-amber-900/80">
                      Screening estimate only — confirm with an eye-care professional.
                    </span>
                  </p>
                );
              }
              return null;
            })()}
            <div className="mt-4 inline-flex items-center gap-2 rounded-full border border-border bg-card px-3 py-1.5 text-sm font-semibold text-[#0A2540]">
              <CalendarCheck size={14} /> {copy.next}
            </div>
          </div>
        </motion.section>

        {strabismus_ai &&
          strabismus_ai.risk &&
          strabismus_ai.risk !== "normal" && (
            <motion.section
              initial={{ y: 6, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              data-testid="patient-strabismus-ai-card"
              className={`rounded-2xl border border-border bg-white shadow-sm ${STRABISMUS_CARD_BORDER.mild}`}
            >
              <div className="p-6 sm:p-7">
                <div className="flex items-center gap-3">
                  <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-teal-50 text-teal-700 ring-1 ring-teal-100">
                    <Eye className="h-6 w-6" aria-hidden />
                  </div>
                  <div>
                    <p className="text-[11px] font-bold uppercase tracking-[0.2em] text-muted-foreground">
                      AI screening review
                    </p>
                    <h2 className="text-xl font-bold tracking-tight text-[#0A2540]">Camera screening follow-up</h2>
                  </div>
                </div>

                <p className="mt-5 text-sm leading-relaxed text-slate-700">
                  {strabismus_ai.recommendation ||
                    "AI screening output suggests this should be reviewed by an eye-care professional."}
                </p>

<p className="mt-4 text-[11px] leading-relaxed text-muted-foreground">
                  AI-assisted screening. Not a medical diagnosis.
                </p>
              </div>
            </motion.section>
          )}

        {isHighRisk && (
          <UrgentBanner findings={prediction.findings || ["Please visit a doctor soon."]} />
        )}

        {/* Per-test results (patient-friendly) */}
        <section className="space-y-3">
          <div className="flex items-center justify-between">
            <div className="text-xs font-bold uppercase tracking-widest text-muted-foreground">Per-test results</div>
            <div className="text-xs text-muted-foreground font-mono">{results.length} result{results.length !== 1 ? "s" : ""}</div>
          </div>
          <div className="grid gap-4 md:grid-cols-2">
            {testCards.map((t) => {
              const r = byTest(t.key);
              const skipped = r?.details?.skipped;
              const conf = confidenceFor(r);
              const confPct = Math.round(conf * 100);
              return (
                <div key={t.key} className="rounded-2xl border border-border bg-card p-5 shadow-sm">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="text-[11px] font-bold uppercase tracking-widest text-muted-foreground">{t.name}</div>
                      <div className="mt-2 text-2xl font-extrabold tracking-tight text-[#0A2540]">
                        {skipped ? "Skipped" : t.value(r)}
                      </div>
                    </div>
                    <div className="shrink-0">
                      <span className={`inline-flex items-center rounded-full border px-2.5 py-1 text-[11px] font-bold uppercase tracking-wider ${
                        r ? "bg-teal-50 text-teal-700 border-teal-200" : "bg-slate-50 text-slate-400 border-slate-200"
                      }`}>
                        {r ? "Done" : "Not done"}
                      </span>
                    </div>
                  </div>
                  <p className="mt-3 text-sm text-slate-600 leading-relaxed">{t.explain(r)}</p>
                  {/* AI confidence (subtle) */}
                  {r && !skipped && (
                    <div className="mt-4">
                      <div className="flex items-center justify-between text-[11px] text-muted-foreground">
                        <span>AI confidence (approx.)</span>
                        <span className="font-mono">{confPct}%</span>
                      </div>
                      <div className="mt-1.5 h-2 w-full rounded-full bg-muted overflow-hidden">
                        <div
                          className="h-full rounded-full bg-teal-600 transition-all"
                          style={{ width: `${confPct}%` }}
                        />
                      </div>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </section>

        {ai_deviation_insights.length > 0 && (
          <section className="rounded-2xl border border-amber-200 bg-amber-50/40 p-6">
            <div className="text-xs font-bold uppercase tracking-widest text-amber-900">
              AI camera insights (if available)
            </div>
            <p className="mt-2 text-sm text-amber-900/80">
              These are supplementary hints. Please confirm with a clinician.
            </p>
            <div className="mt-4 space-y-3">
              {ai_deviation_insights.slice(0, 3).map((row) => (
                <div key={row.id} className="rounded-xl border border-amber-200 bg-white/60 p-4">
                  <div className="text-xs font-bold uppercase tracking-widest text-amber-900">
                    {row.test_name}
                  </div>
                  <pre className="mt-2 overflow-x-auto whitespace-pre-wrap font-mono text-[11px] text-amber-950/90">
{JSON.stringify(
  {
    possible_deviation: row.deviation,
    doctor_review_required: row.doctor_review_required,
  },
  null,
  2
)}
                  </pre>
                </div>
              ))}
            </div>
          </section>
        )}

        {/* Simplified findings — plain-language bullets */}
        <section className="rounded-2xl border border-border bg-card p-6">
          <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-widest text-muted-foreground">
            <HeartPulse size={14} /> What we checked
          </div>
          <ul className="mt-4 space-y-3">
            {(prediction.findings || []).map((f, i) => (
              <li key={i} className="flex items-start gap-3 text-sm text-slate-800">
                <CheckCircle2 className="text-teal-600 shrink-0 mt-0.5" size={18} />
                <span>{f}</span>
              </li>
            ))}
          </ul>
        </section>

        {/* Summary of test completion — no raw data for patient */}
        <section className="rounded-2xl border border-border bg-card p-6">
          <div className="text-xs font-bold uppercase tracking-widest text-muted-foreground">Tests completed</div>
          <div className="mt-3 flex flex-wrap gap-2">
            {["visual_acuity","gaze","hirschberg","prism","titmus","red_reflex","heidelberg"].map((k) => {
              const r = results.find((x) => x.test_name === k);
              const skipped = r?.details?.skipped;
              const label = k.replace("_"," ").replace(/\b\w/g, c => c.toUpperCase());
              return (
                <span key={k} className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold border ${skipped ? "bg-slate-50 text-slate-400 border-slate-200" : r ? "bg-teal-50 text-teal-700 border-teal-200" : "bg-slate-50 text-slate-400 border-slate-200"}`}>
                  {r && !skipped ? <CheckCircle2 size={12} /> : "○"} {label}
                </span>
              );
            })}
          </div>
        </section>

        <MedicalDisclaimer />

        <div className="flex items-center justify-between gap-3 pt-4 flex-wrap">
          <button onClick={() => nav("/patient")} type="button" className="inline-flex items-center gap-2 rounded-xl border border-input bg-background px-4 py-2.5 text-muted-foreground shadow-sm hover:bg-muted/50">
            <Home size={16} /> Back to home
          </button>
          <button data-testid="download-pdf" onClick={download} className="inline-flex items-center gap-2 rounded-xl bg-[#0A2540] px-5 py-2.5 font-semibold text-white shadow-md transition-all hover:bg-[#0D2E52]">
            <FileDown size={16} /> Download your report
          </button>
          <button data-testid="share-pdf" onClick={share} className="inline-flex items-center gap-2 rounded-xl border border-input bg-background px-5 py-2.5 font-semibold text-[#0A2540] shadow-sm transition-all hover:bg-muted/50">
            <Share2 size={16} /> Share report
          </button>
        </div>
      </main>
    </div>
  );
}
