import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { toast } from "sonner";
import { useAuthStore } from "@/core/auth/AuthStore";
import LanguageSwitcher from "@/components/ambyo/LanguageSwitcher";
import OfflineBadge from "@/components/ambyo/OfflineBadge";
import { ArrowLeft, Stethoscope, Mail, Lock, Eye as EyeIcon, EyeOff } from "lucide-react";
import { motion } from "framer-motion";
import { useI18n } from "@/core/i18n/translations";

function staffHome(role) {
  if (["super_admin", "hospital_admin", "admin"].includes(role)) return "/admin";
  return "/doctor";
}

const fieldWrap =
  "mt-2 flex items-center rounded-xl border border-input bg-background focus-within:border-teal-600 focus-within:ring-2 focus-within:ring-teal-600/20 transition";

export default function DoctorLogin() {
  const nav = useNavigate();
  const { doctorLogin, token, user } = useAuthStore();
  const { t } = useI18n();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPw, setShowPw] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (token && user?.role) nav(staffHome(user.role));
  }, [token, user, nav]);

  const submit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      const u = await doctorLogin(email, password);
      toast.success(t("signed_in"));
      nav(staffHome(u?.role));
    } catch (e) {
      toast.error(e?.response?.data?.detail || t("login_failed"));
    } finally { setLoading(false); }
  };

  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden bg-gradient-to-br from-slate-50 via-white to-teal-50/30 px-4 py-10 text-foreground">
      <div className="pointer-events-none absolute inset-0 scan-grid opacity-30" />
      <div className="pointer-events-none absolute -right-40 -top-40 h-[32rem] w-[32rem] rounded-full bg-teal-400/15 blur-3xl" />

      <header className="absolute left-4 right-4 top-4 z-10 flex items-center justify-between">
        <button onClick={() => nav("/")} data-testid="landing-back" type="button" className="inline-flex items-center gap-1.5 rounded-xl border border-input bg-background px-3 py-1.5 text-sm text-muted-foreground shadow-sm hover:bg-muted/50">
          <ArrowLeft size={16} /> {t("home")}
        </button>
        <div className="flex items-center gap-2">
          <OfflineBadge /><LanguageSwitcher />
        </div>
      </header>

      <motion.form
        onSubmit={submit}
        initial={{ y: 12, opacity: 0 }} animate={{ y: 0, opacity: 1 }}
        className="relative w-full max-w-md rounded-3xl border border-border bg-card p-8 shadow-2xl sm:p-10"
      >
        <div className="flex size-12 items-center justify-center rounded-2xl bg-teal-50 text-teal-700">
          <Stethoscope size={22} />
        </div>
        <h1 className="mt-5 text-3xl font-bold tracking-tight text-[#0A2540]">{t("staff_sign_in")}</h1>
        <p className="mt-1 text-sm text-muted-foreground">{t("staff_sign_in_subtitle")}</p>

        <div className="mt-8 space-y-5">
          <div>
            <label className="text-xs font-semibold uppercase tracking-widest text-muted-foreground">{t("email")}</label>
            <div className={fieldWrap}>
              <div className="pl-3 text-muted-foreground"><Mail size={16} /></div>
              <input
                data-testid="doctor-email"
                type="email"
                autoFocus
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="doctor@aravind.in"
                className="flex-1 bg-transparent px-3 py-3 text-foreground placeholder:text-muted-foreground focus:outline-none"
                required
              />
            </div>
          </div>
          <div>
            <label className="text-xs font-semibold uppercase tracking-widest text-muted-foreground">{t("password")}</label>
            <div className={fieldWrap}>
              <div className="pl-3 text-muted-foreground"><Lock size={16} /></div>
              <input
                data-testid="doctor-password"
                type={showPw ? "text" : "password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="flex-1 bg-transparent px-3 py-3 text-foreground focus:outline-none"
                required
              />
              <button type="button" onClick={() => setShowPw((s) => !s)} className="px-3 text-muted-foreground hover:text-foreground">
                {showPw ? <EyeOff size={16} /> : <EyeIcon size={16} />}
              </button>
            </div>
          </div>
          <button
            data-testid="doctor-submit"
            disabled={loading}
            className="w-full rounded-xl border border-transparent bg-teal-600 py-3 font-bold text-white shadow-md transition-all hover:bg-teal-700 disabled:opacity-40"
          >{loading ? t("signing_in") : t("sign_in")}</button>
        </div>

        <p className="mt-6 text-center text-xs text-muted-foreground">
          {t("demo")}: <span className="font-mono text-foreground">doctor@aravind.in</span> /{" "}
          <span className="font-mono text-foreground">aravind2026</span>
        </p>
      </motion.form>
    </div>
  );
}
