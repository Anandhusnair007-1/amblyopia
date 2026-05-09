import { useCallback, useEffect, useMemo, useState } from "react";
import { api, useAuthStore } from "@/core/auth/AuthStore";
import PageHeader from "@/components/shell/PageHeader";
import DashboardCard from "@/components/shell/DashboardCard";
import ReferralDetailDrawer from "@/components/referrals/ReferralDetailDrawer";
import { AlertTriangle } from "lucide-react";

export default function AdminReferrals() {
  const { user } = useAuthStore();
  const canPatch = ["doctor", "hospital_admin", "admin", "super_admin"].includes(user?.role);
  const [rows, setRows] = useState([]);
  const [msg, setMsg] = useState("");
  const [selected, setSelected] = useState(null);
  const [drawerOpen, setDrawerOpen] = useState(false);

  const load = useCallback(async () => {
    setMsg("");
    try {
      const r = await api.get("/referrals");
      setRows(r.data || []);
    } catch (e) {
      setMsg(e?.response?.data?.detail || String(e));
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const openRow = (r) => {
    setSelected(r);
    setDrawerOpen(true);
  };

  const patch = async (id, body) => {
    if (!canPatch) return;
    setMsg("");
    try {
      const payload = { ...body };
      if (payload.contact_attempt === undefined) delete payload.contact_attempt;
      await api.patch(`/referrals/${id}`, payload);
      await load();
    } catch (e) {
      setMsg(e?.response?.data?.detail || "Update failed");
    }
  };

  const sorted = useMemo(() => [...rows].sort((a, b) => (b.created_at || "").localeCompare(a.created_at || "")), [rows]);

  return (
    <div className="max-w-6xl space-y-6">
      <PageHeader
        eyebrow="Triage"
        title="Referrals"
        description={
          canPatch
            ? "Urgent sessions create referrals automatically. Use the row to open details, timeline, and SLA."
            : "Read-only referral pipeline."
        }
      />
      {msg && <p className="text-sm text-amber-800">{msg}</p>}
      <DashboardCard className="overflow-hidden p-0">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border bg-muted/30 text-left text-muted-foreground">
                <th className="p-3">Created</th>
                <th className="p-3">Status</th>
                <th className="p-3">Urgency</th>
                <th className="p-3">SLA</th>
                <th className="p-3">Session</th>
                <th className="p-3">Camp</th>
                <th className="p-3 w-24" />
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {sorted.map((r) => (
                <tr key={r.id} className="hover:bg-muted/30">
                  <td className="p-3 text-muted-foreground">{r.created_at}</td>
                  <td className="p-3 font-medium capitalize text-[#0A2540]">{r.status?.replace(/_/g, " ")}</td>
                  <td className="p-3">{r.urgency}</td>
                  <td className="p-3">
                    <div className="flex items-center gap-2">
                      <span className="font-mono text-xs">{r.sla_due_at || "—"}</span>
                      {r.sla_status === "breached" && (
                        <span className="inline-flex items-center gap-1 rounded-full bg-red-100 px-2 py-0.5 text-xs font-medium text-red-800">
                          <AlertTriangle className="h-3 w-3" /> Overdue
                        </span>
                      )}
                    </div>
                  </td>
                  <td className="p-3 font-mono text-xs">{r.session_id}</td>
                  <td className="p-3 font-mono text-xs">{r.camp_id || "—"}</td>
                  <td className="p-3 text-right">
                    <button
                      type="button"
                      className="text-xs font-semibold text-teal-700 hover:underline"
                      onClick={() => openRow(r)}
                    >
                      Details
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </DashboardCard>

      <ReferralDetailDrawer
        row={selected}
        open={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        canPatch={canPatch}
        onUpdated={patch}
      />
    </div>
  );
}
