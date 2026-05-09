import { useEffect, useState } from "react";
import { api, useAuthStore } from "@/core/auth/AuthStore";
import PageHeader from "@/components/shell/PageHeader";
import DashboardCard from "@/components/shell/DashboardCard";

const field = "w-full rounded-lg border border-input bg-background px-3 py-2 text-sm text-foreground";

export default function AdminCamps() {
  const { user } = useAuthStore();
  const hid = user?.hospital_id;
  const [camps, setCamps] = useState([]);
  const [branches, setBranches] = useState([]);
  const [msg, setMsg] = useState("");
  const [form, setForm] = useState({
    hospital_id: hid || "",
    branch_id: "",
    name: "",
    location: "",
    start_date: "",
    end_date: "",
  });

  const load = async () => {
    const [c, b] = await Promise.all([
      api.get("/admin/camps"),
      api.get("/admin/branches"),
    ]);
    setCamps(c.data || []);
    setBranches(b.data || []);
  };

  useEffect(() => {
    load().catch((e) => setMsg(e?.response?.data?.detail || String(e)));
  }, []);

  const submit = async (e) => {
    e.preventDefault();
    setMsg("");
    try {
      await api.post("/admin/camps", {
        ...form,
        branch_id: form.branch_id || null,
        location: form.location || "",
        start_date: form.start_date || null,
        end_date: form.end_date || null,
      });
      setMsg("Camp created.");
      await load();
    } catch (e) {
      setMsg(e?.response?.data?.detail || "Create failed");
    }
  };

  const patchStatus = async (id, status) => {
    setMsg("");
    try {
      await api.patch(`/admin/camps/${id}`, { status });
      await load();
    } catch (e) {
      setMsg(e?.response?.data?.detail || "Update failed");
    }
  };

  return (
    <div className="max-w-4xl space-y-8">
      <PageHeader
        eyebrow="Screening"
        title="Camps"
        description="Create and update screening camps."
      />
      {msg && <p className="text-sm text-amber-800">{msg}</p>}

      <DashboardCard className="max-w-md space-y-3 p-4">
        <form onSubmit={submit} className="space-y-3">
          <div className="text-xs font-semibold uppercase text-muted-foreground">New camp</div>
          {!hid && (
            <input
              className={field}
              placeholder="hospital_id"
              value={form.hospital_id}
              onChange={(e) => setForm((f) => ({ ...f, hospital_id: e.target.value }))}
              required
            />
          )}
          <select
            className={field}
            value={form.branch_id}
            onChange={(e) => setForm((f) => ({ ...f, branch_id: e.target.value }))}
          >
            <option value="">Branch (optional)</option>
            {branches.map((b) => (
              <option key={b.id} value={b.id}>{b.name}</option>
            ))}
          </select>
          <input
            className={field}
            placeholder="Camp name"
            value={form.name}
            onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
            required
          />
          <input
            className={field}
            placeholder="Location"
            value={form.location}
            onChange={(e) => setForm((f) => ({ ...f, location: e.target.value }))}
          />
          <div className="flex gap-2">
            <input type="date" className={`${field} flex-1`} value={form.start_date} onChange={(e) => setForm((f) => ({ ...f, start_date: e.target.value }))} />
            <input type="date" className={`${field} flex-1`} value={form.end_date} onChange={(e) => setForm((f) => ({ ...f, end_date: e.target.value }))} />
          </div>
          <button type="submit" className="rounded-lg bg-teal-600 px-4 py-2 text-sm font-semibold text-white hover:bg-teal-700">Create camp</button>
        </form>
      </DashboardCard>

      <DashboardCard className="overflow-hidden p-0">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border bg-muted/30 text-left text-muted-foreground">
                <th className="p-3">Name</th>
                <th className="p-3">Status</th>
                <th className="p-3">Hospital</th>
                <th className="p-3">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {camps.map((c) => (
                <tr key={c.id}>
                  <td className="p-3 font-medium text-[#0A2540]">{c.name}</td>
                  <td className="p-3 text-foreground">{c.status}</td>
                  <td className="p-3 font-mono text-xs text-muted-foreground">{c.hospital_id}</td>
                  <td className="p-3 space-x-2">
                    {["planned", "active", "completed", "cancelled"].map((s) => (
                      <button key={s} type="button" className="text-teal-700 hover:underline" onClick={() => patchStatus(c.id, s)}>{s}</button>
                    ))}
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
