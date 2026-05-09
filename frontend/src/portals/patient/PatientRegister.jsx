import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { api, useAuthStore } from "@/core/auth/AuthStore";
import { toast } from "sonner";
import LanguageSwitcher from "@/components/ambyo/LanguageSwitcher";
import OfflineBadge from "@/components/ambyo/OfflineBadge";
import PageHeader from "@/components/shell/PageHeader";
import { motion } from "framer-motion";
import { UserPlus, LogOut } from "lucide-react";
import { useI18n } from "@/core/i18n/translations";

export default function PatientRegister() {
  const nav = useNavigate();
  const { setAuth, user, logout } = useAuthStore();
  const { t } = useI18n();
  const [form, setForm] = useState({
    name: "",
    date_of_birth: "",
    gender: "unspecified",
    guardian_name: "",
    guardian_relation: "Parent",
    mrn: "",
  });
  const [loading, setLoading] = useState(false);
  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }));

  const submit = async (e) => {
    e.preventDefault();
    if (!form.name.trim() || !form.date_of_birth) return toast.error(t("err_name_dob_required"));
    setLoading(true);
    try {
      const payload = { ...form, mrn: form.mrn?.trim() || undefined };
      const r = await api.post("/patient/register", payload);
      setAuth(r.data.token, r.data.user);
      toast.success(t("profile_created"));
      nav("/patient");
    } catch (e) {
      toast.error(e?.response?.data?.detail || t("failed"));
    } finally { setLoading(false); }
  };

  const inputCls =
    "w-full h-12 px-4 rounded-xl border border-input bg-background text-foreground focus:outline-none focus:ring-2 focus:ring-[#0A2540]/20 focus:border-[#0A2540] transition-all";

  return (
    <div className="min-h-screen bg-background page-enter">
      <header className="border-b border-border bg-card">
        <div className="mx-auto flex h-16 max-w-3xl items-center justify-end gap-2 px-4 sm:px-6 lg:px-8">
          <OfflineBadge /><LanguageSwitcher />
          <button onClick={() => { logout(); nav("/"); }} className="inline-flex items-center gap-1.5 rounded-xl border border-input bg-background px-3 py-1.5 text-sm text-foreground shadow-sm hover:bg-muted/50">
            <LogOut size={14} /> {t("sign_out")}
          </button>
        </div>
      </header>
      <main className="mx-auto max-w-3xl space-y-6 px-4 py-8 sm:px-6 lg:px-8">
        <PageHeader
          eyebrow={user?.phone ? `+91 ${user.phone}` : t("patient_onboarding")}
          title={t("create_your_profile")}
          description={t("patient_register_description")}
        />
        <motion.form
          onSubmit={submit}
          initial={{ y: 8, opacity: 0 }} animate={{ y: 0, opacity: 1 }}
          className="space-y-6 rounded-2xl border border-border bg-card p-6 shadow-sm sm:p-8"
        >
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-xl bg-teal-50 text-teal-700 flex items-center justify-center">
              <UserPlus size={22} />
            </div>
            <div>
              <h2 className="text-xl font-bold text-[#0A2540]">{t("who_are_we_screening")}</h2>
              <p className="text-sm text-slate-500">{t("who_are_we_screening_subtitle")}</p>
            </div>
          </div>

          <label className="block">
            <span className="text-xs uppercase tracking-widest text-slate-500 font-semibold">{t("full_name")} *</span>
            <input data-testid="child-name" className={inputCls + " mt-2"} value={form.name} onChange={(e) => set("name", e.target.value)} placeholder={t("patient_register_name_placeholder")} required />
          </label>
          <div className="grid sm:grid-cols-2 gap-5">
            <label className="block">
              <span className="text-xs uppercase tracking-widest text-slate-500 font-semibold">{t("date_of_birth")} *</span>
              <input data-testid="dob" type="date" className={inputCls + " mt-2"} value={form.date_of_birth} onChange={(e) => set("date_of_birth", e.target.value)} max={new Date().toISOString().split("T")[0]} required />
            </label>
            <label className="block">
              <span className="text-xs uppercase tracking-widest text-slate-500 font-semibold">{t("gender")}</span>
              <select data-testid="gender" className={inputCls + " mt-2"} value={form.gender} onChange={(e) => set("gender", e.target.value)}>
                <option value="unspecified">{t("unspecified")}</option>
                <option value="male">{t("male")}</option>
                <option value="female">{t("female")}</option>
              </select>
            </label>
          </div>
          <div className="grid sm:grid-cols-2 gap-5">
            <label className="block">
              <span className="text-xs uppercase tracking-widest text-slate-500 font-semibold">{t("guardian_name")}</span>
              <input data-testid="guardian-name" className={inputCls + " mt-2"} value={form.guardian_name} onChange={(e) => set("guardian_name", e.target.value)} placeholder={t("guardian_name_placeholder")} />
            </label>
            <label className="block">
              <span className="text-xs uppercase tracking-widest text-slate-500 font-semibold">{t("guardian_relation")}</span>
              <select data-testid="guardian-relation" className={inputCls + " mt-2"} value={form.guardian_relation} onChange={(e) => set("guardian_relation", e.target.value)}>
                <option>{t("relation_parent")}</option><option>{t("relation_mother")}</option><option>{t("relation_father")}</option>
                <option>{t("relation_grandparent")}</option><option>{t("relation_guardian")}</option><option>{t("relation_self")}</option>
              </select>
            </label>
          </div>
          <label className="block">
            <span className="text-xs font-semibold tracking-wide text-slate-500">
              {t("patient_register_mrn_label")}
            </span>
            <input
              data-testid="mrn"
              className={inputCls + " mt-2"}
              value={form.mrn}
              onChange={(e) => set("mrn", e.target.value)}
              placeholder={t("patient_register_mrn_placeholder")}
            />
          </label>
          <div className="pt-4 border-t border-slate-100 flex justify-end gap-3">
            <button type="submit" data-testid="submit-patient" disabled={loading} className="inline-flex items-center gap-2 rounded-xl bg-[#0A2540] px-5 py-2.5 font-semibold text-white shadow-md transition-all hover:bg-[#0D2E52] disabled:opacity-60">
              {loading ? t("saving") : t("continue")}
            </button>
          </div>
        </motion.form>
      </main>
    </div>
  );
}
