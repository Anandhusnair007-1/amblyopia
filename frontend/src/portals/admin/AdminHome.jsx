import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, useAuthStore } from "@/core/auth/AuthStore";
import PageHeader from "@/components/shell/PageHeader";
import DashboardCard from "@/components/shell/DashboardCard";

function StatTile({ label, value, sub }) {
  return (
    <div className="rounded-2xl border border-border bg-card p-4 shadow-sm">
      <div className="text-xs font-medium text-muted-foreground">{label}</div>
      <div className="mt-2 font-mono text-2xl font-bold text-[#0A2540]">{value ?? "—"}</div>
      {sub && <div className="mt-1 text-xs text-muted-foreground">{sub}</div>}
    </div>
  );
}

export default function AdminHome() {
  const { user } = useAuthStore();
  const ops = ["super_admin", "hospital_admin", "admin"].includes(user?.role);
  const [hospitals, setHospitals] = useState([]);
  const [stats, setStats] = useState(null);
  const [referrals, setReferrals] = useState([]);
  const [camps, setCamps] = useState([]);
  const [devices, setDevices] = useState([]);
  const [err, setErr] = useState("");

  useEffect(() => {
    let cancel = false;
    (async () => {
      try {
        const [h, st, ref, cp, dv] = await Promise.all([
          api.get("/admin/hospitals").catch(() => ({ data: [] })),
          api.get("/doctor/stats").catch(() => ({ data: {} })),
          api.get("/referrals").catch(() => ({ data: [] })),
          api.get("/admin/camps").catch(() => ({ data: [] })),
          api.get("/admin/devices").catch(() => ({ data: [] })),
        ]);
        if (cancel) return;
        setHospitals(h.data || []);
        setStats(st.data || {});
        setReferrals(ref.data || []);
        setCamps(cp.data || []);
        setDevices(dv.data || []);
      } catch (e) {
        if (!cancel) setErr(e?.response?.data?.detail || "Failed to load overview");
      }
    })();
    return () => {
      cancel = true;
    };
  }, []);

  const urgentRefs = referrals.filter((r) => r.urgency === "urgent" && r.status !== "closed").length;
  const overdueRefs = referrals.filter((r) => r.sla_status === "breached").length;
  const activeCamps = camps.filter((c) => c.status === "active" || !c.status).length;
  const activeDevices = devices.filter((d) => d.status === "active").length;
  const completionApprox =
    stats?.completed_sessions != null && stats?.today_sessions != null && stats.today_sessions > 0
      ? `${Math.round((stats.completed_sessions / Math.max(stats.today_sessions, 1)) * 100)}% (approx.)`
      : "—";

  return (
    <div className="mx-auto max-w-[1440px] space-y-8">
      <PageHeader
        eyebrow="Operations"
        title="Command center"
        description="Live operational snapshot for screening, reviews, referrals, and sites."
      />
      {err && (
        <DashboardCard className="border-amber-200 bg-amber-50/50 p-4">
          <p className="text-sm text-amber-900">{String(err)}</p>
        </DashboardCard>
      )}

      <div className="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-5">
        <StatTile label="Active camps" value={activeCamps} />
        <StatTile label="Screened today (sessions started)" value={stats?.today_sessions} />
        <StatTile label="Urgent referrals (open)" value={urgentRefs} />
        <StatTile label="Pending clinical reviews" value={stats?.pending_review} />
        <StatTile label="Follow-ups due" value={stats?.followups_due} />
        <StatTile label="Overdue referrals (SLA)" value={overdueRefs} />
        <StatTile label="Staff on platform (patients)" value={stats?.total_patients} sub="Registered patients" />
        <StatTile label="Devices active" value={activeDevices} sub={`${devices.length} registered`} />
        <StatTile label="Completed sessions (all time)" value={stats?.completed_sessions} />
        <StatTile label="Completion vs today" value={completionApprox} sub="Heuristic for pilots" />
      </div>

      <DashboardCard className="border-border p-0">
        <div className="border-b border-border px-4 py-3">
          <h2 className="text-sm font-semibold text-[#0A2540]">Hospitals in scope</h2>
        </div>
        <ul className="divide-y divide-border">
          {(hospitals || []).map((h) => (
            <li key={h.id} className="px-4 py-3 text-sm">
              <span className="font-medium text-[#0A2540]">{h.name}</span>
              <span className="ml-2 font-mono text-xs text-muted-foreground">{h.id}</span>
              {h.status && <span className="ml-2 text-muted-foreground">· {h.status}</span>}
            </li>
          ))}
        </ul>
      </DashboardCard>

      <div className="grid gap-4 rounded-2xl border border-dashed border-border bg-muted/20 p-4 md:grid-cols-2">
        <div>
          <h3 className="text-sm font-semibold text-[#0A2540]">Integrations (future)</h3>
          <p className="mt-1 text-xs text-muted-foreground">SSO / FHIR connectors will appear here for enterprise rollout.</p>
        </div>
        <div>
          <h3 className="text-sm font-semibold text-[#0A2540]">Break-glass access</h3>
          <p className="mt-1 text-xs text-muted-foreground">
            Emergency elevated access is logged with a reason. Wire to your hospital policy before go-live.
          </p>
        </div>
      </div>

      {ops && (
        <div className="flex flex-wrap gap-4 text-sm">
          <Link to="/admin/camps" className="font-medium text-teal-800 hover:underline">
            Camps →
          </Link>
          <Link to="/admin/staff" className="font-medium text-teal-800 hover:underline">
            Staff →
          </Link>
          <Link to="/admin/referrals" className="font-medium text-teal-800 hover:underline">
            Referrals →
          </Link>
          <Link to="/admin/followups" className="font-medium text-teal-800 hover:underline">
            Follow-ups →
          </Link>
          <Link to="/doctor/audit" className="font-medium text-teal-800 hover:underline">
            Audit logs →
          </Link>
        </div>
      )}
    </div>
  );
}
