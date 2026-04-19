import { useNavigate } from "react-router-dom";
import { useAuthStore } from "@/core/auth/AuthStore";
import { useEffect, useRef, useState } from "react";
import LanguageSwitcher from "@/components/ambyo/LanguageSwitcher";
import OfflineBadge from "@/components/ambyo/OfflineBadge";
import AmbyoEyeLogo from "@/components/ambyo/AmbyoEyeLogo";
import { motion, useMotionValue, useTransform } from "framer-motion";
import { HeartPulse, Stethoscope, ShieldCheck, ChevronRight, Sparkles, Clock, Languages } from "lucide-react";

function ParallaxBlob({ className = "", offset = 20 }) {
  return <div className={`absolute rounded-full blur-3xl pointer-events-none ${className}`} style={{ transform: `translateY(${offset}px)` }} />;
}

export default function Landing() {
  const nav = useNavigate();
  const { token, user } = useAuthStore();
  const mx = useMotionValue(0), my = useMotionValue(0);
  const rotX = useTransform(my, [-200, 200], [6, -6]);
  const rotY = useTransform(mx, [-200, 200], [-6, 6]);

  useEffect(() => {
    if (token && user?.role === "patient") nav("/patient");
    if (token && user?.role === "doctor") nav("/doctor");
  }, [token, user, nav]);

  const onMouse = (e) => {
    const r = e.currentTarget.getBoundingClientRect();
    mx.set(e.clientX - r.left - r.width / 2);
    my.set(e.clientY - r.top - r.height / 2);
  };

  return (
    <div onMouseMove={onMouse} className="min-h-screen relative overflow-hidden bg-gradient-to-br from-slate-50 via-white to-teal-50/30">
      {/* Layered backgrounds */}
      <div className="absolute inset-0 scan-grid opacity-30 pointer-events-none" />
      <ParallaxBlob className="-top-56 -right-56 w-[48rem] h-[48rem] bg-teal-400/10" />
      <ParallaxBlob className="-bottom-56 -left-56 w-[48rem] h-[48rem] bg-[#0A2540]/10" />

      {/* Animated floating particles (visual depth) */}
      <div className="absolute inset-0 pointer-events-none">
        {[...Array(14)].map((_, i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, y: 40 }}
            animate={{
              opacity: [0, 0.45, 0],
              y: [40, -40, -80],
              x: [0, (i % 2 ? 20 : -20)],
            }}
            transition={{ duration: 10 + i, repeat: Infinity, delay: i * 0.4, ease: "easeInOut" }}
            className="absolute rounded-full bg-teal-400"
            style={{
              width: 4 + (i % 3) * 2,
              height: 4 + (i % 3) * 2,
              left: `${(i * 7 + 10) % 95}%`,
              top: `${(i * 13 + 20) % 90}%`,
            }}
          />
        ))}
      </div>

      <header className="relative z-10 px-6 sm:px-10 py-6 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <AmbyoEyeLogo size={44} />
          <div>
            <div className="font-bold text-[#0A2540] tracking-tight">AmbyoAI</div>
            <div className="text-[10px] uppercase tracking-widest text-teal-700 font-semibold">Pediatric Eye Screening</div>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <OfflineBadge />
          <LanguageSwitcher />
        </div>
      </header>

      <main className="relative z-10 max-w-6xl mx-auto px-6 sm:px-10 pt-10 sm:pt-16 pb-16">
        <motion.div
          initial={{ y: 20, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ duration: 0.55, ease: [0.22,1,0.36,1] }}
          className="text-center"
        >
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-white border border-slate-200 shadow-sm text-xs font-semibold text-teal-700">
            <Sparkles size={14} />
            <span>India's first browser-based pediatric amblyopia screening</span>
          </div>
          <h1 className="mt-6 text-4xl sm:text-6xl lg:text-7xl font-bold tracking-tight text-[#0A2540]">
            Detect lazy eye in under{" "}
            <span className="relative inline-block">
              <span className="relative z-10 bg-gradient-to-br from-teal-600 to-emerald-500 bg-clip-text text-transparent">3 minutes</span>
              <motion.span
                initial={{ scaleX: 0 }} animate={{ scaleX: 1 }} transition={{ duration: 0.8, delay: 0.6, ease: "easeOut" }}
                className="absolute left-0 bottom-1 h-1.5 w-full bg-teal-400/60 origin-left rounded"
              />
            </span>
            <span className="text-[#0A2540]">.</span>
          </h1>
          <p className="mt-5 text-lg sm:text-xl text-slate-600 max-w-2xl mx-auto leading-relaxed">
            Six clinical tests. Zero equipment. Works offline. Powered by AI and built for the workflow at{" "}
            <span className="font-semibold text-[#0A2540]">Aravind Eye Hospital</span>.
          </p>
        </motion.div>

        <motion.div
          style={{ rotateX: rotX, rotateY: rotY, transformPerspective: 1000 }}
          initial="hidden" animate="show"
          variants={{ hidden: {}, show: { transition: { staggerChildren: 0.12, delayChildren: 0.3 } } }}
          className="mt-14 grid sm:grid-cols-2 gap-6 max-w-3xl mx-auto"
        >
          {/* Patient Portal */}
          <motion.button
            variants={{ hidden: { y: 16, opacity: 0 }, show: { y: 0, opacity: 1 } }}
            data-testid="patient-portal-cta"
            onClick={() => nav("/patient-login")}
            whileHover={{ y: -6 }}
            className="group relative text-left bg-white border border-slate-200 rounded-3xl p-8 hover:border-teal-300 hover:shadow-2xl transition-all overflow-hidden"
          >
            <div className="absolute inset-0 bg-gradient-to-br from-teal-50/0 via-teal-50/0 to-teal-50 opacity-0 group-hover:opacity-100 transition-opacity" />
            <div className="relative">
              <div className="w-14 h-14 rounded-2xl bg-teal-50 text-teal-700 flex items-center justify-center group-hover:bg-teal-600 group-hover:text-white group-hover:scale-110 transition-all">
                <HeartPulse size={26} />
              </div>
              <h2 className="mt-6 text-2xl font-bold text-[#0A2540] tracking-tight">Patient Portal</h2>
              <p className="mt-1.5 text-slate-500 text-sm leading-relaxed">
                Screen yourself or your child at home. Sign in with your phone number and start a new screening.
              </p>
              <div className="mt-6 inline-flex items-center gap-2 text-sm font-semibold text-teal-700 group-hover:gap-3 transition-all">
                Continue as patient <ChevronRight size={16} />
              </div>
              <div className="absolute top-0 right-0 text-[10px] uppercase tracking-widest text-slate-400 font-semibold">
                Phone + OTP
              </div>
            </div>
          </motion.button>

          {/* Doctor Portal */}
          <motion.button
            variants={{ hidden: { y: 16, opacity: 0 }, show: { y: 0, opacity: 1 } }}
            data-testid="doctor-portal-cta"
            onClick={() => nav("/doctor-login")}
            whileHover={{ y: -6 }}
            className="group relative text-left bg-[#0A2540] text-white rounded-3xl p-8 hover:shadow-2xl transition-all border border-[#0A2540] overflow-hidden"
          >
            <motion.div
              aria-hidden
              className="absolute -top-1/2 -left-1/2 w-[200%] h-[200%] opacity-20"
              animate={{ rotate: 360 }}
              transition={{ duration: 22, repeat: Infinity, ease: "linear" }}
              style={{
                background: "conic-gradient(from 0deg, transparent 0deg, transparent 280deg, rgba(45,212,191,0.4) 340deg, transparent 360deg)",
              }}
            />
            <div className="relative">
              <div className="w-14 h-14 rounded-2xl bg-white/10 text-teal-300 flex items-center justify-center group-hover:bg-teal-400 group-hover:text-[#0A2540] group-hover:scale-110 transition-all">
                <Stethoscope size={26} />
              </div>
              <h2 className="mt-6 text-2xl font-bold tracking-tight">Doctor Portal</h2>
              <p className="mt-1.5 text-slate-300 text-sm leading-relaxed">
                Review screening results, access detailed clinical measurements, and manage patient diagnoses.
              </p>
              <div className="mt-6 inline-flex items-center gap-2 text-sm font-semibold text-teal-300 group-hover:gap-3 transition-all">
                Continue as doctor <ChevronRight size={16} />
              </div>
              <div className="absolute top-0 right-0 text-[10px] uppercase tracking-widest text-teal-300/70 font-semibold">
                Hospital login
              </div>
            </div>
          </motion.button>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.6, duration: 0.5 }}
          className="mt-16 flex items-center justify-center gap-6 text-xs text-slate-500 font-medium flex-wrap"
        >
          <span className="inline-flex items-center gap-1.5"><ShieldCheck size={14} /> Hospital-grade clinical thresholds</span>
          <span className="inline-flex items-center gap-1.5"><Clock size={14} /> ~3 minutes per screening</span>
          <span className="inline-flex items-center gap-1.5"><Languages size={14} /> EN · தமிழ் · മലയാളം</span>
        </motion.div>
      </main>

      {/* Footer byline */}
      <footer className="relative z-10 border-t border-slate-200 mt-10">
        <div className="max-w-6xl mx-auto px-6 py-4 flex items-center justify-between text-xs text-slate-400">
          <span>© 2026 AmbyoAI — Aravind Eye Hospital pilot</span>
          <span className="font-mono">v2.1</span>
        </div>
      </footer>
    </div>
  );
}
