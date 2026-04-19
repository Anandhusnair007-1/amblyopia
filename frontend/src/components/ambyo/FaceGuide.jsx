import { motion } from "framer-motion";

/**
 * Full-screen face-positioning guide.
 * Props:
 *  - distanceCm: number | null
 *  - range: [min, max] cm
 *  - horizontalOffset: -1..1 (0 = centered)   (optional)
 *  - verticalOffset: -1..1 (0 = centered)     (optional)
 *  - visible: boolean
 * Renders a pulsing face oval outline + status text + directional arrows.
 */
export default function FaceGuide({
  distanceCm,
  range = [35, 45],
  horizontalOffset = 0,
  verticalOffset = 0,
  visible = true,
  onReady,
}) {
  if (!visible) return null;
  const [min, max] = range;
  const noFace = distanceCm == null;
  const tooClose = !noFace && distanceCm < min;
  const tooFar = !noFace && distanceCm > max;
  const good = !noFace && !tooClose && !tooFar;

  const statusColor = good ? "#10B981" : tooClose ? "#EF4444" : tooFar ? "#F59E0B" : "#94A3B8";
  const statusLabel = noFace ? "Face the camera" : tooClose ? "Too close" : tooFar ? "Move closer" : "Perfect";
  const delta = !noFace ? (good ? 0 : tooClose ? distanceCm - min : distanceCm - max) : null;

  return (
    <div className="pointer-events-none absolute inset-0 flex items-center justify-center z-10">
      {/* Pulsing face oval */}
      <motion.svg
        width="min(58vh, 400px)" height="min(75vh, 520px)" viewBox="0 0 400 520"
        initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }}
        className="overflow-visible"
      >
        <defs>
          <linearGradient id="faceStroke" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0" stopColor={statusColor} stopOpacity="0.9" />
            <stop offset="1" stopColor={statusColor} stopOpacity="0.3" />
          </linearGradient>
        </defs>
        <motion.ellipse
          cx="200" cy="260" rx="160" ry="220"
          fill="none"
          stroke="url(#faceStroke)"
          strokeWidth={good ? 3 : 2}
          strokeDasharray={good ? "0" : "6 8"}
          animate={{
            strokeWidth: good ? [3, 5, 3] : [2, 3, 2],
            opacity: good ? 1 : [0.5, 0.9, 0.5],
          }}
          transition={{ duration: 1.8, repeat: Infinity, ease: "easeInOut" }}
        />
        {/* corner marks */}
        {[[60, 60], [340, 60], [60, 460], [340, 460]].map(([x, y], i) => (
          <g key={i} stroke={statusColor} strokeWidth="3" strokeLinecap="round">
            <line x1={x - 14} y1={y} x2={x + 14} y2={y} />
            <line x1={x} y1={y - 14} x2={x} y2={y + 14} />
          </g>
        ))}
      </motion.svg>

      {/* Status badge */}
      <motion.div
        initial={{ y: 10, opacity: 0 }} animate={{ y: 0, opacity: 1 }}
        className="absolute top-24 left-1/2 -translate-x-1/2 flex flex-col items-center gap-2"
      >
        <div
          className="px-5 py-2 rounded-full text-sm font-bold shadow-2xl backdrop-blur-xl border-2 flex items-center gap-2"
          style={{ borderColor: statusColor, color: statusColor, background: "rgba(10, 15, 28, 0.6)" }}
        >
          <span className="relative flex w-2 h-2">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full opacity-75" style={{ background: statusColor }} />
            <span className="relative inline-flex rounded-full h-2 w-2" style={{ background: statusColor }} />
          </span>
          {statusLabel}
          {distanceCm != null && (
            <span className="font-mono ml-1.5 text-slate-300 text-xs">{Math.round(distanceCm)} cm</span>
          )}
        </div>
        {delta !== null && Math.abs(delta) >= 1 && (
          <div className="text-xs font-semibold" style={{ color: statusColor }}>
            {tooClose ? `↶ Move back ${Math.round(Math.abs(delta))} cm` : `↷ Move in ${Math.round(Math.abs(delta))} cm`}
          </div>
        )}
        <div className="text-[10px] uppercase tracking-widest text-slate-500 font-mono mt-0.5">
          Target: {min}–{max} cm
        </div>
      </motion.div>
    </div>
  );
}
