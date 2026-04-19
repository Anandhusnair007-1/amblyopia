import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { api } from "@/core/auth/AuthStore";
import { toast } from "sonner";
import ScoreRing from "@/components/ambyo/ScoreRing";
import RiskBadge from "@/components/ambyo/RiskBadge";
import UrgentBanner from "@/components/ambyo/UrgentBanner";
import OfflineBadge from "@/components/ambyo/OfflineBadge";
import LanguageSwitcher from "@/components/ambyo/LanguageSwitcher";
import { generateReport, generateReferralLetter } from "@/reports/PDFGenerator";
import { ArrowLeft, FileDown, Mail, Save, ChevronDown, ChevronUp, Activity, Microscope } from "lucide-react";
import { motion } from "framer-motion";

const SEV_STYLE = {
  normal: "bg-emerald-500/15 text-emerald-300 border-emerald-500/30",
  mild: "bg-amber-500/15 text-amber-300 border-amber-500/30",
  moderate: "bg-orange-500/15 text-orange-300 border-orange-500/30",
  high: "bg-orange-500/20 text-orange-200 border-orange-500/40",
  urgent: "bg-red-500/15 text-red-300 border-red-500/40 animate-pulse",
};

const TESTS = {
  visual_acuity: "Visual Acuity",
  gaze: "Gaze Deviation",
  hirschberg: "Hirschberg",
  prism: "Prism Diopter",
  titmus: "Titmus Stereo",
  red_reflex: "Red Reflex",
};

