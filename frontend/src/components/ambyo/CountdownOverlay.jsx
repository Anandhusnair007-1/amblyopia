import { useEffect, useRef, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { speak, NARRATION } from "@/core/audio/AudioGuide";

/**
 * 3-2-1 countdown overlay with TTS.
 *
 * Z-index ladder (test runner): viewport="window" uses `fixed inset-0 z-50`.
 * The overlay is pointer-events-none, so Back/Home stay clickable even while the
 * countdown is visible.
 */
export default function CountdownOverlay({
  from = 3,
  lang = "en",
  onDone,
  label = "Get ready",
  viewport = "stage",
}) {
  const [n, setN] = useState(from);
  const words = NARRATION.countdown[lang] || NARRATION.countdown.en;
  const onDoneRef = useRef(onDone);

  useEffect(() => {
    onDoneRef.current = onDone;
  }, [onDone]);

  useEffect(() => {
    let cancelled = false;
    const word = n > 0 ? words[words.length - 1 - n] : words[words.length - 1];
    speak(word, { lang, key: "countdown" });
    const t = setTimeout(() => {
      if (cancelled) return;
      if (n <= 0) onDoneRef.current?.();
      else setN((x) => x - 1);
    }, 900);
    return () => { cancelled = true; clearTimeout(t); };
  }, [n, lang, words]);

  const positionCls =
    viewport === "window"
      ? "fixed inset-0 z-50"
      : "absolute inset-0 z-50";

  return (
    <div
      role="presentation"
      aria-hidden
      className={`${positionCls} pointer-events-none flex items-center justify-center`}
    >
      <div className="pointer-events-none absolute inset-0 bg-[#0A0F1C]/75 backdrop-blur-2xl" />
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute -top-40 -right-40 h-[42rem] w-[42rem] rounded-full bg-teal-500/10 blur-3xl" />
        <div className="absolute -bottom-40 -left-40 h-[34rem] w-[34rem] rounded-full bg-sky-500/10 blur-3xl" />
      </div>
      <div className="pointer-events-none absolute left-1/2 top-[calc(var(--test-topbar-height,5.5rem)+1rem)] -translate-x-1/2 text-center">
        <p className="text-xs font-semibold tracking-wide text-teal-300">{label}</p>
      </div>
      <AnimatePresence mode="wait">
        <motion.div
          key={n}
          initial={{ scale: 0.6, opacity: 0, rotate: -8 }}
          animate={{ scale: 1, opacity: 1, rotate: 0 }}
          exit={{ scale: 2, opacity: 0, rotate: 6 }}
          transition={{ type: "spring", stiffness: 160, damping: 16 }}
          className="relative pointer-events-none"
        >
          <div className="absolute inset-0 rounded-full bg-teal-400/20 blur-3xl scale-150" />
          <div className="relative font-mono text-[min(56vw,18rem)] sm:text-[18rem] font-extrabold leading-none bg-gradient-to-br from-teal-100 to-sky-300 bg-clip-text text-transparent drop-shadow-[0_0_40px_rgba(45,212,191,0.15)]">
            {n > 0 ? n : "GO"}
          </div>
        </motion.div>
      </AnimatePresence>
    </div>
  );
}
