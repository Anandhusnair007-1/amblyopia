import { useState, useRef, useEffect, useCallback } from "react";
import TestStage from "@/tests/TestStage";
import { recognizeOnce, speechLangFor } from "@/core/voice/SpeechEngine";
import { parseDirection } from "@/core/voice/MultilingualParser";
import { useI18n } from "@/core/i18n/translations";
import MicIndicator from "@/components/ambyo/MicIndicator";
import { speak } from "@/core/audio/AudioGuide";
import { motion, AnimatePresence } from "framer-motion";
import { Check, X, Mic } from "lucide-react";

const DIRS = ["up", "right", "down", "left"];
const LINES = [
  { den: 60, size: 220 }, { den: 36, size: 170 }, { den: 24, size: 130 },
  { den: 18, size: 100 }, { den: 12, size: 72 },  { den: 9, size: 56 }, { den: 6, size: 42 },
];

function TumblingE({ dir = "up", size = 220, color = "#FFFFFF" }) {
  const rot = { up: 270, right: 0, down: 90, left: 180 }[dir];
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" style={{ transform: `rotate(${rot}deg)` }}>
      <g fill={color}>
        <rect x="15" y="15" width="70" height="14" /><rect x="15" y="15" width="14" height="70" />
        <rect x="15" y="43" width="55" height="14" /><rect x="15" y="71" width="70" height="14" />
      </g>
    </svg>
  );
}

const LEA = [{ e: "🍎" }, { e: "🏠" }, { e: "●" }, { e: "■" }];

export default function VisualAcuityTest({ patient, onComplete }) {
  const { lang } = useI18n();
  const age = patient?.age ?? 8;
  const profile = age <= 4 ? "A" : age <= 7 ? "B" : "C";
  const [lineIdx, setLineIdx] = useState(0);
  const [errors, setErrors] = useState(0);
  const [passedLines, setPassedLines] = useState([]);
  const [dirAnswer, setDirAnswer] = useState(null);
  const [listening, setListening] = useState(false);
  const [transcript, setTranscript] = useState("");
  const [displayDir, setDisplayDir] = useState("up");
  const currentDirRef = useRef("up");
  const finishedRef = useRef(false);

  const pickDir = useCallback(() => {
    const d = DIRS[Math.floor(Math.random() * DIRS.length)];
    currentDirRef.current = d;
    setDisplayDir(d);
  }, []);

  useEffect(() => { pickDir(); }, [lineIdx, pickDir]);

  const listen = async () => {
    if (listening) return;
    setListening(true);
    setTranscript("");
    const r = await recognizeOnce({ lang: speechLangFor(lang), listenMs: 7000 });
    setTranscript(r.transcript);
    setListening(false);
    const parsed = parseDirection(r.transcript);
    if (parsed) onAnswer(parsed);
  };

  const onAnswer = (ans) => {
    if (finishedRef.current) return;
    const correct = ans === currentDirRef.current;
    setDirAnswer({ ans, correct });
    setTimeout(() => {
      setDirAnswer(null);
      if (correct) {
        setPassedLines((p) => [...p, LINES[lineIdx].den]);
        setErrors(0);
        const next = lineIdx + 1;
        if (next >= LINES.length) finish(LINES[lineIdx].den);
        else setLineIdx(next);
      } else {
        const e = errors + 1;
        setErrors(e);
        if (e >= 2) finish(LINES[Math.max(0, lineIdx - 1)].den);
        else pickDir();
      }
    }, 550);
  };

  const finish = (finalDen) => {
    finishedRef.current = true;
    const normalized = Math.max(0, Math.min(1, 6 / finalDen));
    speak(`Vision recorded as six over ${finalDen}.`, { lang });
    setTimeout(() => onComplete({
      raw_score: finalDen, normalized_score: normalized,
      details: { snellen_denominator: finalDen, snellen_label: `6/${finalDen}`, profile, age, passed_lines: passedLines },
    }), 900);
  };

  const line = LINES[lineIdx];

  return (
    <TestStage testId="visual_acuity" distanceRange={[35, 45]} age={age}>
      {({ ready }) => (
        <div className="flex-1 flex flex-col items-center justify-center px-4 py-24 relative">
          <div className="absolute top-24 left-1/2 -translate-x-1/2 text-center">
            <p className="text-xs uppercase tracking-[0.3em] text-sky-400 font-bold">Visual Acuity · 6/{line.den}</p>
            <h2 className="mt-2 text-xl sm:text-2xl font-bold text-white">
              {profile === "A" ? "Point to the picture" : "Which way is the E pointing?"}
            </h2>
          </div>

          <AnimatePresence mode="wait">
            <motion.div
              key={`${lineIdx}-${displayDir}`}
              initial={{ scale: 0.92, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.9, opacity: 0 }}
              transition={{ duration: 0.35 }}
            >
              {profile === "A"
                ? <div className="text-white" style={{ fontSize: line.size }}>{LEA[lineIdx % LEA.length].e}</div>
                : <TumblingE dir={displayDir} size={line.size} />}
            </motion.div>
          </AnimatePresence>

          {dirAnswer && (
            <motion.div
              initial={{ scale: 0.5, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              className={`absolute top-1/2 text-8xl ${dirAnswer.correct ? "text-emerald-400" : "text-red-400"}`}
            >
              {dirAnswer.correct ? <Check size={96} /> : <X size={96} />}
            </motion.div>
          )}

          <div className="absolute bottom-20 left-1/2 -translate-x-1/2 flex flex-col items-center gap-4">
            <div className="grid grid-cols-3 gap-2">
              <div />
              <button data-testid="dir-up" onClick={() => onAnswer("up")} className="w-16 h-16 rounded-2xl bg-white/8 border border-white/15 text-white text-2xl hover:bg-white/15 active:scale-95 transition-all">↑</button>
              <div />
              <button data-testid="dir-left" onClick={() => onAnswer("left")} className="w-16 h-16 rounded-2xl bg-white/8 border border-white/15 text-white text-2xl hover:bg-white/15 active:scale-95 transition-all">←</button>
              <button
                data-testid="voice-btn"
                onClick={listen}
                className={`w-16 h-16 rounded-2xl flex items-center justify-center text-white transition-all ${listening ? "bg-sky-500 animate-pulse" : "bg-teal-500 hover:bg-teal-400"}`}
              ><Mic size={22} /></button>
              <button data-testid="dir-right" onClick={() => onAnswer("right")} className="w-16 h-16 rounded-2xl bg-white/8 border border-white/15 text-white text-2xl hover:bg-white/15 active:scale-95 transition-all">→</button>
              <div />
              <button data-testid="dir-down" onClick={() => onAnswer("down")} className="w-16 h-16 rounded-2xl bg-white/8 border border-white/15 text-white text-2xl hover:bg-white/15 active:scale-95 transition-all">↓</button>
              <div />
            </div>
            <MicIndicator active={listening} listening={listening} transcript={transcript} />
          </div>
        </div>
      )}
    </TestStage>
  );
}
