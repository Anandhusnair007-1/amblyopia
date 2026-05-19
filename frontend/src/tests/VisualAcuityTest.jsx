import { useState, useRef, useEffect, useCallback } from "react";
import TestStage from "@/tests/TestStage";
import MonocularOccluder from "@/components/ambyo/MonocularOccluder";
import { recognizeOnce, speechLangFor, isSpeechRecognitionSupported } from "@/core/voice/SpeechEngine";
import { parseDirection } from "@/core/voice/MultilingualParser";
import { useI18n } from "@/core/i18n/translations";
import MicIndicator from "@/components/ambyo/MicIndicator";
import { speak, primeSpeech, waitForSpeechIdle } from "@/core/audio/AudioGuide";
import { motion, AnimatePresence } from "framer-motion";
import { Check, X, Mic } from "lucide-react";
import { toast } from "sonner";
import {
  getOptotypePxFromCalibration,
  estimatePpi,
  DEFAULT_TEST_DISTANCE_CM,
  SCREENING_ACUITY_MEASUREMENT_TYPE,
  SCREENING_ACUITY_DISCLAIMER,
} from "@/core/vision/SnellenChart";
import {
  SNELLEN_DENOMINATORS,
  acuityFromStaircase,
  interEyeLinesDiff,
  worseDenominator,
  screeningLineLabel,
  normalizedScoreFromDen,
} from "@/core/vision/AcuityEngine";
import { getAcuityProfile, isScorableAcuityProfile } from "@/core/vision/acuityProfiles";
import { getDeviceInfo } from "@/core/vision/ScreenCalibration";

const DIRS = ["up", "right", "down", "left"];

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

