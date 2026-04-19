import { AlertTriangle } from "lucide-react";
import { motion } from "framer-motion";

export default function UrgentBanner({ findings = [] }) {
  return (
    <motion.div
      initial={{ y: -8, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.35 }}
      data-testid="urgent-banner"
      className="w-full rounded-2xl border border-red-200 bg-gradient-to-br from-red-50 to-red-100/60 p-5 sm:p-6 relative overflow-hidden"
    >
      <div className="absolute inset-y-0 left-0 w-1.5 bg-red-600 animate-pulse" />
      <div className="flex items-start gap-4 ml-3">
        <div className="shrink-0 w-10 h-10 rounded-full bg-red-600 text-white flex items-center justify-center shadow-md">
          <AlertTriangle size={20} />
        </div>
        <div className="flex-1">
          <h3 className="text-red-900 font-bold text-lg tracking-tight">Urgent Referral Required</h3>
          <p className="text-red-800/80 text-sm mt-0.5">Clinical thresholds exceeded. Immediate ophthalmology review recommended.</p>
          <ul className="mt-3 space-y-1.5">
            {findings.map((f, i) => (
              <li key={i} className="text-sm text-red-900 flex items-start gap-2">
                <span className="mt-1.5 w-1.5 h-1.5 rounded-full bg-red-600 shrink-0" />
                <span>{f}</span>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </motion.div>
  );
}
