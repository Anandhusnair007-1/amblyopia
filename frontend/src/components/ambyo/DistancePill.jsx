import { motion } from "framer-motion";

/**
 * Floating pill indicator for real-time distance.
 * status: "good" | "too_close" | "move_closer" | "face_camera"
 */
export default function DistancePill({ distanceCm, status = "face_camera", label }) {
  const styles = {
    good: "bg-emerald-50 text-emerald-700 border-emerald-200",
    too_close: "bg-red-50 text-red-700 border-red-200",
    move_closer: "bg-amber-50 text-amber-700 border-amber-200",
    face_camera: "bg-slate-800/80 text-slate-100 border-slate-600",
  };
  const icon = {
    good: "●",
    too_close: "←",
    move_closer: "→",
    face_camera: "◎",
  }[status];

  return (
    <motion.div
      initial={{ y: -8, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.3 }}
      data-testid="distance-pill"
      className={`inline-flex items-center gap-2 px-4 py-2 rounded-full text-sm font-semibold border shadow-lg backdrop-blur-xl ${styles[status]}`}
    >
      <span className="text-base">{icon}</span>
      {distanceCm != null ? (
        <span className="font-mono tabular-nums">{Math.round(distanceCm)} cm</span>
      ) : (
        <span className="opacity-80">—</span>
      )}
      <span className="opacity-90">{label}</span>
    </motion.div>
  );
}

export function distanceStatus(d, [min, max]) {
  if (d == null) return "face_camera";
  if (d < min) return "too_close";
  if (d > max) return "move_closer";
  return "good";
}
