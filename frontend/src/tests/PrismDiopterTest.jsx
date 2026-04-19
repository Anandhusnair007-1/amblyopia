import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { api } from "@/core/auth/AuthStore";
import { motion } from "framer-motion";
import { Ruler } from "lucide-react";
import { speak } from "@/core/audio/AudioGuide";
import { useI18n } from "@/core/i18n/translations";

// Prism Diopter is pure calculation — no camera
export default function PrismDiopterTest({ onComplete }) {
  const { sessionId } = useParams();
  const { lang } = useI18n();
  const [maxPd, setMaxPd] = useState(null);
  const [error, setError] = useState(false);

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        const r = await api.get(`/sessions/${sessionId}`);
        if (!mounted) return;
        const gaze = (r.data.results || []).find((x) => x.test_name === "gaze");
        const maxDev = gaze?.details?.max_deviation_pd ?? 0;
        setMaxPd(maxDev);
        speak(`Prism measurement: ${maxDev.toFixed(1)} prism diopters.`, { lang });
        const normalized = Math.max(0, Math.min(1, maxDev / 30));
        setTimeout(() => onComplete({
          raw_score: +maxDev.toFixed(2), normalized_score: +normalized.toFixed(3),
          details: { max_prism_diopters: +maxDev.toFixed(2), derived_from: "gaze", per_direction: gaze?.details?.per_direction || {} },
        }), 1600);
      } catch (e) {
        setError(true);
        setTimeout(() => onComplete({ raw_score: 0, normalized_score: 0, details: { error: true } }), 800);
      }
    })();
    return () => { mounted = false; };
  }, [sessionId, onComplete, lang]);

  return (
    <div className="relative flex-1 flex items-center justify-center px-6">
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute inset-0 scan-grid opacity-20" />
        <div className="absolute -top-40 left-1/2 -translate-x-1/2 w-[40rem] h-[40rem] rounded-full bg-amber-400/10 blur-3xl" />
      </div>
      <motion.div initial={{ y: 12, opacity: 0 }} animate={{ y: 0, opacity: 1 }} className="relative text-center">
        <div className="w-24 h-24 mx-auto rounded-3xl bg-amber-500/15 text-amber-300 flex items-center justify-center">
          <Ruler size={44} />
        </div>
        <p className="mt-5 text-xs uppercase tracking-[0.35em] text-amber-400 font-bold">Prism Diopter</p>
        <h2 className="mt-2 text-3xl sm:text-4xl font-bold text-white tracking-tight">Δ = 100 × tan(θ)</h2>
        <p className="mt-3 text-slate-400 text-sm">Derived from your gaze-tracking results. No camera needed.</p>
        {maxPd != null && (
          <motion.div
            initial={{ scale: 0.6, opacity: 0 }} animate={{ scale: 1, opacity: 1 }}
            className="mt-10 inline-block"
          >
            <div className="font-mono text-7xl font-bold bg-gradient-to-br from-amber-200 to-amber-500 bg-clip-text text-transparent">
              {maxPd.toFixed(1)}
            </div>
            <div className="mt-1 text-sm text-slate-500 uppercase tracking-[0.3em]">Prism Diopters (Δ)</div>
          </motion.div>
        )}
        {error && <p className="mt-3 text-red-400 text-sm">Gaze data unavailable</p>}
      </motion.div>
    </div>
  );
}
