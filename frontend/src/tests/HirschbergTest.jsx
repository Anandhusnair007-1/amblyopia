import { useEffect, useMemo, useRef, useState } from "react";
import TestStage from "@/tests/TestStage";
import { speak } from "@/core/audio/AudioGuide";
import { useI18n } from "@/core/i18n/translations";

export default function HirschbergTest({ patient, onComplete, flowIndex, flowTotal, flowLabels }) {
  const { lang } = useI18n();
  const age = patient?.age ?? 8;
  const [phase, setPhase] = useState("capture"); // capture → analyzing
  const videoRef = useRef(null);
  const canvasRef = useRef(null);
  const ctxRef = useRef(null);
  const samplesRef = useRef([]);
  const finishedRef = useRef(false);

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

  const ensureCanvas = () => {
    const v = videoRef.current;
    if (!v || v.readyState < 2) return null;
    if (!canvasRef.current) canvasRef.current = document.createElement("canvas");
    const c = canvasRef.current;
    if (c.width !== v.videoWidth || c.height !== v.videoHeight) {
      c.width = v.videoWidth;
      c.height = v.videoHeight;
      ctxRef.current = c.getContext("2d", { willReadFrequently: true });
    }
    return ctxRef.current;
  };

  const toPx = (p, w, h) => ({ x: p.x * w, y: p.y * h });

  const irisCenterPx = (landmarks, indices, w, h) => {
    let sx = 0, sy = 0;
    for (const i of indices) {
      sx += landmarks[i].x;
      sy += landmarks[i].y;
    }
    return { x: (sx / indices.length) * w, y: (sy / indices.length) * h };
  };

  const irisDiameterPx = (landmarks, indices, w, h) => {
    // Use max pairwise distance among iris landmarks as a stable diameter proxy.
    let max = 0;
    for (let a = 0; a < indices.length; a++) {
      const pa = toPx(landmarks[indices[a]], w, h);
      for (let b = a + 1; b < indices.length; b++) {
        const pb = toPx(landmarks[indices[b]], w, h);
        const dx = pa.x - pb.x;
        const dy = pa.y - pb.y;
        const d = Math.hypot(dx, dy);
        if (d > max) max = d;
      }
    }
    return max || null;
  };

  const brightestClusterCentroid = (ctx, roi) => {
    // roi: { x, y, w, h } in pixels (clamped before calling)
    const img = ctx.getImageData(roi.x, roi.y, roi.w, roi.h);
    const d = img.data;
    let maxL = 0;
    // First pass: find max luminance
    for (let i = 0; i < d.length; i += 4) {
      const r = d[i], g = d[i + 1], b = d[i + 2];
      const l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      if (l > maxL) maxL = l;
    }
    if (maxL < 8) return null; // too dark / no signal

    // Second pass: centroid of top bright pixels (adaptive threshold).
    const thr = Math.max(32, maxL * 0.9);
    let sx = 0, sy = 0, n = 0;
    for (let i = 0; i < d.length; i += 4) {
      const r = d[i], g = d[i + 1], b = d[i + 2];
      const l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      if (l >= thr) {
        const px = (i / 4) % roi.w;
        const py = Math.floor(i / 4 / roi.w);
        sx += px;
        sy += py;
        n++;
      }
    }
    if (n < 6) return null;
    return { x: roi.x + sx / n, y: roi.y + sy / n, n, maxL, thr };
  };

  const measureEye = (ctx, landmarks, indices, w, h) => {
    const center = irisCenterPx(landmarks, indices, w, h);
    const diamPx = irisDiameterPx(landmarks, indices, w, h);
    if (!diamPx || diamPx < 4) return null;

    // Iris ROI bounding box (with padding)
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (const i of indices) {
      const p = toPx(landmarks[i], w, h);
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }
    const pad = Math.max(2, diamPx * 0.35);
    const x0 = Math.max(0, Math.floor(minX - pad));
    const y0 = Math.max(0, Math.floor(minY - pad));
    const x1 = Math.min(w - 1, Math.ceil(maxX + pad));
    const y1 = Math.min(h - 1, Math.ceil(maxY + pad));
    const rw = Math.max(1, x1 - x0);
    const rh = Math.max(1, y1 - y0);
    if (rw < 6 || rh < 6) return null;

    const cluster = brightestClusterCentroid(ctx, { x: x0, y: y0, w: rw, h: rh });
    if (!cluster) return null;

    const dxPx = cluster.x - center.x;
    const dyPx = cluster.y - center.y;
    const dispPx = Math.hypot(dxPx, dyPx);
    const mmPerPx = 11.8 / diamPx; // average iris diameter (mm)
    const dispMm = dispPx * mmPerPx;
    return {
      displacementMm: +dispMm.toFixed(3),
      displacementPx: +dispPx.toFixed(2),
      dxPx: +dxPx.toFixed(2),
      dyPx: +dyPx.toFixed(2),
      irisDiameterPx: +diamPx.toFixed(2),
      reflex: { x: +cluster.x.toFixed(1), y: +cluster.y.toFixed(1), n: cluster.n, maxL: +cluster.maxL.toFixed(1) },
      center: { x: +center.x.toFixed(1), y: +center.y.toFixed(1) },
    };
  };

  const onFaceData = (face) => {
    if (!face?.landmarks || phase !== "capture") return;
    const v = videoRef.current;
    if (!v || v.readyState < 2) return;

    const ctx = ensureCanvas();
    if (!ctx) return;

    // Draw current frame once per callback.
    ctx.drawImage(v, 0, 0, v.videoWidth, v.videoHeight);

    const w = v.videoWidth;
    const h = v.videoHeight;
    const lm = face.landmarks;
    if (lm.length < 478) return;

    const left = measureEye(ctx, lm, [468, 469, 470, 471, 472], w, h);
    const right = measureEye(ctx, lm, [473, 474, 475, 476, 477], w, h);
    if (!left || !right) return;

    samplesRef.current.push({ left, right, ts: performance.now() });
  };

  // Show a 2s white flash once TestStage goes "ready"
  useEffect(() => {
    const t = setTimeout(() => {
      if (finishedRef.current) return;
      setPhase("analyzing");
      const samples = samplesRef.current;
      if (samples.length === 0) {
        return onComplete({
          raw_score: 0,
          normalized_score: 0,
          details: {
            leftDisplacementMM: 0,
            rightDisplacementMM: 0,
            estimatedPD: 0,
            asymmetry: 0,
            risk: "unknown",
            samples: 0,
            note: "no samples",
          },
        });
      }

      // Robust aggregate: take median displacement for each eye across samples.
      const median = (arr) => {
        const a = arr.filter((x) => Number.isFinite(x)).sort((x, y) => x - y);
        if (!a.length) return 0;
        const m = Math.floor(a.length / 2);
        return a.length % 2 ? a[m] : (a[m - 1] + a[m]) / 2;
      };
      const leftMm = median(samples.map((s) => s.left.displacementMm));
      const rightMm = median(samples.map((s) => s.right.displacementMm));
      const asymmetry = Math.abs(leftMm - rightMm);

      // Hirschberg ratio: 1mm displacement ≈ 22 prism diopters
      const estimatedPD = ((leftMm + rightMm) / 2) * 22;
      const risk = classifyRisk(estimatedPD);

      const normalized = Math.max(0, Math.min(1, Math.abs(estimatedPD) / 30)); // 0..30 PD scaled
      speak("Capture complete.", { lang });
      finishedRef.current = true;
      setTimeout(() => onComplete({
        raw_score: +estimatedPD.toFixed(2),
        normalized_score: +normalized.toFixed(3),
        details: {
          leftDisplacementMM: +leftMm.toFixed(3),
          rightDisplacementMM: +rightMm.toFixed(3),
          estimatedPD: +estimatedPD.toFixed(2),
          asymmetry: +asymmetry.toFixed(3),
          risk,
          samples: samples.length,
          // Keep some debug context for clinicians (bounded size).
          sample_preview: samples.slice(-3),
        },
      }), 800);
    }, 2000);
    return () => clearTimeout(t);
    // eslint-disable-next-line
  }, []);

  return (
    <TestStage
      testId="hirschberg"
      distanceRange={[30, 45]}
      age={age}
      onFaceData={onFaceData}
      cameraOutRef={videoRef}
      progress={flowTotal ? { index: flowIndex || 0, total: flowTotal, labels: flowLabels || [] } : null}
    >
      {() => (
        <div className="absolute inset-0 z-40 flex items-center justify-center bg-white">
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
