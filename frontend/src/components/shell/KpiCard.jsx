import { motion } from "framer-motion";
import CountUp from "@/components/ambyo/CountUp";

const ACCENTS = {
  slate: "text-slate-600 bg-slate-100 border-slate-200",
  teal: "text-teal-700 bg-teal-50 border-teal-200",
  red: "text-red-700 bg-red-50 border-red-200",
  amber: "text-amber-800 bg-amber-50 border-amber-200",
  sky: "text-sky-800 bg-sky-50 border-sky-200",
};

const GLOW = {
  slate: "",
  teal: "shadow-[0_12px_40px_-16px_rgba(13,148,136,0.35)]",
  red: "shadow-[0_12px_40px_-16px_rgba(239,68,68,0.25)]",
  amber: "shadow-[0_12px_40px_-16px_rgba(245,158,11,0.2)]",
  sky: "shadow-[0_12px_40px_-16px_rgba(14,165,233,0.2)]",
};

export default function KpiCard({ icon: Icon, label, value, color = "slate", testid }) {
  const accent = ACCENTS[color] || ACCENTS.slate;
  const glow = GLOW[color] || "";
  return (
    <motion.div
      data-testid={testid}
      whileHover={{ y: -2 }}
      className={`relative overflow-hidden rounded-2xl border border-border bg-card p-5 text-card-foreground transition-shadow ${glow}`}
    >
      <div className="flex items-center justify-between gap-2">
        <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-lg border ${accent}`}>
          <Icon size={18} />
        </div>
        <span className="text-[11px] font-semibold uppercase tracking-widest text-muted-foreground text-right">
          {label}
        </span>
      </div>
      <div className="mt-4 font-mono text-3xl font-bold text-[#0A2540] sm:text-4xl">
        <CountUp value={value ?? 0} />
      </div>
    </motion.div>
  );
}