function ResultCard({ name, result }) {
  const [open, setOpen] = useState(false);
  if (!result) {
    return (
      <div className="bg-[#121A2F] border border-white/10 rounded-xl p-4">
        <div className="text-xs uppercase tracking-widest text-slate-400 font-bold">{TESTS[name] || name}</div>
        <div className="mt-2 text-sm text-slate-500">Not performed</div>
      </div>
    );
  }
  const details = result.details || {};
  const skipped = details.skipped;
  return (
    <div className="bg-[#121A2F] border border-white/10 rounded-xl p-4">
      <div className="flex items-center justify-between">
        <div className="text-xs uppercase tracking-widest text-slate-400 font-bold">{TESTS[name] || name}</div>
        {skipped && <span className="text-xs text-amber-300 font-semibold">SKIPPED</span>}
      </div>
      <div className="mt-2 grid grid-cols-2 gap-2 text-sm">
        <div><span className="text-slate-500">Raw:</span> <span className="font-mono text-white">{Number(result.raw_score).toFixed(2)}</span></div>
        <div><span className="text-slate-500">Norm:</span> <span className="font-mono text-white">{Number(result.normalized_score).toFixed(3)}</span></div>
      </div>
      <button onClick={() => setOpen(!open)} className="mt-3 inline-flex items-center gap-1 text-xs text-teal-300 hover:text-teal-200">
        {open ? <ChevronUp size={12} /> : <ChevronDown size={12} />} {open ? "Hide" : "Show"} raw details
      </button>
      {open && (
        <pre className="mt-2 text-[11px] text-slate-300 bg-black/30 rounded-md p-2 overflow-x-auto font-mono">
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
  const [form, setForm] = useState({ diagnosis: "", treatment: "", risk_label: "", follow_up_date: "", referred_to: "" });

  const load = async () => {
    const r = await api.get(`/sessions/${sessionId}`);
    setData(r.data);
    if (r.data.diagnosis) setForm({
      diagnosis: r.data.diagnosis.diagnosis || "",
      treatment: r.data.diagnosis.treatment || "",
      risk_label: r.data.diagnosis.risk_label || "",
      follow_up_date: r.data.diagnosis.follow_up_date || "",
      referred_to: r.data.diagnosis.referred_to || "",
    });
  };
  useEffect(() => { load().catch(() => toast.error("Could not load session")); /* eslint-disable-next-line */ }, [sessionId]);

  if (!data) return <div className="min-h-screen bg-[#0A0F1C] text-slate-400 flex items-center justify-center">Loading…</div>;
  const { patient, session, results = [], prediction = {} } = data;
  const risk = prediction.risk_level || "normal";
  const urgent = risk === "urgent";
  const medical = prediction.medical_findings || [];

  const saveDiagnosis = async () => {
    if (!form.diagnosis.trim()) return toast.error("Diagnosis required");
    setSaving(true);
    try {
      await api.post("/doctor/diagnoses", { session_id: sessionId, ...form });
      toast.success("Diagnosis saved");
      load();
    } catch (e) {
      toast.error(e?.response?.data?.detail || "Failed");
    } finally { setSaving(false); }
  };

  const downloadPdf = () => {
    const d = generateReport({ patient, session, results, prediction });
    d.save(`AmbyoAI-Medical-${patient?.name?.replace(/\s+/g, "_")}.pdf`);
  };
  const downloadReferral = () => {
    const d = generateReferralLetter({ patient, prediction });
    d.save(`Referral-${patient?.name?.replace(/\s+/g, "_")}.pdf`);
  };

  return (
    <div className="min-h-screen bg-[#0A0F1C] text-slate-100 page-enter" data-testid="doctor-report">
      <header className="bg-[#121A2F]/80 backdrop-blur border-b border-white/10 sticky top-0 z-20">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <button onClick={() => nav(-1)} data-testid="back-btn" className="p-2 rounded-lg hover:bg-white/10"><ArrowLeft size={18} /></button>
            <div>
              <div className="font-bold text-white leading-none tracking-tight">{patient?.name}</div>
              <div className="text-[11px] text-slate-400 mt-0.5 font-mono">Session #{session?.id?.slice(0, 8)} · {new Date(session?.created_at).toLocaleString()}</div>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <OfflineBadge /><LanguageSwitcher variant="dark" />
            <button data-testid="download-pdf" onClick={downloadPdf} className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm bg-teal-500 text-[#0A0F1C] font-semibold hover:bg-teal-400"><FileDown size={14} /> Medical PDF</button>
            {urgent && <button data-testid="download-referral" onClick={downloadReferral} className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm bg-red-500 text-white font-semibold hover:bg-red-400"><Mail size={14} /> Referral</button>}
          </div>
        </div>
      </header>

      <main className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
        {urgent && <UrgentBanner findings={prediction.findings || []} />}

        <motion.section initial={{ y: 8, opacity: 0 }} animate={{ y: 0, opacity: 1 }}
          className="bg-[#121A2F] border border-white/10 rounded-3xl p-6 sm:p-8 grid md:grid-cols-[auto_1fr] gap-8 items-center">
          <ScoreRing score={prediction.health_score ?? 0} level={risk} size={180} stroke={14} />
          <div>
            <div className="flex items-center gap-3 flex-wrap">
              <p className="text-xs uppercase tracking-widest text-teal-300 font-bold">Clinical Risk</p>
              <RiskBadge level={risk} />
              <span className="text-xs font-mono text-slate-400">score {prediction.risk_score} · {prediction.model_version}</span>
            </div>
            <h1 className="mt-2 text-2xl sm:text-3xl font-bold tracking-tight text-white">
              Patient: {patient?.name} <span className="text-slate-400 text-base font-normal">({patient?.age}y, {patient?.gender})</span>
            </h1>
            <p className="mt-2 text-slate-400 text-sm">DOB {patient?.date_of_birth} · Phone +91 {patient?.phone || "—"}{patient?.guardian_name ? ` · Guardian ${patient.guardian_name}` : ""}</p>
            <div className="mt-4 grid sm:grid-cols-3 gap-3">
              <div className="px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-xs">
                <div className="text-slate-500 uppercase tracking-wider">Session started</div>
                <div className="font-mono text-white mt-0.5">{new Date(session?.created_at).toLocaleString()}</div>
              </div>
              <div className="px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-xs">
                <div className="text-slate-500 uppercase tracking-wider">Completed</div>
                <div className="font-mono text-white mt-0.5">{session?.completed_at ? new Date(session.completed_at).toLocaleString() : "—"}</div>
              </div>
              <div className="px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-xs">
                <div className="text-slate-500 uppercase tracking-wider">Health score</div>
                <div className="font-mono text-white mt-0.5">{prediction.health_score} / 100</div>
              </div>
            </div>
          </div>
        </motion.section>

        {/* Medical findings with clinical interpretations */}
        <section>
          <div className="flex items-center gap-2 mb-3">
            <Microscope size={16} className="text-teal-300" />
            <h2 className="text-lg font-bold tracking-tight">Medical Findings</h2>
          </div>
          <div className="grid md:grid-cols-2 gap-4">
            {medical.length === 0 ? (
              <div className="md:col-span-2 bg-[#121A2F] border border-white/10 rounded-xl p-5 text-slate-500 text-sm">
                No abnormal findings flagged. All measured values within normal clinical thresholds.
              </div>
            ) : medical.map((f, i) => (
              <motion.div
                key={i}
                data-testid={`medical-finding-${i}`}
                initial={{ y: 6, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ delay: i * 0.05 }}
                className="bg-[#121A2F] border border-white/10 rounded-xl p-5"
              >
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <div className="text-xs uppercase tracking-widest text-slate-400 font-bold">{f.test}</div>
                    <div className="mt-1 font-mono text-2xl font-bold text-white">{f.value}</div>
                  </div>
                  <span className={`inline-flex px-2.5 py-1 rounded-md text-xs font-bold uppercase tracking-wider border ${SEV_STYLE[f.severity] || SEV_STYLE.normal}`}>
                    {f.severity}
                  </span>
                </div>
                <div className="mt-3 text-xs text-slate-400">
                  <span className="uppercase tracking-wider">Threshold:</span> <span className="text-slate-300 font-mono">{f.threshold}</span>
                </div>
                <p className="mt-2 text-sm text-slate-200 leading-relaxed">{f.interpretation}</p>
              </motion.div>
            ))}
          </div>
        </section>

        {/* Per-test raw data */}
        <section>
          <div className="flex items-center gap-2 mb-3">
            <Activity size={16} className="text-teal-300" />
            <h2 className="text-lg font-bold tracking-tight">Test-by-test raw data</h2>
          </div>
          <div className="grid md:grid-cols-3 gap-4">
            {Object.keys(TESTS).map((k) => (
              <ResultCard key={k} name={k} result={results.find((r) => r.test_name === k)} />
            ))}
          </div>
        </section>

        {/* Diagnosis form */}
        <section className="bg-[#121A2F] border border-white/10 rounded-2xl p-6 sm:p-8">
          <h2 className="text-lg font-bold tracking-tight">Doctor's Review & Diagnosis</h2>
          <p className="text-sm text-slate-400 mt-1">Your notes will be saved to the medical record and appear on the final PDF report.</p>

          <div className="mt-5 space-y-4">
            <div>
              <label className="text-xs uppercase tracking-widest font-semibold text-slate-400">Diagnosis *</label>
              <textarea
                data-testid="diagnosis-input"
                value={form.diagnosis}
                onChange={(e) => setForm({ ...form, diagnosis: e.target.value })}
                rows={3}
                placeholder="E.g. Right-eye amblyopia with mild esotropia. Rule out refractive amblyopia."
                className="mt-2 w-full bg-white/5 border border-white/10 rounded-xl p-3 text-sm focus:outline-none focus:border-teal-400 transition-colors resize-none"
              />
            </div>
            <div>
              <label className="text-xs uppercase tracking-widest font-semibold text-slate-400">Treatment plan</label>
              <textarea
                data-testid="treatment-input"
                value={form.treatment}
                onChange={(e) => setForm({ ...form, treatment: e.target.value })}
                rows={3}
                placeholder="E.g. Prescription glasses, patching 2h/day of dominant eye for 6 weeks, review in 1 month."
                className="mt-2 w-full bg-white/5 border border-white/10 rounded-xl p-3 text-sm focus:outline-none focus:border-teal-400 transition-colors resize-none"
              />
            </div>
            <div className="grid sm:grid-cols-3 gap-4">
              <div>
                <label className="text-xs uppercase tracking-widest font-semibold text-slate-400">Clinical label</label>
                <input
                  data-testid="risk-label-input"
                  value={form.risk_label}
                  onChange={(e) => setForm({ ...form, risk_label: e.target.value })}
                  placeholder="e.g. Anisometropic amblyopia"
                  className="mt-2 w-full bg-white/5 border border-white/10 rounded-xl p-3 text-sm focus:outline-none focus:border-teal-400 transition-colors"
                />
              </div>
              <div>
                <label className="text-xs uppercase tracking-widest font-semibold text-slate-400">Follow-up</label>
                <input
                  type="date"
                  data-testid="followup-input"
                  value={form.follow_up_date}
                  onChange={(e) => setForm({ ...form, follow_up_date: e.target.value })}
                  className="mt-2 w-full bg-white/5 border border-white/10 rounded-xl p-3 text-sm focus:outline-none focus:border-teal-400 transition-colors text-slate-200"
                />
              </div>
              <div>
                <label className="text-xs uppercase tracking-widest font-semibold text-slate-400">Referred to</label>
                <select
                  data-testid="referred-input"
                  value={form.referred_to}
                  onChange={(e) => setForm({ ...form, referred_to: e.target.value })}
                  className="mt-2 w-full bg-white/5 border border-white/10 rounded-xl p-3 text-sm focus:outline-none focus:border-teal-400 transition-colors text-slate-200"
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
          </div>

          <div className="mt-6 flex items-center justify-end">
            <button
              data-testid="save-diagnosis"
              onClick={saveDiagnosis}
              disabled={saving}
              className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-teal-500 text-[#0A0F1C] font-bold shadow-md hover:bg-teal-400 transition-all disabled:opacity-60"
            ><Save size={16} /> {saving ? "Saving…" : "Save diagnosis"}</button>
          </div>

          {data.diagnosis && (
            <div className="mt-5 text-xs text-slate-500 font-mono">
              Last saved {new Date(data.diagnosis.created_at).toLocaleString()} by {data.diagnosis.doctor_name || "Doctor"}
            </div>
          )}
        </section>
      </main>
    </div>
  );
}
