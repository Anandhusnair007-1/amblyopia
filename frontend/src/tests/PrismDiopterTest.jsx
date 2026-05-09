import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import TestStage from "@/tests/TestStage";
import { speak } from "@/core/audio/AudioGuide";
import { useI18n } from "@/core/i18n/translations";
import { Ruler, EyeOff, ShieldCheck, ArrowRight, CheckCircle2 } from "lucide-react";

/**
 * PrismDiopterTest — independent cover-test simulation.
 *
 * Flow:
 * 1) Look at the dot, cover LEFT eye (measure RIGHT eye fixation)
 * 2) Look at the dot, cover RIGHT eye (measure LEFT eye fixation)
 * 3) Compute fixation shift between the two captures using iris landmarks.
 *
 * Angle estimate:
 *   angle_deg ≈ (shift_px / image_width_px) * camera_fov_deg
 * Prism diopters:
 *   PD = 100 * tan(angle_deg)
 */
export default function PrismDiopterTest({ patient, onComplete, flowIndex, flowTotal, flowLabels }) {
  const { lang } = useI18n();
  const age = patient?.age ?? 8;

  const [step, setStep] = useState("cover_left_intro");
  // cover_left_intro -> cover_left_capture -> cover_right_intro -> cover_right_capture -> analyzing -> done
  const finishedRef = useRef(false);
  const captureStartRef = useRef(0);
  const rightEyeSamplesRef = useRef([]); // when LEFT eye is covered
  const leftEyeSamplesRef = useRef([]);  // when RIGHT eye is covered

  const resetCapture = () => {
    captureStartRef.current = performance.now();
    if (step.startsWith("cover_left")) rightEyeSamplesRef.current = [];
    if (step.startsWith("cover_right")) leftEyeSamplesRef.current = [];
  };

  const thresholds = useMemo(
    () => ({
      normal: 5,     // PD
      mild: 10,
      moderate: 15,
    }),
    []
  );

  const classifyRisk = (pd) => {
    const v = Math.abs(pd || 0);
    if (v >= thresholds.moderate) return "urgent";
    if (v >= thresholds.mild) return "moderate";
    if (v >= thresholds.normal) return "mild";
    return "normal";
  };

  const median = (arr) => {
    const a = arr.filter((x) => Number.isFinite(x)).sort((x, y) => x - y);
    if (!a.length) return 0;
    const m = Math.floor(a.length / 2);
    return a.length % 2 ? a[m] : (a[m - 1] + a[m]) / 2;
  };

  const irisCenterNorm = (landmarks, indices) => {
    let sx = 0, sy = 0;
    for (const i of indices) {
      sx += landmarks[i].x;
      sy += landmarks[i].y;
    }
    return { x: sx / indices.length, y: sy / indices.length };
  };

  const toPx = (p, w, h) => ({ x: p.x * w, y: p.y * h });

  const irisDiameterPx = (landmarks, indices, w, h) => {
    let max = 0;
    for (let a = 0; a < indices.length; a++) {
      const pa = toPx(landmarks[indices[a]], w, h);
      for (let b = a + 1; b < indices.length; b++) {
        const pb = toPx(landmarks[indices[b]], w, h);
        const d = Math.hypot(pa.x - pb.x, pa.y - pb.y);
        if (d > max) max = d;
      }
    }
    return max || null;
  };

  const onFaceData = useCallback(
    (face) => {
      if (!face?.landmarks || finishedRef.current) return;
      if (step !== "cover_left_capture" && step !== "cover_right_capture") return;
      const lm = face.landmarks;
      if (lm.length < 478) return;

      // Capture for ~900ms; aggregate median.
      const now = performance.now();
      const elapsed = now - (captureStartRef.current || now);

      const leftIris = irisCenterNorm(lm, [468, 469, 470, 471, 472]);
      const rightIris = irisCenterNorm(lm, [473, 474, 475, 476, 477]);

      // Prefer the iris of the uncovered eye, but we can’t reliably detect coverage.
      // So we capture only the "target" eye each step:
      if (step === "cover_left_capture") {
        // left eye covered -> measure right eye
        rightEyeSamplesRef.current.push({
          x: rightIris.x,
          y: rightIris.y,
          w: face.imageWidthPx,
          h: face.imageHeightPx,
          irisDiamPx: irisDiameterPx(lm, [473, 474, 475, 476, 477], face.imageWidthPx, face.imageHeightPx),
        });
      } else {
        // right eye covered -> measure left eye
        leftEyeSamplesRef.current.push({
          x: leftIris.x,
          y: leftIris.y,
          w: face.imageWidthPx,
          h: face.imageHeightPx,
          irisDiamPx: irisDiameterPx(lm, [468, 469, 470, 471, 472], face.imageWidthPx, face.imageHeightPx),
        });
      }

      if (elapsed < 900) return;

      if (step === "cover_left_capture") setStep("cover_right_intro");
      else setStep("analyzing");
    },
    [step]
  );

  useEffect(() => {
    // Step narration
    if (step === "cover_left_intro") {
      speak("Cover the left eye. Keep looking at the dot with the other eye. Then tap Capture.", { lang });
    } else if (step === "cover_right_intro") {
      speak("Now cover the right eye. Keep looking at the dot. Then tap Capture.", { lang });
    }
  }, [step, lang]);

  const startCapture = () => {
    if (step === "cover_left_intro") {
      setStep("cover_left_capture");
      resetCapture();
      return;
    }
    if (step === "cover_right_intro") {
      setStep("cover_right_capture");
      resetCapture();
    }
  };

  const finish = useCallback(() => {
    if (finishedRef.current) return;
    finishedRef.current = true;

    const rs = rightEyeSamplesRef.current;
    const ls = leftEyeSamplesRef.current;
    if (!rs.length || !ls.length) {
      onComplete?.({
        raw_score: 0,
        normalized_score: 0,
        details: { error: true, reason: "insufficient_samples", rightSamples: rs.length, leftSamples: ls.length },
      });
      return;
    }

    // Median normalized iris centers per capture
    const rX = median(rs.map((s) => s.x));
    const rY = median(rs.map((s) => s.y));
    const lX = median(ls.map((s) => s.x));
    const lY = median(ls.map((s) => s.y));

    // Use the most common (latest) frame geometry
    const w = rs[rs.length - 1].w || ls[ls.length - 1].w || 640;
    const h = rs[rs.length - 1].h || ls[ls.length - 1].h || 480;

    const shiftNorm = Math.hypot(rX - lX, rY - lY);
    const shiftPx = shiftNorm * Math.max(w, h);

    // Approx camera HFOV — keep consistent with distance estimator default.
    const cameraFovDeg = 60;
    const angleDeg = (shiftPx / Math.max(w, 1)) * cameraFovDeg;
    const estimatedPD = 100 * Math.tan((angleDeg * Math.PI) / 180);
    const risk = classifyRisk(estimatedPD);

    const normalized = Math.max(0, Math.min(1, Math.abs(estimatedPD) / 30));
    speak(`Prism measurement complete.`, { lang });
    onComplete?.({
      raw_score: +estimatedPD.toFixed(2),
      normalized_score: +normalized.toFixed(3),
      details: {
        // requested outputs
        estimatedPD: +estimatedPD.toFixed(2),
        asymmetry: +Math.abs(estimatedPD).toFixed(2),
        risk,
        // capture details
        rightEyeFixation: { x: +rX.toFixed(4), y: +rY.toFixed(4) },
        leftEyeFixation: { x: +lX.toFixed(4), y: +lY.toFixed(4) },
        shiftPx: +shiftPx.toFixed(2),
        angleDeg: +angleDeg.toFixed(3),
        samples: { right: rs.length, left: ls.length },
      },
    });
  }, [classifyRisk, lang, onComplete]);

  useEffect(() => {
    if (step === "analyzing") {
      const t = setTimeout(() => {
        setStep("done");
        finish();
      }, 350);
      return () => clearTimeout(t);
    }
  }, [step, finish]);

  const title =
    step.startsWith("cover_left") ? "Cover test · Left eye covered" :
    step.startsWith("cover_right") ? "Cover test · Right eye covered" :
    step === "analyzing" ? "Analyzing" :
    "Prism Diopter";

  const sub =
    step.endsWith("_intro")
      ? "Cover one eye and keep looking at the dot."
      : step.endsWith("_capture")
        ? "Hold steady for a moment…"
        : step === "analyzing"
          ? "Computing deviation…"
          : "Complete";

  return (
    <TestStage
      testId="prism"
      distanceRange={[40, 60]}
      age={age}
      onFaceData={onFaceData}
      progress={flowTotal ? { index: flowIndex || 0, total: flowTotal, labels: flowLabels || [] } : null}
    >
      {({ distance }) => (
        <div className="relative min-h-0 flex-1 overflow-hidden">
          <div className="pointer-events-none absolute inset-0">
            <div className="absolute inset-0 scan-grid opacity-15" />
            <div className="absolute -top-40 left-1/2 -translate-x-1/2 w-[42rem] h-[42rem] rounded-full bg-amber-400/10 blur-3xl" />
          </div>

          {/* Fixation target */}
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="relative">
              <div className="w-4 h-4 rounded-full bg-white shadow-[0_0_40px_10px_rgba(255,255,255,0.25)]" />
              <div className="absolute inset-0 rounded-full border-2 border-amber-300/60 animate-pulse-ring" />
            </div>
          </div>

          {/* Header card */}
          <div className="absolute left-1/2 top-14 z-30 w-[calc(100%-2rem)] max-w-lg -translate-x-1/2">
            <motion.div
              initial={{ y: 10, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              className="rounded-3xl border border-white/10 bg-[#0A0F1C]/70 backdrop-blur-xl p-5 text-slate-100 shadow-2xl"
            >
              <div className="flex items-start justify-between gap-4">
                <div className="min-w-0">
                  <div className="flex items-center gap-2 text-xs uppercase tracking-[0.3em] text-amber-300 font-bold">
                    <Ruler size={14} /> Prism Diopter
                  </div>
                  <h2 className="mt-2 text-xl font-bold tracking-tight">{title}</h2>
                  <p className="mt-1 text-sm text-slate-300">{sub}</p>
                  {distance != null && (
                    <p className="mt-2 text-[11px] text-slate-400">
                      Distance: <span className="font-mono text-slate-200">{Math.round(distance)} cm</span>
                    </p>
                  )}
                </div>
                <div className="shrink-0 rounded-2xl bg-amber-500/15 p-3 text-amber-300">
                  <EyeOff size={22} />
                </div>
              </div>

              <AnimatePresence mode="wait">
                {step.endsWith("_intro") && (
                  <motion.div
                    key={step}
                    initial={{ opacity: 0, y: 8 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -6 }}
                    className="mt-4 flex flex-col gap-3"
                  >
                    <div className="rounded-2xl border border-white/10 bg-white/5 p-3 text-xs text-slate-300 leading-relaxed">
                      <div className="flex items-center gap-2 text-slate-200 font-semibold">
                        <ShieldCheck size={14} /> Instructions
                      </div>
                      <ul className="mt-2 space-y-1.5">
                        <li>- Keep your head still.</li>
                        <li>- Look at the dot.</li>
                        <li>- Cover one eye fully with your palm (no peeking).</li>
                      </ul>
                    </div>
                    <button
                      type="button"
                      data-testid="prism-capture"
                      onClick={startCapture}
                      className="inline-flex items-center justify-center gap-2 rounded-2xl bg-amber-400 px-5 py-3 font-bold text-[#0A0F1C] shadow-lg hover:bg-amber-300 active:scale-[0.99] transition-all"
                    >
                      Capture <ArrowRight size={16} />
                    </button>
                  </motion.div>
                )}

                {step.endsWith("_capture") && (
                  <motion.div
                    key={step}
                    initial={{ opacity: 0, y: 8 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0 }}
                    className="mt-4 rounded-2xl border border-white/10 bg-white/5 p-3 text-sm text-slate-200"
                  >
                    Capturing… hold steady for 1 second.
                  </motion.div>
                )}

                {step === "done" && (
                  <motion.div
                    key="done"
                    initial={{ opacity: 0, y: 8 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="mt-4 flex items-center gap-2 rounded-2xl border border-emerald-500/30 bg-emerald-500/10 p-3 text-sm text-emerald-200"
                  >
                    <CheckCircle2 size={16} /> Measurement recorded.
                  </motion.div>
                )}
              </AnimatePresence>
            </motion.div>
          </div>
        </div>
      )}
    </TestStage>
  );
}
