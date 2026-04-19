import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api, useAuthStore } from "@/core/auth/AuthStore";
import { toast } from "sonner";
import LanguageSwitcher from "@/components/ambyo/LanguageSwitcher";
import OfflineBadge from "@/components/ambyo/OfflineBadge";
import AudioToggle from "@/components/ambyo/AudioToggle";
import RiskBadge from "@/components/ambyo/RiskBadge";
import AmbyoEyeLogo from "@/components/ambyo/AmbyoEyeLogo";
import { LogOut, PlayCircle, FileText, ChevronRight, Shield, Sparkles, Hospital,
  ScanEye, Crosshair, Flashlight, Ruler, Layers, Sun, ArrowRight } from "lucide-react";
import { motion } from "framer-motion";

const TESTS = [
  { id: "visual_acuity", name: "Visual Acuity", desc: "How sharp is your vision?", icon: ScanEye, color: "from-sky-500 to-blue-600", dur: "~60s" },
  { id: "gaze",          name: "Gaze Tracking", desc: "Eye alignment in 9 directions", icon: Crosshair, color: "from-teal-400 to-emerald-600", dur: "~30s" },
  { id: "hirschberg",    name: "Hirschberg",    desc: "Corneal light reflex",          icon: Flashlight, color: "from-amber-400 to-orange-500", dur: "~15s" },
  { id: "prism",         name: "Prism Diopter", desc: "Measures ocular deviation",     icon: Ruler,      color: "from-amber-300 to-amber-500", dur: "~5s"  },
  { id: "titmus",        name: "Titmus Stereo", desc: "3D depth perception",            icon: Layers,     color: "from-violet-400 to-fuchsia-600", dur: "~60s" },
  { id: "red_reflex",    name: "Red Reflex",    desc: "Pupil reflex analysis",          icon: Sun,        color: "from-rose-400 to-red-600", dur: "~15s" },
];

