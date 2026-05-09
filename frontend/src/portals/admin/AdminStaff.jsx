import { useEffect, useState } from "react";
import { api, useAuthStore } from "@/core/auth/AuthStore";
import PageHeader from "@/components/shell/PageHeader";
import DashboardCard from "@/components/shell/DashboardCard";

const ROLES = ["doctor", "optometrist", "field_worker", "hospital_admin"];
const field = "w-full rounded-lg border border-input bg-background px-3 py-2 text-sm text-foreground";

export default function AdminStaff() {
  const { user } = useAuthStore();
  const hid = user?.hospital_id;
  const [rows, setRows] = useState([]);
  const [msg, setMsg] = useState("");
  const [form, setForm] = useState({
    hospital_id: hid || "",
    branch_id: "",
    email: "",
    password: "",
    name: "",
    role: "field_worker",
  });

  const load = async () => {
    const r = await api.get("/admin/staff");
    setRows(r.data || []);
  };

  useEffect(() => {
    load().catch((e) => setMsg(e?.response?.data?.detail || String(e)));
  }, []);

  const submit = async (e) => {
    e.preventDefault();
    setMsg("");
    try {
      await api.post("/admin/staff", {
        hospital_id: form.hospital_id,
        branch_id: form.branch_id || null,
        camp_ids: [],
        email: form.email,
        password: form.password,
        name: form.name,
        role: form.role,
      });
      setMsg("Staff created.");
      setForm((f) => ({ ...f, email: "", password: "", name: "" }));
      await load();
    } catch (e) {
      setMsg(e?.response?.data?.detail || "Create failed");
    }
  };

  const toggleActive = async (userId, active) => {
    setMsg("");
    try {
      await api.patch(`/admin/staff/${userId}`, { active: !active });
      await load();
    } catch (e) {
      setMsg(e?.response?.data?.detail || "Update failed");
    }
  };

  return (
    <div className="max-w-4xl space-y-8">
      <PageHeader
        eyebrow="People"
        title="Staff"
        description="Create accounts for camp operations (password login)."
      />
      {msg && <p className="text-sm text-amber-800">{msg}</p>}

      <DashboardCard className="max-w-md space-y-3 p-4">
        <form onSubmit={submit} className="space-y-3">
          <div className="text-xs font-semibold uppercase text-muted-foreground">New staff</div>
          {!hid && (
            <input
              className={field}
              placeholder="hospital_id"
              value={form.hospital_id}
              onChange={(e) => setForm((f) => ({ ...f, hospital_id: e.target.value }))}
              required
            />
          )}
          <input className={field} placeholder="Full name" value={form.name} onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))} required />
          <input className={field} type="email" placeholder="Email" value={form.email} onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))} required />
          <input className={field} type="password" placeholder="Password" value={form.password} onChange={(e) => setForm((f) => ({ ...f, password: e.target.value }))} required />
          <select className={field} value={form.role} onChange={(e) => setForm((f) => ({ ...f, role: e.target.value }))}>
            {ROLES.map((r) => <option key={r} value={r}>{r}</option>)}
          </select>
          <button type="submit" className="rounded-lg bg-teal-600 px-4 py-2 text-sm font-semibold text-white hover:bg-teal-700">Create staff</button>
        </form>
      </DashboardCard>

      <DashboardCard className="overflow-hidden p-0">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border bg-muted/30 text-left text-muted-foreground">
                <th className="p-3">Email</th>
                <th className="p-3">Name</th>
                <th className="p-3">Role</th>
                <th className="p-3">Active</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {rows.map((s) => (
                <tr key={s.user_id || s.id}>
                  <td className="p-3 text-foreground">{s.email}</td>
                  <td className="p-3 font-medium text-[#0A2540]">{s.name}</td>
                  <td className="p-3">{s.role}</td>
                  <td className="p-3">
                    <button type="button" className="text-teal-700 hover:underline" onClick={() => toggleActive(s.user_id, s.active)}>
                      {s.active === false ? "Activate" : "Deactivate"}
                    </button>
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
