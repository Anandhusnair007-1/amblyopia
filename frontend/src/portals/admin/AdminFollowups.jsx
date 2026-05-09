import { useEffect, useState } from "react";
import { api } from "@/core/auth/AuthStore";
import PageHeader from "@/components/shell/PageHeader";
import DashboardCard from "@/components/shell/DashboardCard";

const STATUSES = ["pending", "completed", "missed", "rescheduled"];
const selectSm = "rounded-md border border-input bg-background px-2 py-1 text-xs text-foreground";

export default function AdminFollowups() {
  const [rows, setRows] = useState([]);
  const [msg, setMsg] = useState("");

  const load = async () => {
    const r = await api.get("/followups");
    setRows(r.data || []);
  };

  useEffect(() => {
    load().catch((e) => setMsg(e?.response?.data?.detail || String(e)));
  }, []);

  const patch = async (id, status) => {
    setMsg("");
    try {
      await api.patch(`/followups/${id}`, { status });
      await load();
    } catch (e) {
      setMsg(e?.response?.data?.detail || "Update failed");
    }
  };

  return (
    <div className="max-w-5xl space-y-6">
      <PageHeader
        eyebrow="Care coordination"
        title="Follow-ups"
        description="Scoped to your hospital. Documents need hospital_id set server-side when created."
      />
      {msg && <p className="text-sm text-amber-800">{msg}</p>}
      <DashboardCard className="overflow-hidden p-0">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border bg-muted/30 text-left text-muted-foreground">
                <th className="p-3">ID</th>
                <th className="p-3">Due</th>
                <th className="p-3">Status</th>
                <th className="p-3">Patient</th>
                <th className="p-3">Update</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {rows.length === 0 && (
                <tr><td colSpan={5} className="p-6 text-center text-muted-foreground">No follow-ups yet.</td></tr>
              )}
              {rows.map((r) => (
                <tr key={r.id}>
                  <td className="p-3 font-mono text-xs">{r.id}</td>
                  <td className="p-3 text-muted-foreground">{r.due_date || "—"}</td>
                  <td className="p-3 font-medium text-[#0A2540]">{r.status}</td>
                  <td className="p-3 font-mono text-xs">{r.patient_id || "—"}</td>
                  <td className="p-3">
                    <select
                      className={selectSm}
                      value={r.status}
                      onChange={(e) => patch(r.id, e.target.value)}
                    >
                      {STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}
                    </select>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </DashboardCard>
    </div>
  );
}
