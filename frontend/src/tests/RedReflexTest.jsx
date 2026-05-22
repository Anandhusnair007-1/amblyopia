import { useEffect, useRef } from "react";
import TestStage from "@/tests/TestStage";
import { speak } from "@/core/audio/AudioGuide";
import { useI18n } from "@/core/i18n/translations";
import {
  averageRgbFromImageData,
  classifyRedReflexEye,
  aggregateRedReflex,
  DEFAULT_RED_REFLEX_THRESHOLDS,
} from "@/core/clinical/redReflexAnalysis";

const PATCH = DEFAULT_RED_REFLEX_THRESHOLDS.patch_size ?? 21;
const HALF = Math.floor(PATCH / 2);

export default function RedReflexTest({ patient, onComplete, flowIndex, flowTotal, flowLabels }) {
  const { t, lang } = useI18n();
  const age = patient?.age ?? 8;
  const videoRef = useRef(null);
  const samplesRef = useRef([]);
  const finishedRef = useRef(false);

  const onFaceData = (face) => {
    if (face?.landmarks && face.landmarks.length >= 478) {
      samplesRef.current.push({
        leftIris: face.landmarks[468],
        rightIris: face.landmarks[473],
        w: face.imageWidthPx,
        h: face.imageHeightPx,
      });
    }
  };

  const samplePatch = (ctx, canvas, iris) => {
    const sx = Math.floor(iris.x * canvas.width);
    const sy = Math.floor(iris.y * canvas.height);
    const x0 = Math.max(0, sx - HALF);
    const y0 = Math.max(0, sy - HALF);
    const w = Math.min(PATCH, canvas.width - x0);
    const h = Math.min(PATCH, canvas.height - y0);
    if (w < 4 || h < 4) return null;
    const data = ctx.getImageData(x0, y0, w, h).data;
    return averageRgbFromImageData(data);
  };

  useEffect(() => {
    const timer = setTimeout(() => {
      if (finishedRef.current) return;
      finishedRef.current = true;
      const samples = samplesRef.current;
      const v = videoRef.current;
      let classification = "absent";
      let perEye = { left: null, right: null };
      let asymmetric = false;

      if (samples.length > 0 && v && v.videoWidth > 0) {
        const canvas = document.createElement("canvas");
        canvas.width = v.videoWidth;
        canvas.height = v.videoHeight;
        const ctx = canvas.getContext("2d", { willReadFrequently: true });
        ctx.drawImage(v, 0, 0, canvas.width, canvas.height);
        const last = samples[samples.length - 1];
        try {
          const leftRgb = samplePatch(ctx, canvas, last.leftIris);
          const rightRgb = samplePatch(ctx, canvas, last.rightIris);
          const left = classifyRedReflexEye(leftRgb);
          const right = classifyRedReflexEye(rightRgb);
          const agg = aggregateRedReflex(left, right);
          classification = agg.classification;
          asymmetric = agg.asymmetric;
          perEye = {
            left: {
              classification: left.classification,
              hsv: left.hsv,
              red_ratio: left.red_ratio != null ? +left.red_ratio.toFixed(3) : null,
            },
            right: {
              classification: right.classification,
              hsv: right.hsv,
              red_ratio: right.red_ratio != null ? +right.red_ratio.toFixed(3) : null,
            },
          };
        } catch (e) {
          classification = "indeterminate";
        }
      }

      speak(t("red_reflex_complete") || "Red reflex analysis complete.", { lang });
      const riskMap = {
        normal: 0.05,
        dim: 0.4,
        media_opacity: 0.55,
        leukocoria: 0.95,
        absent: 0.9,
        indeterminate: 0.3,
      };
      const normalized = riskMap[classification] ?? 0.3;
      const incomplete = classification === "indeterminate";
      setTimeout(
        () =>
          onComplete({
            raw_score: normalized,
            normalized_score: normalized,
            details: {
              classification,
              asymmetric,
              per_eye: perEye,
              samples: samples.length,
              flash_used: true,
              camera_type: "consumer_front",
              patch_size: PATCH,
              test_status: incomplete ? "incomplete" : "completed",
              measurement_valid: !incomplete,
              measurement_type: "red_reflex_screening_proxy",
            },
          }),
        900
      );
    }, 2000);
    return () => clearTimeout(timer);
    // eslint-disable-next-line
  }, []);

  return (
    <TestStage
      testId="red_reflex"
      distanceRange={[25, 35]}
      age={age}
      onFaceData={onFaceData}
      cameraOutRef={videoRef}
      progress={flowTotal ? { index: flowIndex || 0, total: flowTotal, labels: flowLabels || [] } : null}
    >
      {() => (
        <div className="absolute inset-0 z-40 flex items-center justify-center bg-white">
          <div className="text-center px-6 max-w-md">
            <div className="text-slate-600 uppercase tracking-[0.3em] text-xs font-bold">
              {t("red_reflex_capturing") || "Capturing red reflex"}
            </div>
            <p className="mt-3 text-slate-500 text-sm">
              {t("red_reflex_hold_still") ||
                "Hold still. The screen flash helps show whether each pupil looks red (normal) or pale."}
            </p>
            <div className="mt-4 inline-block">
              <div className="w-16 h-16 rounded-full border-4 border-red-200 border-t-red-600 animate-spin" />
            </div>
          </div>
        </div>
      )}
    </TestStage>
  );
}
