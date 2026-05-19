import { useMemo, useState } from "react";
import { CreditCard, Minus, Plus, Ruler, ShieldCheck } from "lucide-react";
import {
  loadScreenCalibration,
  saveScreenCalibration,
  STANDARD_CARD_WIDTH_MM,
} from "@/core/vision/ScreenCalibration";

export default function ScreenCalibrationPanel({ onCalibrated }) {
  const existing = useMemo(() => loadScreenCalibration(), []);
  const [method, setMethod] = useState("standard_card");
  const [widthPx, setWidthPx] = useState(existing?.reference_width_px || 320);
  const [referenceMm, setReferenceMm] = useState(existing?.reference_width_mm || STANDARD_CARD_WIDTH_MM);
  const [saved, setSaved] = useState(existing || null);

  const adjust = (delta) => setWidthPx((v) => Math.max(80, Math.min(900, Number(v) + delta)));

  const save = () => {
    const calibration = saveScreenCalibration({
      method,
      referenceWidthMm: referenceMm,
      referenceWidthPx: widthPx,
    });
    setSaved(calibration);
    onCalibrated?.(calibration);
  };

  return (
    <div className="rounded-2xl border border-white/10 bg-white/[0.06] p-4 text-left text-slate-100 shadow-lg">
      <div className="flex items-center gap-3">
        <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-sky-500/20 text-sky-200">
          <Ruler size={20} />
        </div>
        <div>
          <h3 className="text-sm font-bold">Screen calibration</h3>
          <p className="text-xs text-slate-400">Match the bar to a real card or ruler before acuity testing.</p>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-2 gap-2">
        <button
          type="button"
          onClick={() => { setMethod("standard_card"); setReferenceMm(STANDARD_CARD_WIDTH_MM); }}
          className={`rounded-xl border px-3 py-2 text-xs font-semibold ${method === "standard_card" ? "border-teal-300 bg-teal-400/15 text-teal-100" : "border-white/10 bg-white/5 text-slate-300"}`}
        >
          <CreditCard className="mr-1 inline h-3.5 w-3.5" /> Standard card
        </button>
        <button
          type="button"
          onClick={() => { setMethod("ruler"); setReferenceMm(50); }}
          className={`rounded-xl border px-3 py-2 text-xs font-semibold ${method === "ruler" ? "border-teal-300 bg-teal-400/15 text-teal-100" : "border-white/10 bg-white/5 text-slate-300"}`}
        >
          <Ruler className="mr-1 inline h-3.5 w-3.5" /> 50 mm ruler
        </button>
      </div>

      <div className="mt-4 rounded-xl border border-white/10 bg-black/20 p-3">
        <div
          className="h-10 rounded-lg border-2 border-dashed border-teal-300 bg-teal-300/10"
          style={{ width: `${widthPx}px`, maxWidth: "100%" }}
          aria-label="Calibration width bar"
        />
      </div>

      <div className="mt-3 flex items-center justify-between gap-2">
        <button type="button" onClick={() => adjust(-10)} className="h-11 w-11 rounded-xl border border-white/10 bg-white/5">
          <Minus className="mx-auto h-4 w-4" />
        </button>
        <div className="min-w-0 text-center">
          <div className="font-mono text-sm">{Math.round(widthPx)} px · {referenceMm} mm</div>
          <div className="text-[11px] text-slate-400">Resize until the bar matches the physical reference.</div>
        </div>
        <button type="button" onClick={() => adjust(10)} className="h-11 w-11 rounded-xl border border-white/10 bg-white/5">
          <Plus className="mx-auto h-4 w-4" />
        </button>
      </div>

      <button
        type="button"
        data-testid="save-screen-calibration"
        onClick={save}
        className="mt-4 inline-flex w-full items-center justify-center gap-2 rounded-xl bg-teal-500 px-4 py-3 text-sm font-bold text-[#0A0F1C]"
      >
        <ShieldCheck size={16} /> Save calibration
      </button>
      <p className="mt-2 text-[11px] text-slate-400">
        {saved ? `Calibration saved ${new Date(saved.calibrated_at).toLocaleString()}.` : "Without calibration, acuity is labeled as near-screen screening estimate only."}
      </p>
    </div>
  );
}
