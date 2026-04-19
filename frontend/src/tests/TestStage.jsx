// Shared "stage" wrapper used by every test.
// Handles: camera, face detection, distance pill, face-positioning gate, audio narration,
//          3-2-1 countdown, and reveals children only when "ready".
import { useEffect, useRef, useState, useCallback } from "react";
import WebRTCCamera from "@/core/camera/WebRTCCamera";
import { loadLandmarker, detectFace, estimateDistanceCm, gazeRatios } from "@/core/camera/MediaPipeSetup";
import FaceGuide from "@/components/ambyo/FaceGuide";
import CountdownOverlay from "@/components/ambyo/CountdownOverlay";
import { speak, NARRATION, useAudioStore } from "@/core/audio/AudioGuide";
import { useI18n } from "@/core/i18n/translations";

/**
 * Props:
 *  - testId: "visual_acuity" | "gaze" | "hirschberg" | "prism" | "titmus" | "red_reflex"
 *  - distanceRange: [min, max]   (cm)
 *  - age: number   (for face-width calibration)
 *  - requireCamera: bool (default true). For prism we skip camera entirely.
 *  - skipGate: bool — if true, reveal children immediately (no positioning gate / countdown)
 *  - onFaceData: (face, gaze) => void  — called every frame when face detected
 *  - children: (opts) => ReactNode
 *      opts = { ready, triggerCountdown, distance, cameraReady }
 */
export default function TestStage({
  testId,
  distanceRange = [35, 45],
  age = 8,
  requireCamera = true,
  skipGate = false,
  onFaceData,
  children,
}) {
  const { lang } = useI18n();
  const { muted } = useAudioStore();
  const [landmarker, setLandmarker] = useState(null);
  const [distance, setDistance] = useState(null);
  const [cameraReady, setCameraReady] = useState(false);
  const [phase, setPhase] = useState(requireCamera && !skipGate ? "intro" : "active"); // intro | countdown | active
  const [goodHoldMs, setGoodHoldMs] = useState(0);
  const lastGoodTsRef = useRef(null);
  const introSpokenRef = useRef(false);

  useEffect(() => {
    if (requireCamera) loadLandmarker().then(setLandmarker);
  }, [requireCamera]);

  // Speak the intro narration once per test
  useEffect(() => {
    if (introSpokenRef.current) return;
    if (phase !== "intro" && phase !== "active") return;
    const script = NARRATION[testId]?.[lang] || NARRATION[testId]?.en;
    if (script) { speak(script, { lang, key: `intro-${testId}` }); introSpokenRef.current = true; }
  }, [testId, lang, phase]);

  // Frame callback — distance + gaze
  const onFrame = useCallback((video, ts) => {
    if (!landmarker) return;
    const face = detectFace(landmarker, video, ts);
    if (!face) {
      setDistance(null);
      lastGoodTsRef.current = null;
      setGoodHoldMs(0);
      return;
    }
    const d = estimateDistanceCm({ faceBoxPx: face.faceBoxPx, imageWidthPx: face.imageWidthPx, ageYears: age });
    setDistance(d);
    if (onFaceData) {
      const g = gazeRatios(face.landmarks);
      onFaceData(face, g);
    }
    // Track how long we have been in the good zone
    const [min, max] = distanceRange;
    const good = d >= min && d <= max;
    const now = performance.now();
    if (good) {
      if (!lastGoodTsRef.current) lastGoodTsRef.current = now;
      setGoodHoldMs(now - lastGoodTsRef.current);
    } else {
      lastGoodTsRef.current = null;
      setGoodHoldMs(0);
    }
  }, [landmarker, age, distanceRange, onFaceData]);

  // Auto-advance intro → countdown once good-hold ≥ 1200ms
  useEffect(() => {
    if (phase !== "intro") return;
    if (goodHoldMs >= 1200) setPhase("countdown");
  }, [phase, goodHoldMs]);

  const triggerCountdown = () => setPhase("countdown");

  const countdownDone = () => setPhase("active");

  const ready = phase === "active";

  return (
    <div className="relative flex-1 flex flex-col">
      {requireCamera && (
        <WebRTCCamera
          onReady={() => setCameraReady(true)}
          onFrame={onFrame}
          hidden={phase === "active"}
          className="absolute inset-0 w-full h-full object-cover opacity-40"
          mirrored
        />
      )}

      {requireCamera && phase === "intro" && (
        <>
          <div className="absolute inset-0 bg-gradient-to-b from-[#0A0F1C]/95 via-[#0A0F1C]/80 to-[#0A0F1C]" />
          <FaceGuide distanceCm={distance} range={distanceRange} visible />
          <div className="absolute bottom-24 left-1/2 -translate-x-1/2 text-center px-6">
            <p className="text-xs uppercase tracking-[0.3em] text-teal-300 font-bold">{testLabel(testId)}</p>
            <p className="mt-2 text-slate-300 text-sm">
              {cameraReady ? "Position your face inside the oval. Test will start automatically." : "Starting camera…"}
            </p>
            <button
              data-testid="stage-start-manual"
              onClick={triggerCountdown}
              className="mt-4 px-5 py-2.5 rounded-xl bg-teal-500 text-[#0A0F1C] font-bold shadow-md hover:bg-teal-400 transition-all text-sm"
            >Start now</button>
          </div>
        </>
      )}

      {phase === "countdown" && (
        <CountdownOverlay from={3} lang={lang} onDone={countdownDone} label={testLabel(testId)} />
      )}

      {ready && children?.({ ready, distance, cameraReady, muted })}

      {/* Distance pill — visible during active phase too (mini) */}
      {ready && requireCamera && distance != null && (
        <div className="fixed top-24 left-1/2 -translate-x-1/2 z-20 pointer-events-none">
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-xs font-semibold border shadow-lg backdrop-blur-xl bg-[#0A0F1C]/60 border-white/10 text-slate-200">
            <span className={`w-1.5 h-1.5 rounded-full ${
              distance < distanceRange[0] ? "bg-red-400" : distance > distanceRange[1] ? "bg-amber-400" : "bg-emerald-400"
            }`} />
            <span className="font-mono">{Math.round(distance)} cm</span>
          </div>
        </div>
      )}
    </div>
  );
}

function testLabel(id) {
  return {
    visual_acuity: "Visual Acuity",
    gaze: "Gaze Detection",
    hirschberg: "Hirschberg",
    prism: "Prism Diopter",
    titmus: "Titmus Stereo",
    red_reflex: "Red Reflex",
  }[id] || id;
}
