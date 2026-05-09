import { useEffect, useRef } from "react";
import TestStage from "@/tests/TestStage";
import { speak } from "@/core/audio/AudioGuide";
import { useI18n } from "@/core/i18n/translations";

/**
 * Heidelberg (proxy) — browser-based retinal-imaging approximation.
 *
 * Since we cannot do true OCT, we re-use a red-reflex style capture and apply
 * rule-based brightness pattern heuristics around the pupil/iris region.
 *
 * Output (details):
 *  - classification: normal | suspect | refer | indeterminate
 *  - confidence: 0..1
 *  - metrics: { centerV, ringV, contrast, asymmetry }
 */
export default function HeidelbergTest({ patient, onComplete, flowIndex, flowTotal, flowLabels }) {
  const { lang } = useI18n();
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

  const rgbToHsv = (r, g, b) => {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
    let h = 0;
    if (d !== 0) {
      if (max === r) h = 60 * (((g - b) / d) % 6);
      else if (max === g) h = 60 * ((b - r) / d + 2);
      else h = 60 * ((r - g) / d + 4);
      if (h < 0) h += 360;
    }
    return { h, s: max === 0 ? 0 : d / max, v: max };
  };

  const samplePatch = (ctx, x, y, size) => {
    const half = Math.floor(size / 2);
    const sx = Math.max(0, Math.floor(x - half));
    const sy = Math.max(0, Math.floor(y - half));
    const w = Math.max(1, Math.min(size, ctx.canvas.width - sx));
    const h = Math.max(1, Math.min(size, ctx.canvas.height - sy));
    const d = ctx.getImageData(sx, sy, w, h).data;
    let r = 0, g = 0, b = 0, n = 0;
    for (let i = 0; i < d.length; i += 4) {
      r += d[i]; g += d[i + 1]; b += d[i + 2]; n++;
    }
    return n ? rgbToHsv(r / n, g / n, b / n) : { h: 0, s: 0, v: 0 };
  };

  useEffect(() => {
    // Keep guidance short and non-technical.
    speak("Heidelberg proxy test. Increase screen brightness. Look at the center dot and keep still.", { lang });
    const t = setTimeout(() => {
      if (finishedRef.current) return;
      finishedRef.current = true;
      const v = videoRef.current;
      const samples = samplesRef.current;

      let classification = "indeterminate";
      let confidence = 0.2;
      let metrics = null;

      if (v && samples.length > 0) {
        const canvas = document.createElement("canvas");
        canvas.width = v.videoWidth;
        canvas.height = v.videoHeight;
        const ctx = canvas.getContext("2d");
        ctx.drawImage(v, 0, 0, canvas.width, canvas.height);

        const last = samples[samples.length - 1];
        const lx = Math.floor(last.leftIris.x * canvas.width);
        const ly = Math.floor(last.leftIris.y * canvas.height);
        const rx = Math.floor(last.rightIris.x * canvas.width);
        const ry = Math.floor(last.rightIris.y * canvas.height);

        try {
          // Center patches (iris) + a slightly wider "ring" (proxy for optic-disc / fundus reflection consistency).
          const Lc = samplePatch(ctx, lx, ly, 16);
          const Rc = samplePatch(ctx, rx, ry, 16);
          const Lr = samplePatch(ctx, lx, ly, 40);
          const Rr = samplePatch(ctx, rx, ry, 40);

          const centerV = (Lc.v + Rc.v) / 2;
          const ringV = (Lr.v + Rr.v) / 2;
          const contrast = Math.max(0, ringV - centerV);
          const asymmetry = Math.abs(Lr.v - Rr.v);

          metrics = {
            centerV: +centerV.toFixed(3),
            ringV: +ringV.toFixed(3),
            contrast: +contrast.toFixed(3),
            asymmetry: +asymmetry.toFixed(3),
          };

          // Heuristics:
          // - Very low ringV suggests inadequate illumination -> indeterminate.
          // - High asymmetry + low contrast suggests media opacity / abnormal reflections -> refer.
          // - Moderate asymmetry or low contrast -> suspect.
          if (ringV < 0.18) {
            classification = "indeterminate";
            confidence = 0.25;
          } else if (asymmetry > 0.12 && contrast < 0.05) {
            classification = "refer";
            confidence = 0.75;
          } else if (asymmetry > 0.08 || contrast < 0.04) {
            classification = "suspect";
            confidence = 0.6;
          } else {
            classification = "normal";
            confidence = 0.65;
          }
        } catch (e) {
          classification = "indeterminate";
          confidence = 0.2;
        }
      }

      speak("Heidelberg proxy analysis complete.", { lang });
      const normMap = { normal: 0.1, suspect: 0.55, refer: 0.9, indeterminate: 0.35 };
      const normalized = normMap[classification] ?? 0.35;

      setTimeout(() => onComplete({
        raw_score: normalized,
        normalized_score: normalized,
        details: {
          classification,
          confidence: +confidence.toFixed(2),
          metrics,
          samples: samplesRef.current.length,
        },
      }), 700);
    }, 2200);
    return () => clearTimeout(t);
    // eslint-disable-next-line
  }, []);

  return (
    <TestStage
      testId="heidelberg"
      distanceRange={[25, 35]}
      age={age}
      onFaceData={onFaceData}
      cameraOutRef={videoRef}
      progress={flowTotal ? { index: flowIndex || 0, total: flowTotal, labels: flowLabels || [] } : null}
    >
      {() => (
        <div className="absolute inset-0 z-40 flex items-center justify-center bg-white">
          <div className="text-center">
            <div className="text-slate-600 uppercase tracking-[0.3em] text-xs font-bold">Capturing retinal proxy</div>
            <div className="mt-4 inline-block">
              <div className="w-16 h-16 rounded-full border-4 border-slate-200 border-t-slate-700 animate-spin" />
            </div>
          </div>
        </div>
      )}
    </TestStage>
  );
}

