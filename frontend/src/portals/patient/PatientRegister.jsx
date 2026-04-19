import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { api, useAuthStore } from "@/core/auth/AuthStore";
import { toast } from "sonner";
import LanguageSwitcher from "@/components/ambyo/LanguageSwitcher";
import OfflineBadge from "@/components/ambyo/OfflineBadge";
import { motion } from "framer-motion";
import { UserPlus, LogOut } from "lucide-react";

export default function PatientRegister() {
  const nav = useNavigate();
  const { setAuth, user, logout } = useAuthStore();
  const [form, setForm] = useState({
    name: "", date_of_birth: "", gender: "unspecified",
    guardian_name: "", guardian_relation: "Parent",
  });
  const [loading, setLoading] = useState(false);
  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }));

  const submit = async (e) => {
    e.preventDefault();
    if (!form.name.trim() || !form.date_of_birth) return toast.error("Name and DOB required");
    setLoading(true);
    try {
      const r = await api.post("/patient/register", form);
      setAuth(r.data.token, r.data.user);
      toast.success("Profile created");
      nav("/patient");
    } catch (e) {
      toast.error(e?.response?.data?.detail || "Failed");
    } finally { setLoading(false); }
  };

  const inputCls = "w-full h-12 px-4 rounded-xl border border-slate-200 bg-white focus:outline-none focus:ring-2 focus:ring-[#0A2540]/20 focus:border-[#0A2540] transition-all";

  return (
    <div className="min-h-screen bg-slate-50 page-enter">
      <header className="bg-white border-b border-slate-200">
        <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div>
            <div className="font-bold text-[#0A2540] tracking-tight leading-none">Create your profile</div>
            <div className="text-[11px] text-slate-500 mt-0.5">+91 {user?.phone}</div>
          </div>
          <div className="flex items-center gap-2">
            <OfflineBadge /><LanguageSwitcher />
            <button onClick={() => { logout(); nav("/"); }} className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm text-slate-600 hover:bg-slate-100">
              <LogOut size={14} /> Sign out
            </button>
          </div>
        </div>
      </header>
      <main className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <motion.form
          onSubmit={submit}
          initial={{ y: 8, opacity: 0 }} animate={{ y: 0, opacity: 1 }}
          className="bg-white border border-slate-200 rounded-2xl p-6 sm:p-8 shadow-sm space-y-6"
        >
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-xl bg-teal-50 text-teal-700 flex items-center justify-center">
              <UserPlus size={22} />
            </div>
            <div>
              <h2 className="text-xl font-bold text-[#0A2540]">Who are we screening?</h2>
              <p className="text-sm text-slate-500">You can register yourself or a child under your care.</p>
            </div>
          </div>

          <label className="block">
            <span className="text-xs uppercase tracking-widest text-slate-500 font-semibold">Full Name *</span>
            <input data-testid="child-name" className={inputCls + " mt-2"} value={form.name} onChange={(e) => set("name", e.target.value)} placeholder="e.g. Aarav Kumar" required />
          </label>
          <div className="grid sm:grid-cols-2 gap-5">
            <label className="block">
              <span className="text-xs uppercase tracking-widest text-slate-500 font-semibold">Date of Birth *</span>
              <input data-testid="dob" type="date" className={inputCls + " mt-2"} value={form.date_of_birth} onChange={(e) => set("date_of_birth", e.target.value)} max={new Date().toISOString().split("T")[0]} required />
            </label>
            <label className="block">
              <span className="text-xs uppercase tracking-widest text-slate-500 font-semibold">Gender</span>
              <select data-testid="gender" className={inputCls + " mt-2"} value={form.gender} onChange={(e) => set("gender", e.target.value)}>
                <option value="unspecified">Prefer not to say</option>
                <option value="male">Male</option>
                <option value="female">Female</option>
              </select>
            </label>
          </div>
          <div className="grid sm:grid-cols-2 gap-5">
            <label className="block">
              <span className="text-xs uppercase tracking-widest text-slate-500 font-semibold">Guardian Name</span>
              <input data-testid="guardian-name" className={inputCls + " mt-2"} value={form.guardian_name} onChange={(e) => set("guardian_name", e.target.value)} placeholder="If a minor" />
            </label>
            <label className="block">
              <span className="text-xs uppercase tracking-widest text-slate-500 font-semibold">Relation</span>
              <select data-testid="guardian-relation" className={inputCls + " mt-2"} value={form.guardian_relation} onChange={(e) => set("guardian_relation", e.target.value)}>
                <option>Parent</option><option>Mother</option><option>Father</option>
                <option>Grandparent</option><option>Guardian</option><option>Self</option>
              </select>
            </label>
          </div>
          <div className="pt-4 border-t border-slate-100 flex justify-end gap-3">
            <button type="submit" data-testid="submit-patient" disabled={loading} className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-[#0A2540] text-white font-semibold shadow-md hover:bg-[#0D2E52] transition-all disabled:opacity-60">
              {loading ? "Saving…" : "Continue"}
            </button>
          </div>
        </motion.form>
      </main>
    </div>
  );
}
