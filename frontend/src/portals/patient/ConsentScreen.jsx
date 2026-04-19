import { useEffect, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { api, useAuthStore } from "@/core/auth/AuthStore";
import { useI18n } from "@/core/i18n/translations";
import { toast } from "sonner";
import { Switch } from "@/components/ui/switch";
import { ArrowLeft, ShieldCheck, Camera, Database, Microscope, Stethoscope } from "lucide-react";
import { motion } from "framer-motion";

const TOGGLES = [
  { key: "camera", icon: Camera, tKey: "consent_camera" },
  { key: "storage", icon: Database, tKey: "consent_storage" },
  { key: "research", icon: Microscope, tKey: "consent_research" },
  { key: "doctor_share", icon: Stethoscope, tKey: "consent_doctor" },
];

export default function ConsentScreen() {
  const nav = useNavigate();
  const [search] = useSearchParams();
  const quickTarget = search.get("quick");
  const { user } = useAuthStore();
  const { t, lang } = useI18n();
  const [patient, setPatient] = useState(null);
  const [toggles, setToggles] = useState({ camera: false, storage: false, research: false, doctor_share: false });
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    api.get("/patient/me").then((r) => setPatient(r.data.patient)).catch(() => {});
  }, []);

  const allOn = Object.values(toggles).every(Boolean);

  const submit = async () => {
    if (!allOn || !patient) return;
    setSubmitting(true);
    try {
      await api.post("/consent", { patient_id: patient.id, toggles, language: lang, app_version: "2.0.0" });
      toast.success("Consent saved");
      if (quickTarget) { nav(`/patient/quick/${quickTarget}`); return; }
      const s = await api.post("/sessions", { patient_id: patient.id });
      nav(`/patient/session/${s.data.id}/test/0`);
    } catch (e) {
      toast.error(e?.response?.data?.detail || "Failed");
    } finally { setSubmitting(false); }
  };

  return (
    <div className="min-h-screen bg-slate-50 page-enter">
      <header className="bg-white border-b border-slate-200">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center gap-3">
          <button onClick={() => nav(-1)} data-testid="back-btn" className="p-2 rounded-lg hover:bg-slate-100"><ArrowLeft size={18} /></button>
          <div>
            <div className="font-bold text-[#0A2540] tracking-tight leading-none">{t("consent_title")}</div>
            <div className="text-[11px] text-slate-500 mt-0.5">Informed consent</div>
          </div>
        </div>
      </header>
      <main className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <motion.div initial={{ y: 8, opacity: 0 }} animate={{ y: 0, opacity: 1 }} className="bg-white border border-slate-200 rounded-2xl overflow-hidden shadow-sm">
          <div className="p-6 sm:p-8 bg-gradient-to-br from-[#0A2540] to-[#0D2E52] text-white">
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 rounded-xl bg-white/10 flex items-center justify-center"><ShieldCheck size={24} /></div>
              <div>
                <div className="text-xs uppercase tracking-widest text-teal-200 font-semibold">Patient</div>
                <h2 className="text-2xl font-bold tracking-tight">{patient?.name || "…"}</h2>
                <p className="text-white/70 text-sm mt-0.5">{patient ? `Age ${patient.age} · DOB ${patient.date_of_birth}` : ""}</p>
              </div>
            </div>
          </div>
          <div className="p-6 sm:p-8">
            <p className="text-slate-600 text-sm leading-relaxed">{t("consent_intro")}</p>
            <div className="mt-6 space-y-3">
              {TOGGLES.map(({ key, icon: Icon, tKey }) => (
                <label key={key} className={`flex items-center justify-between gap-4 p-4 rounded-xl border transition-all cursor-pointer ${toggles[key] ? "border-teal-300 bg-teal-50/50" : "border-slate-200 hover:bg-slate-50"}`}>
                  <div className="flex items-center gap-3 min-w-0">
                    <div className={`w-10 h-10 rounded-lg flex items-center justify-center shrink-0 ${toggles[key] ? "bg-teal-600 text-white" : "bg-slate-100 text-slate-500"}`}><Icon size={18} /></div>
                    <span className="text-sm sm:text-base text-slate-800">{t(tKey)}</span>
                  </div>
                  <Switch data-testid={`consent-toggle-${key}`} checked={toggles[key]} onCheckedChange={(v) => setToggles((s) => ({ ...s, [key]: v }))} />
                </label>
              ))}
            </div>
            <div className="mt-6 pt-6 border-t border-slate-100 flex justify-end gap-3">
              <button onClick={() => nav(-1)} className="px-4 py-2.5 rounded-xl text-slate-600 hover:bg-slate-100">Cancel</button>
              <button data-testid="submit-consent" disabled={!allOn || submitting} onClick={submit} className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-teal-600 text-white font-semibold shadow-md hover:bg-teal-700 transition-all disabled:opacity-40">
                {submitting ? "Saving…" : t("i_consent")}
              </button>
            </div>
          </div>
        </motion.div>
      </main>
    </div>
  );
}
