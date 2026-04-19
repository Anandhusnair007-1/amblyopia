import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { api } from "@/core/auth/AuthStore";
import { useI18n } from "@/core/i18n/translations";
import { toast } from "sonner";
import ScoreRing from "@/components/ambyo/ScoreRing";
import RiskBadge from "@/components/ambyo/RiskBadge";
import OfflineBadge from "@/components/ambyo/OfflineBadge";
import LanguageSwitcher from "@/components/ambyo/LanguageSwitcher";
import { generateReport } from "@/reports/PDFGenerator";
import { FileDown, Home, ArrowLeft, CheckCircle2, HeartPulse, CalendarCheck } from "lucide-react";
import { motion } from "framer-motion";

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
    message: "The screening found signs that need prompt attention. Please visit an eye specialist as soon as possible. Show this report to the doctor.",
    next: "Next: visit an ophthalmologist at Aravind Eye Hospital as soon as possible.",
  },
};

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
        if (!r.data.prediction) {
          try { await api.post(`/sessions/${sessionId}/complete`); const r2 = await api.get(`/sessions/${sessionId}`); setData(r2.data); }
          catch { setData(r.data); }
        } else setData(r.data);
      } catch { toast.error("Could not load results"); }
      finally { setLoading(false); }
    })();
  }, [sessionId]);

  if (loading || !data) return <div className="min-h-screen bg-slate-50 flex items-center justify-center text-slate-500">Loading results…</div>;

  const { patient, session, results = [], prediction = {} } = data;
  const risk = prediction.risk_level || "normal";
  const copy = FRIENDLY[risk] || FRIENDLY.normal;

  const download = () => {
    const d = generateReport({ patient, session, results, prediction });
    d.save(`AmbyoAI-${patient?.name?.replace(/\s+/g, "_") || "patient"}.pdf`);
    toast.success("Report downloaded");
  };

  return (
    <div className="min-h-screen bg-slate-50 page-enter" data-testid="patient-results">
      <header className="bg-white border-b border-slate-200 sticky top-0 z-20">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <button onClick={() => nav("/patient")} className="p-2 rounded-lg hover:bg-slate-100"><ArrowLeft size={18} /></button>
            <div>
              <div className="font-bold text-[#0A2540] leading-none tracking-tight">Your Screening</div>
              <div className="text-[11px] text-slate-500 mt-0.5 font-mono">Session #{session?.id?.slice(0, 6)}</div>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <OfflineBadge /><LanguageSwitcher />
          </div>
        </div>
      </header>

      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
        <motion.section
          initial={{ y: 8, opacity: 0 }} animate={{ y: 0, opacity: 1 }}
          className={`relative overflow-hidden bg-gradient-to-br ${copy.bg} border border-slate-200 rounded-3xl p-6 sm:p-10 shadow-sm grid md:grid-cols-[auto_1fr] items-center gap-8`}
        >
          <ScoreRing score={prediction.health_score ?? 0} level={risk} size={180} stroke={14} />
          <div>
            <div className="flex items-center gap-3 flex-wrap">
              <p className="text-xs uppercase tracking-[0.3em] text-teal-700 font-bold">Result</p>
              <RiskBadge level={risk} />
            </div>
            <h1 className={`mt-2 text-3xl sm:text-4xl font-bold tracking-tight ${copy.tone}`}>
              {copy.title}
            </h1>
            <p className="mt-3 text-slate-700 leading-relaxed max-w-xl">{copy.message}</p>
            <div className="mt-4 inline-flex items-center gap-2 text-sm font-semibold text-slate-700 bg-white border border-slate-200 rounded-full px-3 py-1.5">
              <CalendarCheck size={14} /> {copy.next}
            </div>
          </div>
        </motion.section>

        {/* Simplified findings — plain-language bullets */}
        <section className="bg-white border border-slate-200 rounded-2xl p-6">
          <div className="flex items-center gap-2 text-xs uppercase tracking-widest text-slate-500 font-bold">
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
        <section className="bg-white border border-slate-200 rounded-2xl p-6">
          <div className="text-xs uppercase tracking-widest text-slate-500 font-bold">Tests completed</div>
          <div className="mt-3 flex flex-wrap gap-2">
            {["visual_acuity","gaze","hirschberg","prism","titmus","red_reflex"].map((k) => {
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

        <div className="flex items-center justify-between gap-3 pt-4 flex-wrap">
          <button onClick={() => nav("/patient")} className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl text-slate-600 hover:bg-slate-100">
            <Home size={16} /> Back to home
          </button>
          <button data-testid="download-pdf" onClick={download} className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-[#0A2540] text-white font-semibold shadow-md hover:bg-[#0D2E52] transition-all">
            <FileDown size={16} /> Download your report
          </button>
        </div>
      </main>
    </div>
  );
}
