import { useEffect, useState } from "react";
import { api } from "@/core/auth/AuthStore";
import { Shield, ArrowLeft, Search } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { motion } from "framer-motion";
import PageHeader from "@/components/shell/PageHeader";
import DashboardCard from "@/components/shell/DashboardCard";

/**
 * Hospital-grade Audit Log Viewer.
 * Required for security compliance and tracking clinical decisions.
 */
export default function DoctorAuditLogs() {
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [params, setParams] = useState({ action: "", user_role: "", limit: 100 });
  const nav = useNavigate();

  const load = async () => {
    setLoading(true);
    try {
      const r = await api.get("/audit/logs", { params });
      setLogs(r.data);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, [params.action, params.user_role]);

  const filterCls =
    "rounded-lg border border-input bg-background px-3 py-2 text-sm text-foreground shadow-sm focus:outline-none focus:ring-2 focus:ring-teal-600/20 focus:border-teal-600";

  return (
    <div className="page-enter space-y-8">
      <PageHeader
        eyebrow="Security & compliance"
        title="Audit logs"
        description="Immutable clinical and security event tracking"
        actions={
          <div className="flex flex-wrap items-center gap-2">
            <select
              value={params.user_role}
              onChange={(e) => setParams((p) => ({ ...p, user_role: e.target.value }))}
              className={filterCls}
              aria-label="Filter by role"
            >
              <option value="">All Roles</option>
              <option value="doctor">Doctor</option>
              <option value="patient">Patient</option>
              <option value="admin">Admin</option>
            </select>
            <div className="relative">
              <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
              <input
                placeholder="Filter action (e.g. login)"
                value={params.action}
                onChange={(e) => setParams((p) => ({ ...p, action: e.target.value }))}
                className={`${filterCls} pl-9 min-w-[12rem]`}
              />
            </div>
          </div>
        }
      />

      <button
        type="button"
        onClick={() => nav("/doctor")}
        className="inline-flex items-center gap-2 text-sm font-medium text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft size={16} /> Back to worklist
      </button>

      <DashboardCard className="overflow-hidden p-0">
        <div className="flex items-center gap-3 border-b border-border bg-muted/30 px-4 py-3 sm:px-6">
          <div className="flex size-10 shrink-0 items-center justify-center rounded-xl border border-teal-200 bg-teal-50 text-teal-700">
            <Shield size={20} />
          </div>
          <p className="text-sm text-muted-foreground">
            Showing up to {params.limit} entries. Refine with role and action filters.
          </p>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full border-collapse text-left text-sm">
            <thead>
              <tr className="border-b border-border bg-muted/20">
                <th className="px-6 py-4 text-xs font-bold uppercase tracking-widest text-muted-foreground">Timestamp</th>
                <th className="px-6 py-4 text-xs font-bold uppercase tracking-widest text-muted-foreground">Action</th>
                <th className="px-6 py-4 text-xs font-bold uppercase tracking-widest text-muted-foreground">User</th>
                <th className="px-6 py-4 text-xs font-bold uppercase tracking-widest text-muted-foreground">Details</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {loading ? (
                <tr><td colSpan={4} className="px-6 py-12 text-center text-muted-foreground">Loading logs…</td></tr>
              ) : logs.length === 0 ? (
                <tr><td colSpan={4} className="px-6 py-12 text-center text-muted-foreground">No logs found.</td></tr>
              ) : (
                logs.map((log, idx) => (
                  <motion.tr
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ delay: idx * 0.01 }}
                    key={log.id}
                    className="hover:bg-muted/40 transition-colors"
                  >
                    <td className="whitespace-nowrap px-6 py-4 font-mono text-xs text-muted-foreground">
                      {new Date(log.timestamp).toLocaleString()}
                    </td>
                    <td className="px-6 py-4">
                      <span className="inline-flex rounded-md border border-teal-200 bg-teal-50 px-2 py-1 text-[10px] font-bold uppercase tracking-wider text-teal-800">
                        {log.action}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <div className="font-medium text-foreground">{log.user_role}</div>
                      <div className="font-mono text-[10px] text-muted-foreground">{log.user_id?.slice(0, 8)}</div>
                    </td>
                    <td className="max-w-xs px-6 py-4">
                      <div className="truncate text-xs text-muted-foreground">
                        {log.details ? JSON.stringify(log.details) : "—"}
                      </div>
                    </td>
                  </motion.tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </DashboardCard>
    </div>
  );
}
