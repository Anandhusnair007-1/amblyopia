import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api, useAuthStore } from "@/core/auth/AuthStore";
import RiskBadge from "@/components/ambyo/RiskBadge";
import LanguageSwitcher from "@/components/ambyo/LanguageSwitcher";
import OfflineBadge from "@/components/ambyo/OfflineBadge";
import CountUp from "@/components/ambyo/CountUp";
import AmbyoEyeLogo from "@/components/ambyo/AmbyoEyeLogo";
import { Stethoscope, LogOut, Users, CheckCircle2, AlertOctagon, Clock, Search, ChevronRight, Filter, ClipboardList } from "lucide-react";
import { motion } from "framer-motion";

const RISK_FILTERS = [
  { key: "", label: "All" },
  { key: "urgent", label: "Urgent" },
  { key: "moderate", label: "Moderate" },
  { key: "mild", label: "Mild" },
  { key: "normal", label: "Normal" },
];

function Stat({ icon: Icon, label, value, color = "slate", testid }) {
  const accent = { slate: "text-slate-300 bg-slate-800/30 border-slate-700",
                   teal: "text-teal-300 bg-teal-500/15 border-teal-500/30",
                   red: "text-red-300 bg-red-500/15 border-red-500/30",
                   amber: "text-amber-300 bg-amber-500/15 border-amber-500/30",
                   sky: "text-sky-300 bg-sky-500/15 border-sky-500/30" }[color];
  const glow = { slate: "", teal: "shadow-[0_0_32px_-12px_rgba(45,212,191,0.4)]",
                 red: "shadow-[0_0_32px_-12px_rgba(239,68,68,0.4)]",
                 amber: "shadow-[0_0_32px_-12px_rgba(245,158,11,0.3)]",
                 sky: "shadow-[0_0_32px_-12px_rgba(56,189,248,0.3)]" }[color];
  return (
    <motion.div
      data-testid={testid}
      whileHover={{ y: -3 }}
      className={`relative overflow-hidden bg-[#121A2F] border border-white/10 rounded-2xl p-5 transition-all ${glow}`}
    >
      <div className="flex items-center justify-between">
        <div className={`w-10 h-10 rounded-lg flex items-center justify-center border ${accent}`}><Icon size={18} /></div>
        <span className="text-[11px] uppercase tracking-widest text-slate-400 font-semibold">{label}</span>
      </div>
      <div className="mt-4 font-mono text-4xl font-bold text-white">
        <CountUp value={value ?? 0} />
      </div>
    </motion.div>
  );
}

