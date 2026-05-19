// Shared "stage" wrapper used by every test.
// Handles: camera, face detection, distance pill, face-positioning gate, audio narration,
//          3-2-1 countdown, and reveals children only when "ready".
//
// Layer stack:
//   z-10 — camera feed
//   z-20 — test UI, face guide, distance HUD, intro controls
//   z-50 — viewport countdown overlay (pointer-events-none so top nav stays clickable)
import { useEffect, useRef, useState, useCallback } from "react";
import WebRTCCamera from "@/core/camera/WebRTCCamera";
import { loadLandmarker, detectFace, estimateDistanceCm, gazeRatios, normalizeAgeYears } from "@/core/camera/MediaPipeSetup";
import FaceGuide from "@/components/ambyo/FaceGuide";
import CountdownOverlay from "@/components/ambyo/CountdownOverlay";
import { speak, NARRATION, useAudioStore, primeSpeech } from "@/core/audio/AudioGuide";
import { useI18n } from "@/core/i18n/translations";
import TestProgressBar from "@/components/ambyo/TestProgressBar";
import ScreenCalibrationPanel from "@/components/ambyo/ScreenCalibrationPanel";
import { loadScreenCalibration } from "@/core/vision/ScreenCalibration";

/**
 * Props:
 *  - testId: "visual_acuity" | "gaze" | "hirschberg" | "prism" | "titmus" | "red_reflex"
 *  - distanceRange: [min, max]   (cm)
 *  - age: number   (for face-width calibration)
 *  - requireCamera: bool (default true). For prism we skip camera entirely.
 *  - requireStableDistance: bool (default true). Blocks manual start until distance is in range.
 *  - skipGate: bool — if true, reveal children immediately (no positioning gate / countdown)
 *  - onFaceData: (face, gaze) => void  — called every frame when face detected
 *  - cameraOutRef: optional ref object; .current is set to the HTMLVideoElement when the stream is ready (for tests that need the same camera as the stage, e.g. red reflex sampling).
 *  - children: (opts) => ReactNode
 *      opts = { ready, triggerCountdown, distance, cameraReady }
 */
