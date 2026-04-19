import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { toast } from "sonner";
import { useAuthStore } from "@/core/auth/AuthStore";
import LanguageSwitcher from "@/components/ambyo/LanguageSwitcher";
import OfflineBadge from "@/components/ambyo/OfflineBadge";
import { ArrowLeft, Stethoscope, Mail, Lock, Eye as EyeIcon, EyeOff } from "lucide-react";
import { motion } from "framer-motion";

export default function DoctorLogin() {
  const nav = useNavigate();
  const { doctorLogin, token, user } = useAuthStore();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPw, setShowPw] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => { if (token && user?.role === "doctor") nav("/doctor"); }, [token, user, nav]);

  const submit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      await doctorLogin(email, password);
      toast.success("Welcome, doctor");
      nav("/doctor");
    } catch (e) {
      toast.error(e?.response?.data?.detail || "Login failed");
    } finally { setLoading(false); }
  };

  return (
    <div className="min-h-screen relative bg-[#0A0F1C] text-slate-100 flex items-center justify-center px-4 py-10 overflow-hidden">
      <div className="absolute inset-0 scan-grid opacity-30 pointer-events-none" />
      <div className="absolute -top-40 -right-40 w-[32rem] h-[32rem] rounded-full bg-teal-500/10 blur-3xl pointer-events-none" />

      <header className="absolute top-4 left-4 right-4 flex items-center justify-between z-10">
        <button onClick={() => nav("/")} data-testid="landing-back" className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm text-slate-300 hover:bg-white/10">
          <ArrowLeft size={16} /> Home
        </button>
        <div className="flex items-center gap-2">
          <OfflineBadge /><LanguageSwitcher variant="dark" />
        </div>
      </header>

      <motion.form
        onSubmit={submit}
        initial={{ y: 12, opacity: 0 }} animate={{ y: 0, opacity: 1 }}
        className="relative w-full max-w-md bg-[#121A2F]/80 backdrop-blur-xl border border-white/10 rounded-3xl shadow-2xl p-8 sm:p-10"
      >
        <div className="w-12 h-12 rounded-2xl bg-teal-500/20 text-teal-300 flex items-center justify-center">
          <Stethoscope size={22} />
        </div>
        <h1 className="mt-5 text-3xl font-bold tracking-tight text-white">Doctor sign in</h1>
        <p className="mt-1 text-slate-400 text-sm">Aravind Eye Hospital — Clinical Review Portal</p>

        <div className="mt-8 space-y-5">
          <div>
            <label className="text-xs uppercase tracking-widest font-semibold text-slate-400">Email</label>
            <div className="mt-2 flex items-center rounded-xl border border-white/10 bg-white/5 focus-within:border-teal-400/60 focus-within:ring-2 focus-within:ring-teal-400/20">
              <div className="pl-3 text-slate-400"><Mail size={16} /></div>
              <input
                data-testid="doctor-email"
                type="email"
                autoFocus
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="doctor@aravind.in"
                className="flex-1 bg-transparent px-3 py-3 focus:outline-none text-white placeholder:text-slate-500"
                required
              />
            </div>
          </div>
          <div>
            <label className="text-xs uppercase tracking-widest font-semibold text-slate-400">Password</label>
            <div className="mt-2 flex items-center rounded-xl border border-white/10 bg-white/5 focus-within:border-teal-400/60 focus-within:ring-2 focus-within:ring-teal-400/20">
              <div className="pl-3 text-slate-400"><Lock size={16} /></div>
              <input
                data-testid="doctor-password"
                type={showPw ? "text" : "password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="flex-1 bg-transparent px-3 py-3 focus:outline-none text-white"
                required
              />
              <button type="button" onClick={() => setShowPw((s) => !s)} className="px-3 text-slate-400 hover:text-slate-200">
                {showPw ? <EyeOff size={16} /> : <EyeIcon size={16} />}
              </button>
            </div>
          </div>
          <button
            data-testid="doctor-submit"
            disabled={loading}
            className="w-full py-3 rounded-xl bg-teal-500 text-[#0A0F1C] font-bold shadow-md hover:bg-teal-400 transition-all disabled:opacity-40"
          >{loading ? "Signing in…" : "Sign in"}</button>
        </div>

        <p className="mt-6 text-center text-xs text-slate-500">
          Demo: <span className="font-mono text-slate-300">doctor@aravind.in</span> / <span className="font-mono text-slate-300">aravind2026</span>
        </p>
      </motion.form>
    </div>
  );
}