export default function DoctorDashboard() {
  const nav = useNavigate();
  const { user, logout } = useAuthStore();
  const [stats, setStats] = useState({});
  const [patients, setPatients] = useState([]);
  const [loading, setLoading] = useState(true);
  const [risk, setRisk] = useState("");
  const [q, setQ] = useState("");

  const load = async () => {
    setLoading(true);
    try {
      const params = {};
      if (risk) params.risk = risk;
      if (q) params.q = q;
      const [s, p] = await Promise.all([api.get("/doctor/stats"), api.get("/doctor/patients", { params })]);
      setStats(s.data); setPatients(p.data);
    } finally { setLoading(false); }
  };
  useEffect(() => { load(); /* eslint-disable-next-line */ }, [risk]);

  return (
    <div className="min-h-screen bg-[#0A0F1C] text-slate-100 page-enter">
      <header className="bg-[#121A2F]/80 backdrop-blur border-b border-white/10 sticky top-0 z-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <AmbyoEyeLogo size={40} color="#0A2540" irisColor="#2DD4BF" />
            <div>
              <div className="font-bold text-white leading-none tracking-tight">AmbyoAI · Doctor</div>
              <div className="text-[11px] text-slate-400 mt-0.5">{user?.name} · {user?.hospital_name || "Aravind Eye Hospital"}</div>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <OfflineBadge /><LanguageSwitcher variant="dark" />
            <button data-testid="logout-btn" onClick={() => { logout(); nav("/"); }} className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm text-slate-300 hover:bg-white/10">
              <LogOut size={14} /> Sign out
            </button>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-8">
        <div>
          <p className="text-xs uppercase tracking-widest text-teal-400 font-bold">Clinical Dashboard</p>
          <h1 className="text-3xl sm:text-4xl font-bold tracking-tight mt-1">Welcome back, {user?.name?.split(" ").slice(-1)[0]}</h1>
          <p className="text-slate-400 mt-1 text-sm">{new Date().toDateString()}</p>
        </div>

        <motion.div initial="hidden" animate="show" variants={{ hidden:{}, show:{ transition:{ staggerChildren:0.06 }}}} className="grid grid-cols-2 md:grid-cols-5 gap-4">
          <motion.div variants={{ hidden:{y:8,opacity:0}, show:{y:0,opacity:1}}}><Stat icon={Users} label="Patients" value={stats.total_patients} color="sky" testid="stat-patients" /></motion.div>
          <motion.div variants={{ hidden:{y:8,opacity:0}, show:{y:0,opacity:1}}}><Stat icon={CheckCircle2} label="Completed" value={stats.completed_sessions} color="teal" testid="stat-completed" /></motion.div>
          <motion.div variants={{ hidden:{y:8,opacity:0}, show:{y:0,opacity:1}}}><Stat icon={AlertOctagon} label="Urgent" value={stats.urgent_cases} color="red" testid="stat-urgent" /></motion.div>
          <motion.div variants={{ hidden:{y:8,opacity:0}, show:{y:0,opacity:1}}}><Stat icon={Clock} label="Today" value={stats.today_sessions} color="amber" testid="stat-today" /></motion.div>
          <motion.div variants={{ hidden:{y:8,opacity:0}, show:{y:0,opacity:1}}}><Stat icon={ClipboardList} label="To Review" value={stats.pending_review} color="slate" testid="stat-pending" /></motion.div>
        </motion.div>

        <section>
          <div className="flex items-end justify-between flex-wrap gap-3">
            <div>
              <h2 className="text-xl font-bold tracking-tight">Patients</h2>
              <p className="text-xs text-slate-400">{patients.length} records</p>
            </div>
            <div className="flex items-center gap-2 flex-wrap">
              <form onSubmit={(e) => { e.preventDefault(); load(); }} className="relative">
                <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                <input
                  data-testid="search-patient"
                  value={q}
                  onChange={(e) => setQ(e.target.value)}
                  placeholder="Search name"
                  className="pl-9 pr-3 py-2 rounded-lg bg-[#121A2F] border border-white/10 text-sm focus:outline-none focus:border-teal-400 transition-colors"
                />
              </form>
              <div className="inline-flex items-center gap-1 p-1 rounded-lg bg-[#121A2F] border border-white/10">
                <Filter size={12} className="text-slate-500 ml-1.5" />
                {RISK_FILTERS.map((f) => (
                  <button
                    key={f.key || "all"}
                    data-testid={`filter-${f.key || "all"}`}
                    onClick={() => setRisk(f.key)}
                    className={`px-2.5 py-1.5 rounded-md text-xs font-semibold tracking-wide transition-all ${risk === f.key ? "bg-teal-500 text-[#0A0F1C]" : "text-slate-400 hover:text-white"}`}
                  >{f.label}</button>
                ))}
              </div>
            </div>
          </div>

          <div className="mt-4 bg-[#121A2F] border border-white/10 rounded-2xl overflow-hidden divide-y divide-white/5">
            {loading && <div className="p-8 text-center text-slate-500">Loading…</div>}
            {!loading && patients.length === 0 && <div className="p-12 text-center text-slate-500">No patients match this filter.</div>}
            {patients.map((p) => (
              <button
                key={p.id}
                data-testid={`patient-row-${p.id}`}
                onClick={() => nav(`/doctor/patient/${p.id}`)}
                className="w-full flex items-center justify-between gap-4 px-5 py-4 hover:bg-white/5 transition-colors text-left"
              >
                <div className="flex items-center gap-4 min-w-0">
                  <div className="w-10 h-10 rounded-full bg-gradient-to-br from-teal-400 to-sky-500 text-[#0A0F1C] flex items-center justify-center font-bold shrink-0">
                    {p.name?.[0]?.toUpperCase() || "?"}
                  </div>
                  <div className="min-w-0">
                    <div className="font-semibold text-white truncate">{p.name}</div>
                    <div className="text-xs text-slate-400 font-mono">Age {p.age} · {p.gender} · +91 {p.phone || "—"}</div>
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  {p.last_risk_level && <RiskBadge level={p.last_risk_level} />}
                  <span className="text-xs text-slate-500 font-mono hidden sm:inline">
                    {p.last_session_date ? new Date(p.last_session_date).toLocaleDateString() : "No sessions"}
                  </span>
                  <ChevronRight size={16} className="text-slate-500" />
                </div>
              </button>
            ))}
          </div>
        </section>
      </main>
    </div>
  );
}