export default function TestStage({
  testId,
  distanceRange = [35, 45],
  age = 8,
  requireCamera = true,
  requireStableDistance = true,
  skipGate = false,
  onFaceData,
  cameraOutRef,
  progress,
  children,
}) {
  const { lang, t } = useI18n();
  const { muted } = useAudioStore();
  const [landmarker, setLandmarker] = useState(null);
  const [landmarkerUnavailable, setLandmarkerUnavailable] = useState(false);
  const [distance, setDistance] = useState(null);
  const [cameraReady, setCameraReady] = useState(false);
  const [phase, setPhase] = useState(requireCamera && !skipGate ? "intro" : "active"); // intro | countdown | active
  const [goodHoldMs, setGoodHoldMs] = useState(0);
  const lastGoodTsRef = useRef(null);
  const introSpokenRef = useRef(false);
  const positionSpokenRef = useRef(null);
  const [faceDetected, setFaceDetected] = useState(false);
  const [calibration, setCalibration] = useState(() => loadScreenCalibration());

  useEffect(() => {
    if (!requireCamera) {
      setLandmarkerUnavailable(false);
      return;
    }
    loadLandmarker().then((lm) => {
      setLandmarker(lm);
      setLandmarkerUnavailable(!lm);
    });
  }, [requireCamera]);

  // Speak the intro narration once per test
  useEffect(() => {
    if (introSpokenRef.current) return;
    if (phase !== "intro" && phase !== "active") return;
    const script = NARRATION[testId]?.[lang] || NARRATION[testId]?.en;
    if (script) {
      primeSpeech();
      speak(script, { lang, key: `intro-${testId}` });
      introSpokenRef.current = true;
    }
  }, [testId, lang, phase]);

  // Spoken distance hints during intro (throttled)
  useEffect(() => {
    if (phase !== "intro" || !requireCamera || muted) return;
    const [min, max] = distanceRange;
    let key = "good";
    if (distance == null) key = "no_face";
    else if (distance < min) key = "too_close";
    else if (distance > max) key = "too_far";
    if (positionSpokenRef.current === key) return;
    positionSpokenRef.current = key;
    const script = NARRATION.positioning?.[key]?.[lang] || NARRATION.positioning?.[key]?.en;
    if (script) speak(script, { lang, key: `pos-${key}`, rate: 1.05 });
  }, [phase, distance, distanceRange, lang, muted, requireCamera]);

  // Frame callback — distance + gaze
  const onFrame = useCallback((video, ts) => {
    if (!landmarker) return;
    const face = detectFace(landmarker, video, ts);
    if (!face) {
      setFaceDetected(false);
      setDistance(null);
      lastGoodTsRef.current = null;
      setGoodHoldMs(0);
      return;
    }
    setFaceDetected(true);
    const d = estimateDistanceCm({
      faceBoxPx: face.faceBoxPx,
      imageWidthPx: face.imageWidthPx,
      ageYears: normalizeAgeYears(age, 8),
    });
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

  const triggerCountdown = useCallback(() => setPhase("countdown"), []);

  const countdownDone = useCallback(() => setPhase("active"), []);

  const ready = phase === "active";
  const [minDistance, maxDistance] = distanceRange;
  const distanceValid = !requireCamera || (distance != null && distance >= minDistance && distance <= maxDistance);
  const canManuallyStart = !requireStableDistance || distanceValid;

  return (
    <section className="relative z-20 h-full min-h-0 overflow-hidden">
      {requireCamera && (
        <WebRTCCamera
          onReady={(el) => {
            if (cameraOutRef) cameraOutRef.current = el;
            setCameraReady(true);
          }}
          onFrame={onFrame}
          hidden={phase === "active"}
          className={`absolute inset-0 z-10 h-full w-full ${
            phase !== "active" ? "rounded-none" : "p-4 sm:p-6"
          }`}
          mirrored
        />
      )}

      {/* Progress stepper (top) */}
      {progress && (
        <div className="pointer-events-none absolute left-0 right-0 top-0 z-30 px-4 pt-[calc(var(--test-topbar-height,5.5rem)+0.75rem)] sm:px-6">
          <div className="mx-auto w-full max-w-4xl">
            <div className="rounded-2xl border border-white/10 bg-[#0A0F1C]/55 px-4 py-3 shadow-lg backdrop-blur-xl">
              <TestProgressBar total={progress.total} index={progress.index} labels={progress.labels} />
            </div>
          </div>
        </div>
      )}

      {requireCamera && phase === "intro" && (
        <>
          <div className="pointer-events-none absolute inset-0 z-20 bg-gradient-to-b from-[#0A0F1C]/85 via-[#0A0F1C]/20 to-[#0A0F1C]/85" />
          <FaceGuide distanceCm={distance} range={distanceRange} visible />
          {/* Bottom sheet instructions */}
          <div className="pointer-events-none absolute inset-x-0 bottom-0 z-30 h-40 bg-gradient-to-t from-[#0A0F1C]/95 via-[#0A0F1C]/70 to-transparent" />
          <div className="pointer-events-auto absolute inset-x-0 bottom-0 z-40 px-4 pb-[max(1rem,env(safe-area-inset-bottom))] sm:px-6">
            <div className="mx-auto w-full max-w-lg">
              <div className="rounded-3xl border border-white/10 bg-[#0A0F1C]/80 p-5 shadow-2xl backdrop-blur-xl">
                <div className="flex items-start justify-between gap-4">
                  <div className="min-w-0">
                    <p className="text-[11px] font-bold uppercase tracking-[0.28em] text-teal-300">
                      {testLabel(testId, t)}
                    </p>
                    <p className="mt-2 text-sm text-slate-200">
                      {!cameraReady
                        ? t("starting_camera")
                        : landmarkerUnavailable
                          ? t("face_assist_unavailable")
                          : t("position_face_inside_oval")}
                    </p>
                    <p className="mt-2 text-xs text-slate-400">
                      {t("status")}:{" "}
                      <span className={faceDetected && distanceValid ? "text-emerald-300" : "text-amber-300"}>
                        {faceDetected ? (distanceValid ? t("face_detected") : t("position_face_inside_oval")) : t("no_face_detected")}
                      </span>
                    </p>
                    {testId === "visual_acuity" && (
                      <p className="mt-2 text-xs text-slate-400">
                        {calibration
                          ? "Screen calibration saved for this device."
                          : "Calibration missing: acuity will be stored as near-screen screening estimate only."}
                      </p>
                    )}
                  </div>
                  <button
                    data-testid="stage-start-manual"
                    onClick={triggerCountdown}
                    disabled={!canManuallyStart}
                    className="shrink-0 rounded-2xl bg-teal-500 px-5 py-3 text-sm font-extrabold text-[#0A0F1C] shadow-md transition-all hover:bg-teal-400 disabled:cursor-not-allowed disabled:opacity-45"
                  >
                    {t("start")}
                  </button>
                </div>
                {testId === "visual_acuity" && (
                  <div className="mt-4">
                    <ScreenCalibrationPanel onCalibrated={setCalibration} />
                  </div>
                )}
              </div>
            </div>
          </div>
        </>
      )}

      {phase === "countdown" && (
        <CountdownOverlay from={3} lang={lang} onDone={countdownDone} label={testLabel(testId, t)} viewport="window" />
      )}

      {ready && (
        <div className="relative z-20 flex h-full min-h-0 flex-col overflow-hidden">
          {/* Camera framing polish (CSS only) */}
          {requireCamera && (
            <div className="pointer-events-none absolute inset-0 z-10 p-4 sm:p-6">
              <div
                className={`h-full w-full rounded-[28px] border shadow-[0_0_0_1px_rgba(255,255,255,0.06)] transition-all ${
                  faceDetected
                    ? "border-emerald-400/40 shadow-[0_0_40px_4px_rgba(16,185,129,0.18)]"
                    : "border-red-400/35 shadow-[0_0_40px_4px_rgba(239,68,68,0.14)]"
                }`}
              />
            </div>
          )}
          {typeof children === "function"
            ? children({ ready, distance, distanceValid, cameraReady, muted, calibration })
            : children}
        </div>
      )}

      {/* Distance pill — scoped to stage viewport (not fixed to window) */}
      {ready && requireCamera && distance != null && (
        <div className="pointer-events-none absolute left-1/2 top-3 z-20 -translate-x-1/2 sm:top-4">
          <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-[#0A0F1C]/60 px-3 py-1.5 text-xs font-semibold text-slate-200 shadow-lg backdrop-blur-xl">
            <span className={`w-1.5 h-1.5 rounded-full ${
              distance < distanceRange[0] ? "bg-red-400" : distance > distanceRange[1] ? "bg-amber-400" : "bg-emerald-400"
            }`} />
            <span className="font-mono">{Math.round(distance)} cm</span>
          </div>
        </div>
      )}
    </section>
  );
}

function testLabel(id, t) {
  const key = {
    visual_acuity: "test_visual_acuity",
    gaze: "test_gaze",
    hirschberg: "test_hirschberg",
    prism: "test_prism",
    titmus: "test_titmus",
    red_reflex: "test_red_reflex",
    heidelberg: "test_heidelberg_proxy",
  }[id];
  return key ? t(key) : id;
}
