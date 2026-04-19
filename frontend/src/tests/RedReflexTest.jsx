import { useEffect, useRef, useState } from "react";
import TestStage from "@/tests/TestStage";
import { speak } from "@/core/audio/AudioGuide";
import { useI18n } from "@/core/i18n/translations";
import WebRTCCamera from "@/core/camera/WebRTCCamera";

function rgbToHsv(r, g, b) {
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
}

export default function RedReflexTest({ patient, onComplete }) {
  const { lang } = useI18n();
  const age = patient?.age ?? 8;
  const videoRef = useRef(null);
  const samplesRef = useRef([]);
  const finishedRef = useRef(false);

  const onFaceData = (face) => {
    if (face?.landmarks && face.landmarks.length >= 478) {
      samplesRef.current.push({
        leftIris: face.landmarks[468], rightIris: face.landmarks[473],
        w: face.imageWidthPx, h: face.imageHeightPx,
      });
    }
  };

  useEffect(() => {
    const t = setTimeout(() => {
      if (finishedRef.current) return;
      finishedRef.current = true;
      const samples = samplesRef.current;
      const v = videoRef.current;
      let classification = "absent";
      let hsvL = null, hsvR = null;
      if (samples.length > 0 && v) {
        const canvas = document.createElement("canvas");
        canvas.width = v.videoWidth; canvas.height = v.videoHeight;
        const ctx = canvas.getContext("2d");
        ctx.drawImage(v, 0, 0, canvas.width, canvas.height);
        const last = samples[samples.length - 1];
        const sx = Math.floor(last.leftIris.x * canvas.width);
        const sy = Math.floor(last.leftIris.y * canvas.height);
        const rx = Math.floor(last.rightIris.x * canvas.width);
        const ry = Math.floor(last.rightIris.y * canvas.height);
        try {
          const L = ctx.getImageData(Math.max(0, sx - 5), Math.max(0, sy - 5), 11, 11).data;
          const R = ctx.getImageData(Math.max(0, rx - 5), Math.max(0, ry - 5), 11, 11).data;
          const avg = (d) => { let r = 0, g = 0, b = 0, n = 0; for (let i = 0; i < d.length; i += 4) { r += d[i]; g += d[i+1]; b += d[i+2]; n++; } return [r/n, g/n, b/n]; };
          const [lr, lg, lb] = avg(L); const [rr, rg, rb] = avg(R);
          hsvL = rgbToHsv(lr, lg, lb); hsvR = rgbToHsv(rr, rg, rb);
          const H = (hsvL.h + hsvR.h) / 2, S = (hsvL.s + hsvR.s) / 2, V = (hsvL.v + hsvR.v) / 2;
          if (V < 0.1) classification = "absent";
          else if (V > 0.85 && S < 0.2) classification = "leukocoria";
          else if ((H < 30 || H > 330) && S > 0.35 && V > 0.3) classification = "normal";
          else if (V < 0.35) classification = "dim";
          else classification = "media_opacity";
        } catch (e) { classification = "indeterminate"; }
      }
      speak("Red reflex analysis complete.", { lang });
      const riskMap = { normal: 0.05, dim: 0.4, media_opacity: 0.55, leukocoria: 0.95, absent: 0.9, indeterminate: 0.3 };
      const normalized = riskMap[classification] ?? 0.3;
      setTimeout(() => onComplete({
        raw_score: normalized, normalized_score: normalized,
        details: { classification, samples: samples.length, hsv_left: hsvL, hsv_right: hsvR },
      }), 900);
    }, 2000);
    return () => clearTimeout(t);
    // eslint-disable-next-line
  }, []);

  return (
    <TestStage testId="red_reflex" distanceRange={[25, 35]} age={age} onFaceData={onFaceData}>
      {() => (
        <div className="fixed inset-0 bg-white z-40 flex items-center justify-center">
          {/* hidden video ref for pixel sampling */}
          <div className="absolute opacity-0 pointer-events-none">
            <WebRTCCamera onReady={(v) => (videoRef.current = v)} hidden />
          </div>
          <div className="text-center">
            <div className="text-slate-600 uppercase tracking-[0.3em] text-xs font-bold">Capturing red reflex</div>
            <div className="mt-4 inline-block">
              <div className="w-16 h-16 rounded-full border-4 border-red-200 border-t-red-600 animate-spin" />
            </div>
          </div>
        </div>
      )}
    </TestStage>
  );
}
