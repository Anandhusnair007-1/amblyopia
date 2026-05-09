import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { api } from "@/core/auth/AuthStore";
import RiskBadge from "@/components/ambyo/RiskBadge";
import PageHeader from "@/components/shell/PageHeader";
import DashboardCard from "@/components/shell/DashboardCard";
import { ArrowLeft, FileText, ChevronRight, User, Calendar, Phone, Hospital } from "lucide-react";
import PatientContextBar from "@/components/clinical/PatientContextBar";
import { maskPhone } from "@/lib/maskPhone";

export default function DoctorPatientDetail() {
  const nav = useNavigate();
  const { patientId } = useParams();
  const [data, setData] = useState(null);

  useEffect(() => {
    api.get(`/doctor/patients/${patientId}`).then((r) => setData(r.data)).catch(() => {});
  }, [patientId]);

  if (!data) {
    return <div className="flex min-h-[40vh] items-center justify-center text-muted-foreground">Loading…</div>;
  }
  const { patient, sessions } = data;
  const latestSession = sessions[0] || null;

  return (
    <div className="page-enter space-y-8">
      <PageHeader
        eyebrow={`Patient #${patient.id.slice(0, 6)}`}
        title={patient.name}
        actions={
          <button
            type="button"
            data-testid="back-btn"
            onClick={() => nav("/doctor")}
            className="inline-flex items-center gap-2 rounded-xl border border-border bg-card px-4 py-2 text-sm font-medium text-[#0A2540] shadow-sm transition-colors hover:bg-muted"
          >
            <ArrowLeft size={18} /> Back to list
          </button>
        }
      />

      <PatientContextBar
        patient={patient}
        session={latestSession}
        prediction={{ risk_level: patient.last_risk_level }}
        consentSummary="On file"
      />

      <DashboardCard className="p-6 sm:p-8">
        <div className="flex flex-wrap items-start gap-5">
          <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-teal-400 to-sky-500 text-2xl font-bold text-[#0A2540]">
            {patient.name?.[0]?.toUpperCase() || "?"}
          </div>
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-3">
              <h2 className="text-xl font-bold tracking-tight text-[#0A2540]">{patient.name}</h2>
              {patient.last_risk_level && <RiskBadge level={patient.last_risk_level} />}
            </div>
            <div className="mt-3 grid gap-x-6 gap-y-2 text-sm sm:grid-cols-2">
              <div className="flex items-center gap-2 text-muted-foreground">
                <User size={14} className="shrink-0 opacity-70" /> {patient.gender} · age {patient.age}
              </div>
              <div className="flex items-center gap-2 text-muted-foreground">
                <Calendar size={14} className="shrink-0 opacity-70" /> DOB {patient.date_of_birth}
              </div>
              <div className="flex items-center gap-2 text-muted-foreground">
                <Phone size={14} className="shrink-0 opacity-70" /> {maskPhone(patient.phone)}
              </div>
              <div className="flex items-center gap-2 text-muted-foreground">
                <Hospital size={14} className="shrink-0 opacity-70" /> {patient.hospital_name || "Aravind Eye Hospital"}
              </div>
              {patient.guardian_name && (
                <div className="text-sm text-muted-foreground sm:col-span-2">
                  Guardian: {patient.guardian_name} ({patient.guardian_relation})
                </div>
              )}
            </div>
          </div>
        </div>
      </DashboardCard>

      <section>
        <h2 className="text-lg font-bold tracking-tight text-[#0A2540]">Screening history</h2>
        <DashboardCard className="mt-3 divide-y divide-border overflow-hidden p-0">
          {sessions.length === 0 && (
            <div className="p-10 text-center text-muted-foreground">No screenings yet.</div>
          )}
          {sessions.map((s) => (
            <button
              key={s.id}
              data-testid={`session-row-${s.id}`}
              type="button"
              onClick={() => nav(`/doctor/session/${s.id}`)}
              className="flex w-full items-center justify-between gap-4 px-5 py-4 text-left transition-colors hover:bg-muted/50"
            >
              <div className="flex min-w-0 items-center gap-4">
                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-teal-50 text-teal-700">
                  <FileText size={18} />
                </div>
                <div className="min-w-0">
                  <div className="truncate font-semibold text-[#0A2540]">Session #{s.id.slice(0, 6)}</div>
                  <div className="font-mono text-xs text-muted-foreground">
                    {new Date(s.created_at).toLocaleString()} · {s.status}
                    {s.reviewed ? " · reviewed" : ""}
                  </div>
                </div>
              </div>
              <div className="flex items-center gap-3">
                {s.risk_level && <RiskBadge level={s.risk_level} />}
                {s.health_score != null && (
                  <span className="font-mono text-xs text-muted-foreground">{s.health_score} / 100</span>
                )}
                <ChevronRight size={16} className="text-muted-foreground" />
              </div>
            </button>
          ))}
        </DashboardCard>
      </section>
    </div>
  );
}
