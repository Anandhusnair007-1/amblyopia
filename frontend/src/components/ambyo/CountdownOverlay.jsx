import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { speak, NARRATION } from "@/core/audio/AudioGuide";

/**
 * Beautiful 3-2-1 countdown overlay with TTS.
 * Props: from (int, default 3), lang, onDone()
 */
export default function CountdownOverlay({ from = 3, lang = "en", onDone, label = "Get ready" }) {
  const [n, setN] = useState(from);
  const words = NARRATION.countdown[lang] || NARRATION.countdown.en;

  useEffect(() => {
    let cancelled = false;
    const word = n > 0 ? words[words.length - 1 - n] : words[words.length - 1];
    speak(word, { lang, key: "countdown" });
    const t = setTimeout(() => {
      if (cancelled) return;
      if (n <= 0) onDone?.();
      else setN((x) => x - 1);
    }, 900);
    return () => { cancelled = true; clearTimeout(t); };
  }, [n, lang, onDone, words]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-[#0A0F1C]/80 backdrop-blur-xl">
      <div className="absolute top-24 left-1/2 -translate-x-1/2 text-center">
        <p className="text-xs uppercase tracking-[0.4em] text-teal-300 font-bold">{label}</p>
      </div>
      <AnimatePresence mode="wait">
        <motion.div
          key={n}
          initial={{ scale: 0.6, opacity: 0, rotate: -8 }}
          animate={{ scale: 1, opacity: 1, rotate: 0 }}
          exit={{ scale: 2, opacity: 0, rotate: 6 }}
          transition={{ type: "spring", stiffness: 160, damping: 16 }}
          className="relative"
        >
          <div className="absolute inset-0 rounded-full bg-teal-400/20 blur-3xl scale-150" />
          <div className="relative font-mono text-[14rem] font-bold leading-none bg-gradient-to-br from-teal-200 to-sky-400 bg-clip-text text-transparent">
            {n > 0 ? n : "GO"}
          </div>
        </motion.div>
      </AnimatePresence>
    </div>
  );
}
