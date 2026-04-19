import { useEffect, useRef, useState } from "react";
import TestStage from "@/tests/TestStage";
import { speak } from "@/core/audio/AudioGuide";
import { useI18n } from "@/core/i18n/translations";

export default function HirschbergTest({ patient, onComplete }) {
  const { lang } = useI18n();
  const age = patient?.age ?? 8;
  const [phase, setPhase] = useState("capture"); // capture → analyzing
  const samplesRef = useRef([]);
  const finishedRef = useRef(false);

  const onFaceData = (_face, gaze) => {
    if (gaze && phase === "capture") samplesRef.current.push(gaze);
  };

  // Show a 2s white flash once TestStage goes "ready"
  useEffect(() => {
    const t = setTimeout(() => {
      if (finishedRef.current) return;
      setPhase("analyzing");
      const samples = samplesRef.current;
      if (samples.length === 0) {
        return onComplete({ raw_score: 0, normalized_score: 0, details: { displacement_mm: 0, samples: 0, note: "no samples" } });
      }
      let asym = 0;
      samples.forEach((s) => { asym += Math.abs(s.left.dx - s.right.dx); });
      asym /= samples.length;
      const displacement_mm = +(asym * 10).toFixed(2);
      const normalized = Math.max(0, Math.min(1, displacement_mm / 5));
      speak("Capture complete.", { lang });
      finishedRef.current = true;
      setTimeout(() => onComplete({
        raw_score: displacement_mm, normalized_score: normalized,
        details: { displacement_mm, samples: samples.length, avg_asymmetry: +asym.toFixed(4) },
      }), 800);
    }, 2000);
    return () => clearTimeout(t);
    // eslint-disable-next-line
  }, []);

  return (
    <TestStage testId="hirschberg" distanceRange={[30, 45]} age={age} onFaceData={onFaceData}>
      {() => (
        <div className="fixed inset-0 bg-white z-40 flex items-center justify-center">
          <div className="text-center">
            <div className="font-mono text-slate-500 text-xs uppercase tracking-widest">Capturing corneal reflex</div>
            <div className="mt-4 inline-block">
              <div className="w-16 h-16 rounded-full border-4 border-slate-300 border-t-slate-800 animate-spin" />
            </div>
          </div>
        </div>
      )}
    </TestStage>
  );
}
