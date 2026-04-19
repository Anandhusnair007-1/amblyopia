import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { api } from "@/core/auth/AuthStore";
import RiskBadge from "@/components/ambyo/RiskBadge";
import OfflineBadge from "@/components/ambyo/OfflineBadge";
import LanguageSwitcher from "@/components/ambyo/LanguageSwitcher";
import { ArrowLeft, FileText, ChevronRight, User, Calendar, Phone, Hospital } from "lucide-react";

export default function DoctorPatientDetail() {
  const nav = useNavigate();
  const { patientId } = useParams();
  const [data, setData] = useState(null);

  useEffect(() => {
    api.get(`/doctor/patients/${patientId}`).then((r) => setData(r.data)).catch(() => {});
  }, [patientId]);

  if (!data) return <div className="min-h-screen bg-[#0A0F1C] text-slate-400 flex items-center justify-center">Loading…</div>;
  const { patient, sessions } = data;

  return (
    <div className="min-h-screen bg-[#0A0F1C] text-slate-100 page-enter">
      <header className="bg-[#121A2F]/80 backdrop-blur border-b border-white/10 sticky top-0 z-20">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <button onClick={() => nav("/doctor")} data-testid="back-btn" className="p-2 rounded-lg hover:bg-white/10"><ArrowLeft size={18} /></button>
            <div>
              <div className="font-bold text-white leading-none tracking-tight">{patient.name}</div>
              <div className="text-[11px] text-slate-400 mt-0.5 font-mono">Patient #{patient.id.slice(0,6)}</div>
            </div>
          </div>
          <div className="flex items-center gap-2"><OfflineBadge /><LanguageSwitcher variant="dark" /></div>
        </div>
      </header>

      <main className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
        <section className="bg-[#121A2F] border border-white/10 rounded-2xl p-6 sm:p-8">
          <div className="flex items-start gap-5 flex-wrap">
            <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-teal-400 to-sky-500 text-[#0A0F1C] flex items-center justify-center font-bold text-2xl">
              {patient.name?.[0]?.toUpperCase() || "?"}
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-3 flex-wrap">
                <h1 className="text-2xl font-bold tracking-tight">{patient.name}</h1>
                {patient.last_risk_level && <RiskBadge level={patient.last_risk_level} />}
              </div>
              <div className="mt-3 grid sm:grid-cols-2 gap-x-6 gap-y-2 text-sm">
                <div className="flex items-center gap-2 text-slate-300"><User size={14} className="text-slate-500" /> {patient.gender} · age {patient.age}</div>
                <div className="flex items-center gap-2 text-slate-300"><Calendar size={14} className="text-slate-500" /> DOB {patient.date_of_birth}</div>
                <div className="flex items-center gap-2 text-slate-300"><Phone size={14} className="text-slate-500" /> +91 {patient.phone || "—"}</div>
                <div className="flex items-center gap-2 text-slate-300"><Hospital size={14} className="text-slate-500" /> {patient.hospital_name || "Aravind Eye Hospital"}</div>
                {patient.guardian_name && <div className="text-slate-400">Guardian: {patient.guardian_name} ({patient.guardian_relation})</div>}
              </div>
            </div>
          </div>
        </section>

        <section>
          <h2 className="text-lg font-bold tracking-tight">Screening history</h2>
          <div className="mt-3 bg-[#121A2F] border border-white/10 rounded-2xl overflow-hidden divide-y divide-white/5">
            {sessions.length === 0 && <div className="p-10 text-center text-slate-500">No screenings yet.</div>}
            {sessions.map((s) => (
              <button
                key={s.id}
                data-testid={`session-row-${s.id}`}
                onClick={() => nav(`/doctor/session/${s.id}`)}
                className="w-full flex items-center justify-between gap-4 px-5 py-4 hover:bg-white/5 transition-colors text-left"
              >
                <div className="flex items-center gap-4 min-w-0">
                  <div className="w-10 h-10 rounded-full bg-white/5 text-teal-300 flex items-center justify-center">
                    <FileText size={18} />
                  </div>
                  <div className="min-w-0">
                    <div className="font-semibold text-white truncate">Session #{s.id.slice(0,6)}</div>
                    <div className="text-xs text-slate-400 font-mono">
                      {new Date(s.created_at).toLocaleString()} · {s.status}
                      {s.reviewed ? " · reviewed" : ""}
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  {s.risk_level && <RiskBadge level={s.risk_level} />}
                  {s.health_score != null && (
                    <span className="font-mono text-xs text-slate-400">{s.health_score} / 100</span>
                  )}
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
