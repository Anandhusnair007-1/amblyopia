import { useEffect, useState, useRef } from "react";
import TestStage from "@/tests/TestStage";
import { motion, AnimatePresence } from "framer-motion";
import { speak } from "@/core/audio/AudioGuide";
import { useI18n } from "@/core/i18n/translations";

const DOTS = [
  { id: "center",    x: 0.5,  y: 0.5 },
  { id: "up",        x: 0.5,  y: 0.18 },
  { id: "down",      x: 0.5,  y: 0.82 },
  { id: "left",      x: 0.12, y: 0.5 },
  { id: "right",     x: 0.88, y: 0.5 },
  { id: "upLeft",    x: 0.12, y: 0.18 },
  { id: "upRight",   x: 0.88, y: 0.18 },
  { id: "downLeft",  x: 0.12, y: 0.82 },
  { id: "downRight", x: 0.88, y: 0.82 },
];
const FRAMES_PER_DOT = 10;

export default function GazeTest({ patient, onComplete }) {
  const { lang } = useI18n();
  const age = patient?.age ?? 8;
  const [step, setStep] = useState(0);
  const framesRef = useRef([]);
  const [readings, setReadings] = useState({});
  const [calibration, setCalibration] = useState(null);
  const finishedRef = useRef(false);

  const onFaceData = (_face, gaze) => {
    if (!gaze) return;
    if (framesRef.current.length < FRAMES_PER_DOT) framesRef.current.push(gaze.avg);
    if (framesRef.current.length === FRAMES_PER_DOT) {
      const dot = DOTS[step];
      if (dot) {
        const dx = framesRef.current.reduce((a, b) => a + b.dx, 0) / FRAMES_PER_DOT;
        const dy = framesRef.current.reduce((a, b) => a + b.dy, 0) / FRAMES_PER_DOT;
        setReadings((r) => ({ ...r, [dot.id]: { dx, dy } }));
        if (dot.id === "center" && !calibration) setCalibration({ dx, dy });
      }
    }
  };

  useEffect(() => {
    if (finishedRef.current) return;
    framesRef.current = [];
    const t = setTimeout(() => {
      if (step + 1 >= DOTS.length) finish();
      else setStep((s) => s + 1);
    }, 2200);
    return () => clearTimeout(t);
    // eslint-disable-next-line
  }, [step]);

  const finish = () => {
    finishedRef.current = true;
    const cal = calibration || readings.center || { dx: 0, dy: 0 };
    const perDir = {};
    let maxDev = 0;
    Object.entries(readings).forEach(([dir, r]) => {
      const ddx = r.dx - cal.dx, ddy = r.dy - cal.dy;
      const mag = Math.sqrt(ddx * ddx + ddy * ddy);
      const angleDeg = Math.min(45, mag * 50);
      const pd = 100 * Math.tan((angleDeg * Math.PI) / 180);
      perDir[dir] = { deviation_pd: +pd.toFixed(2), angle_deg: +angleDeg.toFixed(1), dx: +ddx.toFixed(3), dy: +ddy.toFixed(3) };
      if (dir !== "center" && pd > maxDev) maxDev = pd;
    });
    speak("Gaze tracking complete.", { lang });
    setTimeout(() => onComplete({
      raw_score: +maxDev.toFixed(2),
      normalized_score: Math.max(0, Math.min(1, maxDev / 40)),
      details: { per_direction: perDir, max_deviation_pd: +maxDev.toFixed(2), calibration: cal },
    }), 800);
  };

  const dot = DOTS[step];

  return (
    <TestStage testId="gaze" distanceRange={[40, 60]} age={age} onFaceData={onFaceData}>
      {() => (
        <div className="relative flex-1">
          <div className="absolute top-24 left-1/2 -translate-x-1/2 text-center pointer-events-none">
            <p className="text-xs uppercase tracking-[0.3em] text-sky-400 font-bold">Gaze · {step + 1} / 9</p>
            <p className="mt-1 text-slate-300 text-sm">Follow the dot with your eyes only</p>
          </div>
          <AnimatePresence mode="wait">
            {dot && (
              <motion.div
                key={dot.id}
                data-testid={`gaze-dot-${dot.id}`}
                initial={{ scale: 0.3, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                exit={{ scale: 0.3, opacity: 0 }}
                transition={{ type: "spring", stiffness: 300, damping: 22 }}
                className="absolute -translate-x-1/2 -translate-y-1/2"
                style={{ left: `${dot.x * 100}%`, top: `${dot.y * 100}%` }}
              >
                <div className="relative">
                  <div className="w-12 h-12 rounded-full bg-gradient-to-br from-teal-300 to-sky-500 shadow-[0_0_60px_12px_rgba(45,212,191,0.5)]" />
                  <div className="absolute inset-0 rounded-full border-2 border-teal-300/60 animate-pulse-ring" />
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      )}
    </TestStage>
  );
}
