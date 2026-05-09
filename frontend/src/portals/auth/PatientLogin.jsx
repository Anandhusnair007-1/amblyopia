import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { toast } from "sonner";
import { useAuthStore } from "@/core/auth/AuthStore";
import LanguageSwitcher from "@/components/ambyo/LanguageSwitcher";
import OfflineBadge from "@/components/ambyo/OfflineBadge";
import { InputOTP, InputOTPGroup, InputOTPSlot } from "@/components/ui/input-otp";
import { ArrowLeft, HeartPulse, Phone } from "lucide-react";
import { motion } from "framer-motion";
import { useI18n } from "@/core/i18n/translations";

export default function PatientLogin() {
  const nav = useNavigate();
  const { patientRequestOtp, patientVerifyOtp } = useAuthStore();
  const { t } = useI18n();
  const [step, setStep] = useState("phone"); // phone | otp
  const [phone, setPhone] = useState("");
  const [otp, setOtp] = useState("");
  const [loading, setLoading] = useState(false);
  const [demoOtp, setDemoOtp] = useState("");

  const send = async (e) => {
    e?.preventDefault?.();
    if (!/^\d{10}$/.test(phone)) return toast.error(t("patient_login_err_invalid_phone"));
    setLoading(true);
    try {
      const r = await patientRequestOtp(phone);
      setDemoOtp(r.demo_otp || "1234");
      toast.success(t("patient_login_otp_sent_demo", { otp: String(r.demo_otp || "1234") }));
      setStep("otp");
    } catch (e) {
      toast.error(e?.response?.data?.detail || t("patient_login_err_could_not_send_otp"));
    } finally { setLoading(false); }
  };

  const verify = async (code) => {
    setLoading(true);
    try {
      const r = await patientVerifyOtp(phone, code);
      if (r.registered) {
        toast.success(t("welcome_back"));
        nav("/patient");
      } else {
        nav("/patient/register");
      }
    } catch (e) {
      toast.error(e?.response?.data?.detail || t("patient_login_err_invalid_otp"));
      setOtp("");
    } finally { setLoading(false); }
  };

  useEffect(() => { if (otp.length === 4) verify(otp); /* eslint-disable-next-line */ }, [otp]);

  return (
    <div className="min-h-screen relative bg-gradient-to-br from-slate-50 via-white to-teal-50/30 flex items-center justify-center px-4 py-10">
      <div className="absolute inset-0 scan-grid opacity-30 pointer-events-none" />
      <header className="absolute top-4 left-4 right-4 flex items-center justify-between z-10">
        <button onClick={() => nav("/")} data-testid="landing-back" className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm text-slate-600 hover:bg-slate-100">
          <ArrowLeft size={16} /> {t("home")}
        </button>
        <div className="flex items-center gap-2">
          <OfflineBadge /><LanguageSwitcher />
        </div>
      </header>

      <motion.div initial={{ y: 12, opacity: 0 }} animate={{ y: 0, opacity: 1 }} className="relative w-full max-w-md rounded-3xl border border-border bg-card p-8 shadow-xl sm:p-10">
        <div className="w-12 h-12 rounded-2xl bg-teal-50 text-teal-700 flex items-center justify-center">
          <HeartPulse size={22} />
        </div>
        <h1 className="mt-5 text-3xl font-bold tracking-tight text-[#0A2540]">{t("patient_sign_in")}</h1>
        <p className="mt-1 text-slate-500 text-sm">
          {step === "phone"
            ? t("patient_login_phone_help")
            : t("patient_login_otp_help", { phone: String(phone) })}
        </p>

        {step === "phone" ? (
          <form onSubmit={send} className="mt-8 space-y-5">
            <div>
              <label className="text-xs uppercase tracking-widest font-semibold text-slate-500">{t("mobile_number")}</label>
              <div className="mt-2 flex items-center rounded-xl border border-input bg-background focus-within:border-[#0A2540] focus-within:ring-2 focus-within:ring-[#0A2540]/20 transition">
                <div className="pl-3 flex items-center gap-1.5 text-slate-500"><Phone size={16} /><span className="text-sm font-semibold">+91</span></div>
                <input
                  data-testid="phone-input"
                  type="tel"
                  maxLength={10}
                  autoFocus
                  value={phone}
                  onChange={(e) => setPhone(e.target.value.replace(/\D/g, ""))}
                  placeholder={t("ten_digit_number")}
                  className="flex-1 bg-transparent px-3 py-3 text-lg font-mono tracking-wider focus:outline-none"
                />
              </div>
            </div>
            <button
              data-testid="send-otp"
              disabled={loading || phone.length !== 10}
              className="w-full rounded-xl border border-transparent bg-[#0A2540] py-3 font-semibold text-white shadow-md transition-all hover:bg-[#0D2E52] disabled:opacity-40"
            >{loading ? t("sending") : t("send_otp")}</button>
          </form>
        ) : (
          <div className="mt-8 space-y-5">
            <div className="flex justify-center">
              <InputOTP maxLength={4} value={otp} onChange={setOtp} data-testid="otp-input">
                <InputOTPGroup>
                  <InputOTPSlot index={0} className="w-14 h-14 text-2xl" />
                  <InputOTPSlot index={1} className="w-14 h-14 text-2xl" />
                  <InputOTPSlot index={2} className="w-14 h-14 text-2xl" />
                  <InputOTPSlot index={3} className="w-14 h-14 text-2xl" />
                </InputOTPGroup>
              </InputOTP>
            </div>
            {demoOtp && (
              <p className="text-center text-xs text-slate-400">
                {t("demo_otp")}: <span className="font-mono font-semibold text-slate-600">{demoOtp}</span>
              </p>
            )}
            <div className="flex items-center justify-between text-sm">
              <button data-testid="change-phone" onClick={() => { setStep("phone"); setOtp(""); }} className="text-slate-500 hover:text-slate-700">
                {t("change_number")}
              </button>
              <button onClick={send} className="text-teal-700 font-semibold hover:underline">
                {t("resend_otp")}
              </button>
            </div>
          </div>
        )}
      </motion.div>
    </div>
  );
}
