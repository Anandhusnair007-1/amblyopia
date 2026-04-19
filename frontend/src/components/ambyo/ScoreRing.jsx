import { motion } from "framer-motion";

const COLORS = {
  normal: "#10B981",   // emerald
  mild: "#F59E0B",     // amber
  moderate: "#F97316", // orange
  urgent: "#EF4444",   // red
};

export default function ScoreRing({ score = 0, level = "normal", size = 180, stroke = 14 }) {
  const r = (size - stroke) / 2;
  const circ = 2 * Math.PI * r;
  const pct = Math.max(0, Math.min(100, score));
  const offset = circ * (1 - pct / 100);
  const color = COLORS[level] || COLORS.normal;

  return (
    <div className="relative inline-flex items-center justify-center" style={{ width: size, height: size }} data-testid="score-ring">
      <svg width={size} height={size} className="-rotate-90">
        <circle cx={size / 2} cy={size / 2} r={r} stroke="#E2E8F0" strokeWidth={stroke} fill="none" />
        <motion.circle
          cx={size / 2} cy={size / 2} r={r}
          stroke={color} strokeWidth={stroke} strokeLinecap="round" fill="none"
          strokeDasharray={circ}
          initial={{ strokeDashoffset: circ }}
          animate={{ strokeDashoffset: offset }}
          transition={{ duration: 1.2, ease: "easeOut" }}
        />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span className="font-mono text-4xl font-bold" style={{ color }}>{Math.round(pct)}</span>
        <span className="text-xs uppercase tracking-widest text-slate-500 mt-1">Health</span>
      </div>
    </div>
  );
}
