import { motion } from "framer-motion";
import {
  screeningResultRingFillPercent,
  screeningResultRingLabel,
} from "@/lib/referralCopy";

const COLORS = {
  normal: "#10B981",   // emerald
  mild: "#F59E0B",     // amber
  moderate: "#F97316", // orange
  urgent: "#EF4444",   // red
  incomplete: "#64748B", // slate
};

/**
 * @param {object} props
 * @param {number} [props.score] — 0–100; used when qualitative is false (doctor dashboard)
 * @param {string} [props.level] — normal | mild | moderate | urgent | incomplete
 * @param {boolean} [props.qualitative] — patient-facing: no numeric score, screening labels only
 */
export default function ScoreRing({
  score = 0,
  level = "normal",
  size = 180,
  stroke = 14,
  qualitative = false,
}) {
  const r = (size - stroke) / 2;
  const circ = 2 * Math.PI * r;
  const pct = qualitative
    ? screeningResultRingFillPercent(level)
    : Math.max(0, Math.min(100, score));
  const offset = circ * (1 - pct / 100);
  const color = COLORS[level] || COLORS.normal;
  const ringLabel = qualitative ? screeningResultRingLabel(level) : null;

  return (
    <motion.div
      className="relative inline-flex items-center justify-center"
      style={{ width: size, height: size }}
      data-testid="score-ring"
      data-qualitative={qualitative ? "true" : "false"}
    >
      <svg width={size} height={size} className="-rotate-90" aria-hidden>
        <circle cx={size / 2} cy={size / 2} r={r} stroke="#E2E8F0" strokeWidth={stroke} fill="none" />
        <motion.circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          stroke={color}
          strokeWidth={stroke}
          strokeLinecap="round"
          fill="none"
          strokeDasharray={circ}
          initial={{ strokeDashoffset: circ }}
          animate={{ strokeDashoffset: offset }}
          transition={{ duration: 1.2, ease: "easeOut" }}
        />
      </svg>
      <motion.div
        className="absolute inset-0 flex flex-col items-center justify-center px-3 text-center"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
      >
        {qualitative ? (
          <>
            <span className="text-sm font-bold uppercase tracking-wider" style={{ color }}>
              {ringLabel.line1}
            </span>
            <span className="text-xs font-semibold uppercase tracking-widest text-slate-500 mt-1">
              {ringLabel.line2}
            </span>
          </>
        ) : (
          <>
            <span className="font-mono text-4xl font-bold" style={{ color }}>
              {Math.round(pct)}
            </span>
            <span className="text-xs uppercase tracking-widest text-slate-500 mt-1">Health</span>
          </>
        )}
      </motion.div>
    </motion.div>
  );
}