function AcuityRunPanel({
  ready,
  testingEye,
  distanceCm,
  distanceValid = true,
  calibration,
  onEyeComplete,
  onEyeUnclear,
}) {
  const { lang, t } = useI18n();
  const voiceOk = isSpeechRecognitionSupported();
  const [lineIdx, setLineIdx] = useState(0);
  const [errors, setErrors] = useState(0);
  const [passedLines, setPassedLines] = useState([]);
  const [dirAnswer, setDirAnswer] = useState(null);
  const [listening, setListening] = useState(false);
  const [transcript, setTranscript] = useState("");
  const [voiceHint, setVoiceHint] = useState("");
  const [displayDir, setDisplayDir] = useState("up");
  const currentDirRef = useRef("up");
  const finishedRef = useRef(false);
  const listenGenRef = useRef(0);
  const ppiRef = useRef(estimatePpi());

  const pickDir = useCallback(() => {
    const d = DIRS[Math.floor(Math.random() * DIRS.length)];
    currentDirRef.current = d;
    setDisplayDir(d);
  }, []);

  useEffect(() => {
    pickDir();
  }, [lineIdx, pickDir]);

  const finishEye = useCallback((finalDen) => {
    finishedRef.current = true;
    listenGenRef.current += 1;
    const den = finalDen;
    speak(`Screening vision recorded as approximately six over ${den}.`, { lang });
    setTimeout(() => {
      onEyeComplete({
        snellen_denominator: den,
        snellen_label: screeningLineLabel(den),
        screening_line_label: screeningLineLabel(den),
        passed_lines: passedLines,
        eye: testingEye,
        measurement_valid: true,
        test_status: "completed",
        result_state: "completed",
      });
    }, 700);
  }, [lang, onEyeComplete, passedLines, testingEye]);

  const onAnswer = useCallback((ans) => {
    if (finishedRef.current || !distanceValid) return;
    listenGenRef.current += 1;
    const correct = ans === currentDirRef.current;
    setDirAnswer({ ans, correct });
    setTimeout(() => {
      setDirAnswer(null);
      if (correct) {
        setPassedLines((p) => [...p, SNELLEN_DENOMINATORS[lineIdx]]);
        setErrors(0);
        const next = lineIdx + 1;
        if (next >= SNELLEN_DENOMINATORS.length) finishEye(SNELLEN_DENOMINATORS[lineIdx]);
        else setLineIdx(next);
      } else {
        setErrors((e) => {
          const nextE = e + 1;
          if (nextE >= 2) finishEye(acuityFromStaircase(lineIdx, nextE));
          else pickDir();
          return nextE;
        });
      }
    }, 550);
  }, [distanceValid, finishEye, lineIdx, pickDir]);

  const listen = useCallback(async ({ auto = false } = {}) => {
    if (listening || finishedRef.current || !distanceValid) return;
    if (!voiceOk) {
      if (!auto) toast.error(t("voice_not_supported"));
      return;
    }
    primeSpeech();
    const gen = ++listenGenRef.current;
    setListening(true);
    setTranscript("");
    setVoiceHint("");
    await waitForSpeechIdle(600);
    if (gen !== listenGenRef.current) return;

    const r = await recognizeOnce({ lang: speechLangFor(lang), listenMs: 9000, minListenMs: 900 });
    if (gen !== listenGenRef.current) return;

    setTranscript(r.transcript);
    setListening(false);

    if (!r.ok) {
      setVoiceHint(t("voice_try_again"));
      if (!auto) toast.message(t("voice_not_heard"));
      return;
    }

    const parsed = parseDirection(r.transcript);
    if (parsed) onAnswer(parsed);
    else {
      setVoiceHint(t("voice_say_direction"));
      if (!auto) toast.message(t("voice_say_direction"));
    }
  }, [listening, voiceOk, lang, t, onAnswer, distanceValid]);

  useEffect(() => {
    if (!ready || !distanceValid || dirAnswer || listening || finishedRef.current) return;
    let cancelled = false;
    const tmr = setTimeout(() => {
      if (!cancelled) listen({ auto: true });
    }, 700);
    return () => {
      cancelled = true;
      clearTimeout(tmr);
      listenGenRef.current += 1;
    };
  }, [ready, lineIdx, displayDir, dirAnswer, listening, listen, distanceValid]);

  const den = SNELLEN_DENOMINATORS[lineIdx];
  const dist = distanceCm ?? DEFAULT_TEST_DISTANCE_CM;
  const size = calibration
    ? getOptotypePxFromCalibration(dist, den, calibration)
    : getOptotypePxFromCalibration(dist, den, { px_per_mm: ppiRef.current / 25.4 });

  return (
    <motion.div layout className="relative flex min-h-0 flex-1 flex-col items-center justify-center px-4 py-24">
      <motion.div layout className="absolute top-24 left-1/2 -translate-x-1/2 text-center">
        <p className="text-xs uppercase tracking-[0.3em] text-sky-400 font-bold">
          {testingEye} · {t("visual_acuity_line", { den: String(den) })}
        </p>
        <h2 className="mt-2 text-xl sm:text-2xl font-bold text-white">
          {t("visual_acuity_prompt_e")}
        </h2>
        {voiceOk && (
          <p className="mt-2 text-sm text-slate-400">{t("voice_say_direction_short")}</p>
        )}
        <p className="mt-2 text-xs text-slate-500 max-w-sm mx-auto">
          {calibration ? "Calibrated near-screen screening estimate — not a clinic eye exam." : "Near-screen screening estimate only — not a clinic eye exam."}
        </p>
      </motion.div>

      {ready && !distanceValid && (
        <div className="absolute inset-x-4 top-40 z-30 rounded-2xl border border-amber-300 bg-amber-50 p-4 text-center text-sm font-semibold text-amber-900 shadow-xl">
          Move back to the guided distance and hold steady. Answers are paused while distance is unreliable.
        </div>
      )}

      <AnimatePresence mode="wait">
        <motion.div
          key={`${testingEye}-${lineIdx}-${displayDir}`}
          initial={{ scale: 0.92, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          exit={{ scale: 0.9, opacity: 0 }}
          transition={{ duration: 0.35 }}
        >
          <TumblingE dir={displayDir} size={size} />
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
        <motion.div layout className="grid grid-cols-3 gap-2">
          <motion.div layout />
          <motion.button layout data-testid="dir-up" onClick={() => onAnswer("up")} className="w-16 h-16 rounded-2xl bg-white/8 border border-white/15 text-white text-2xl hover:bg-white/15 active:scale-95 transition-all">↑</motion.button>
          <motion.div layout />
          <motion.button layout data-testid="dir-left" onClick={() => onAnswer("left")} className="w-16 h-16 rounded-2xl bg-white/8 border border-white/15 text-white text-2xl hover:bg-white/15 active:scale-95 transition-all">←</motion.button>
          {voiceOk ? (
            <motion.button
              layout
              data-testid="voice-btn"
              onClick={() => listen({ auto: false })}
              className={`w-16 h-16 rounded-2xl flex items-center justify-center text-white transition-all ${listening ? "bg-sky-500 animate-pulse" : "bg-teal-500 hover:bg-teal-400"}`}
            ><Mic size={22} /></motion.button>
          ) : (
            <motion.div layout className="w-16 h-16" />
          )}
          <motion.button layout data-testid="dir-right" onClick={() => onAnswer("right")} className="w-16 h-16 rounded-2xl bg-white/8 border border-white/15 text-white text-2xl hover:bg-white/15 active:scale-95 transition-all">→</motion.button>
          <motion.div layout />
          <motion.button layout data-testid="dir-down" onClick={() => onAnswer("down")} className="w-16 h-16 rounded-2xl bg-white/8 border border-white/15 text-white text-2xl hover:bg-white/15 active:scale-95 transition-all">↓</motion.button>
          <motion.div layout />
        </motion.div>
        <MicIndicator active={listening} listening={listening} transcript={transcript} hint={voiceHint} unsupported={!voiceOk} />
        <button
          type="button"
          data-testid="va-eye-unclear"
          onClick={onEyeUnclear}
          className="text-xs font-semibold text-amber-200 underline underline-offset-4"
        >
          Wrong or unclear eye covered
        </button>
      </div>
    </motion.div>
  );
}

function PictureAcuityUnavailable({ onContinue, age }) {
  return (
    <div className="absolute inset-0 z-50 flex flex-col items-center justify-center bg-[#0A0F1C]/95 px-6 text-center">
      <h2 className="text-xl font-bold text-white">Acuity screening not available here</h2>
      <p className="mt-3 text-sm text-slate-300 max-w-md leading-relaxed">
        Picture charts for very young children cannot be scored accurately on this device.
        Please continue other tests and have in-person acuity checked by an eye-care professional.
      </p>
      <button
        type="button"
        data-testid="va-picture-unavailable-continue"
        onClick={onContinue}
        className="mt-8 rounded-2xl bg-teal-500 px-8 py-3.5 font-bold text-[#0A0F1C]"
      >
        Continue
      </button>
      <p className="mt-4 text-xs text-slate-500">Age {age} · screening only</p>
    </div>
  );
}

function VisualAcuityPanel({ ready, patient, onComplete, measuredDistance }) {
  const { lang } = useI18n();
  const age = patient?.age ?? 8;
  const profile = getAcuityProfile(age);
  const scorable = isScorableAcuityProfile(profile);
  const [phase, setPhase] = useState("occlude_od");
  const odRef = useRef(null);
  const distanceCm = measuredDistance?.value ?? measuredDistance ?? DEFAULT_TEST_DISTANCE_CM;
  const calibration = measuredDistance?.calibration || null;
  const distanceValid = measuredDistance?.valid ?? true;
  const incompleteSubmittedRef = useRef(false);

  const submitIncomplete = useCallback((reason = "picture_optotype_not_scorable", overrides = {}) => {
    if (incompleteSubmittedRef.current) return;
    incompleteSubmittedRef.current = true;
    speak("Visual acuity screening is not available for this age on this device.", { lang });
    onComplete({
      raw_score: 0,
      normalized_score: 0,
      details: {
        test_status: "incomplete",
        result_state: "incomplete",
        measurement_valid: false,
        measurement_type: SCREENING_ACUITY_MEASUREMENT_TYPE,
        test_distance_cm: Math.round(distanceCm),
        calibrated: false,
        notation: SCREENING_ACUITY_DISCLAIMER,
        profile,
        age,
        reason,
        od: { test_status: "incomplete", measurement_valid: false },
        os: { test_status: "incomplete", measurement_valid: false },
        ...overrides,
      },
    });
  }, [age, distanceCm, lang, onComplete, profile]);

  const submitBoth = useCallback((od, os) => {
    const odDen = od.snellen_denominator;
    const osDen = os.snellen_denominator;
    const worse = worseDenominator(odDen, osDen);
    const linesDiff = interEyeLinesDiff(odDen, osDen);
    const worseEye = odDen >= osDen ? "OD" : "OS";
    speak("Both eyes screened. Near-screen acuity estimate complete.", { lang });
    setTimeout(() => onComplete({
      raw_score: worse,
      normalized_score: normalizedScoreFromDen(worse),
      details: {
        measurement_type: SCREENING_ACUITY_MEASUREMENT_TYPE,
        test_status: "completed",
        result_state: "completed",
        measurement_valid: true,
        test_distance_cm: Math.round(distanceCm),
        calibrated: !!calibration,
        calibration_info: calibration,
        device_info: getDeviceInfo(),
        notation: SCREENING_ACUITY_DISCLAIMER,
        ppi_estimate: estimatePpi(),
        profile,
        age,
        screening_acuity_estimate: {
          od_denominator: odDen,
          os_denominator: osDen,
          worse_denominator: worse,
        },
        od,
        os,
        inter_eye_lines_diff: linesDiff,
        worse_eye: worseEye,
        snellen_denominator: worse,
        snellen_label: screeningLineLabel(worse),
      },
    }), 800);
  }, [age, calibration, distanceCm, lang, onComplete, profile]);

  const handleOdComplete = (eyeData) => {
    odRef.current = eyeData;
    setPhase("occlude_os");
  };

  const handleOsComplete = (eyeData) => {
    setPhase("done");
    submitBoth(odRef.current, eyeData);
  };

  const handleEyeUnclear = () => {
    setPhase("done");
    submitIncomplete("wrong_or_unclear_occlusion", {
      test_status: "unreliable",
      result_state: "unreliable",
      measurement_valid: false,
      occlusion_verified: false,
      od: { test_status: "unreliable", measurement_valid: false },
      os: { test_status: "unreliable", measurement_valid: false },
    });
  };

  if (!scorable) {
    return <PictureAcuityUnavailable age={age} onContinue={submitIncomplete} />;
  }

  if (phase === "occlude_od") {
    return <MonocularOccluder testingEye="OD" onContinue={() => setPhase("test_od")} onUnclear={handleEyeUnclear} />;
  }
  if (phase === "occlude_os") {
    return <MonocularOccluder testingEye="OS" onContinue={() => setPhase("test_os")} onUnclear={handleEyeUnclear} />;
  }

  if (phase === "test_od") {
    return (
      <AcuityRunPanel
        ready={ready}
        testingEye="OD"
        distanceCm={distanceCm}
        distanceValid={distanceValid}
        calibration={calibration}
        onEyeComplete={handleOdComplete}
        onEyeUnclear={handleEyeUnclear}
      />
    );
  }

  if (phase === "test_os") {
    return (
      <AcuityRunPanel
        ready={ready}
        testingEye="OS"
        distanceCm={distanceCm}
        distanceValid={distanceValid}
        calibration={calibration}
        onEyeComplete={handleOsComplete}
        onEyeUnclear={handleEyeUnclear}
      />
    );
  }

  return null;
}

export default function VisualAcuityTest(props) {
  const age = props.patient?.age ?? 8;
  return (
    <TestStage
      testId="visual_acuity"
      distanceRange={[35, 45]}
      age={age}
      progress={props.flowTotal ? { index: props.flowIndex || 0, total: props.flowTotal, labels: props.flowLabels || [] } : null}
    >
      {({ ready, distance, distanceValid, calibration }) => (
        <VisualAcuityPanel
          ready={ready}
          patient={props.patient}
          onComplete={props.onComplete}
          measuredDistance={{ value: distance, valid: distanceValid, calibration }}
        />
      )}
    </TestStage>
  );
}