export default function PatientHome() {
  const nav = useNavigate();
  const { user, logout } = useAuthStore();
  const [data, setData] = useState({ patient: null, sessions: [] });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get("/patient/me").then((r) => setData(r.data)).catch(() => toast.error("Could not load profile")).finally(() => setLoading(false));
  }, []);

  const startFullScreening = async () => {
    try {
      const c = await api.get(`/consent/${data.patient.id}`);
      if (!c.data || c.data.exists === false) { nav("/patient/consent"); return; }
      const s = await api.post("/sessions", { patient_id: data.patient.id });
      nav(`/patient/session/${s.data.id}/test/0`);
    } catch (e) { toast.error(e?.response?.data?.detail || "Could not start"); }
  };

  const startQuick = (testId) => { nav(`/patient/quick/${testId}`); };

  const { patient, sessions } = data;

  return (
    <div className="min-h-screen bg-slate-50 page-enter">
      <header className="bg-white/80 backdrop-blur border-b border-slate-200 sticky top-0 z-20">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <AmbyoEyeLogo size={40} />
            <div>
              <div className="font-bold text-[#0A2540] leading-none tracking-tight">AmbyoAI</div>
              <div className="text-[11px] text-slate-500 mt-0.5 flex items-center gap-1"><Hospital size={10} /> {patient?.hospital_name || "Aravind Eye Hospital"}</div>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <AudioToggle variant="light" />
            <OfflineBadge />
            <LanguageSwitcher />
            <button data-testid="logout-btn" onClick={() => { logout(); nav("/"); }} className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm text-slate-600 hover:bg-slate-100 transition-colors">
              <LogOut size={14} /> Sign out
            </button>
          </div>
        </div>
      </header>

      <main className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-10">
        {/* Hero with full-screening CTA */}
        <motion.section
          initial={{ y: 8, opacity: 0 }} animate={{ y: 0, opacity: 1 }}
          className="relative overflow-hidden bg-gradient-to-br from-[#0A2540] via-[#0D2E52] to-[#0A2540] text-white rounded-3xl p-6 sm:p-10 shadow-xl"
        >
          <div className="absolute -top-24 -right-24 w-96 h-96 rounded-full bg-teal-400/25 blur-3xl" />
          <div className="absolute -bottom-24 -left-24 w-80 h-80 rounded-full bg-sky-500/20 blur-3xl" />
          <div className="relative">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/10 border border-white/20 text-[11px] uppercase tracking-widest text-teal-200 font-bold">
              <Sparkles size={12} /> AI-assisted screening
            </div>
            <h1 className="mt-4 text-3xl sm:text-5xl font-bold tracking-tight">
              Hello, <span className="bg-gradient-to-br from-teal-200 to-sky-300 bg-clip-text text-transparent">{patient?.name?.split(" ")[0] || "friend"}</span>
            </h1>
            <p className="mt-2 text-slate-300 max-w-xl">
              Run the complete 6-test amblyopia screening in about 3 minutes — or pick a single test below.
            </p>
            <div className="mt-6 flex items-center gap-3 flex-wrap">
              <button
                data-testid="start-screening"
                onClick={startFullScreening}
                className="group inline-flex items-center gap-2 px-6 py-3.5 rounded-2xl bg-teal-400 text-[#0A2540] font-bold shadow-lg hover:bg-teal-300 hover:-translate-y-0.5 transition-all"
              >
                <PlayCircle size={20} /> Start full screening
                <ArrowRight size={18} className="group-hover:translate-x-0.5 transition-transform" />
              </button>
              <div className="inline-flex items-center gap-2 text-xs text-teal-200"><Shield size={14} /> Encrypted · shared only with your doctor</div>
            </div>
          </div>
        </motion.section>

        {/* Individual test picker */}
        <section>
          <div className="flex items-end justify-between flex-wrap gap-2">
            <div>
              <p className="text-xs uppercase tracking-widest text-teal-700 font-bold">Individual tests</p>
              <h2 className="text-2xl font-bold text-[#0A2540] tracking-tight mt-1">Run a single test</h2>
              <p className="text-sm text-slate-500 mt-1">Pick any one test — useful for follow-ups or recheck.</p>
            </div>
          </div>

          <motion.div
            initial="hidden" animate="show"
            variants={{ hidden: {}, show: { transition: { staggerChildren: 0.06 } } }}
            className="mt-5 grid grid-cols-2 md:grid-cols-3 gap-4"
          >
            {TESTS.map((t) => {
              const Icon = t.icon;
              return (
                <motion.button
                  key={t.id}
                  variants={{ hidden: { y: 10, opacity: 0 }, show: { y: 0, opacity: 1 } }}
                  data-testid={`quick-${t.id}`}
                  onClick={() => startQuick(t.id)}
                  className="group relative overflow-hidden text-left bg-white border border-slate-200 rounded-2xl p-5 hover:shadow-lg hover:-translate-y-0.5 hover:border-teal-300 transition-all"
                >
                  <div className={`absolute inset-0 bg-gradient-to-br ${t.color} opacity-0 group-hover:opacity-5 transition-opacity`} />
                  <div className={`w-12 h-12 rounded-2xl bg-gradient-to-br ${t.color} flex items-center justify-center text-white shadow-md`}>
                    <Icon size={22} />
                  </div>
                  <h3 className="mt-4 font-bold text-[#0A2540] tracking-tight">{t.name}</h3>
                  <p className="mt-1 text-sm text-slate-500 leading-snug">{t.desc}</p>
                  <div className="mt-4 flex items-center justify-between">
                    <span className="text-[11px] uppercase tracking-widest text-slate-400 font-mono">{t.dur}</span>
                    <ChevronRight size={16} className="text-slate-400 group-hover:translate-x-1 group-hover:text-teal-600 transition-all" />
                  </div>
                </motion.button>
              );
            })}
          </motion.div>
        </section>

        {/* Past screenings */}
        <section>
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-bold text-[#0A2540] tracking-tight">Past screenings</h2>
            <span className="text-xs text-slate-400 font-mono">{sessions.length} session{sessions.length !== 1 ? "s" : ""}</span>
          </div>
          <div className="mt-4 bg-white border border-slate-200 rounded-2xl overflow-hidden divide-y divide-slate-100">
            {loading && <div className="p-8 text-center text-slate-400">Loading…</div>}
            {!loading && sessions.length === 0 && (
              <div className="p-10 text-center"><p className="text-slate-500">No screenings yet. Start your first one above.</p></div>
            )}
            {sessions.map((s) => (
              <button key={s.id}
                data-testid={`session-row-${s.id}`}
                onClick={() => nav(`/patient/session/${s.id}/results`)}
                className="w-full flex items-center justify-between gap-4 px-5 py-4 hover:bg-slate-50 transition-colors text-left"
              >
                <div className="flex items-center gap-4 min-w-0">
                  <div className="w-10 h-10 rounded-full bg-slate-100 text-slate-600 flex items-center justify-center"><FileText size={18} /></div>
                  <div className="min-w-0">
                    <div className="font-semibold text-[#0A2540] truncate">Screening #{s.id.slice(0, 6)}</div>
                    <div className="text-xs text-slate-500 font-mono">{new Date(s.created_at).toLocaleString()} · {s.status}</div>
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  {s.risk_level && <RiskBadge level={s.risk_level} />}
                  <ChevronRight size={16} className="text-slate-400" />
                </div>
              </button>
            ))}
          </div>
        </section>
      </main>
    </div>
  );
}
