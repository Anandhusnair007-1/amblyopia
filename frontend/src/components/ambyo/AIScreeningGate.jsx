import React, { useState, useRef, useCallback } from "react";
import { Button } from "@/components/ui/button";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Loader2, Camera, CheckCircle2, XCircle } from "lucide-react";
import WebRTCCamera from "@/core/camera/WebRTCCamera";
import UrgentBanner from "@/components/ambyo/UrgentBanner";
import { useAuthStore } from "@/core/auth/AuthStore";
import { getApiBasePath } from "@/core/apiBase";
import { useI18n } from "@/core/i18n/translations";

const HINT_KEY = {
  improve_lighting: "ai_hint_improve_lighting",
  hold_steady: "ai_hint_hold_steady",
  center_face: "ai_hint_center_face",
  retake_image: "ai_hint_retake_image",
  move_closer: "ai_hint_move_closer",
  ready: "ai_hint_ready",
};

function hintToKey(patientHint, qualityLabel) {
  if (patientHint && HINT_KEY[patientHint]) return HINT_KEY[patientHint];
  const byLabel = {
    dark: HINT_KEY.improve_lighting,
    blurred: HINT_KEY.hold_steady,
    bad_crop: HINT_KEY.center_face,
    reflection_issue: HINT_KEY.hold_steady,
    unknown: HINT_KEY.retake_image,
    good: HINT_KEY.retake_image,
  };
  return byLabel[qualityLabel] || HINT_KEY.retake_image;
}

/**
 * Camera quality gate — screen-quality decides pass/fail.
 * Supplementary strabismus scan runs after quality passes (never blocks the gate).
 */
export function AIScreeningGate({ sessionId, testName, onPassed }) {
  const token = useAuthStore((s) => s.token);
  const base = getApiBasePath();
  const { t } = useI18n();
  const [status, setStatus] = useState("idle");
  const [patientMessage, setPatientMessage] = useState(null);
  const [strabismusResult, setStrabismusResult] = useState(null);
  const videoRef = useRef(null);

  const buildQualityGatePayload = useCallback(
    (apiJson, overrides = {}) => {
      const q = apiJson?.quality || {};
      const label = overrides.quality_label ?? q.label ?? "unknown";
      const usable = overrides.is_usable ?? q.is_usable ?? false;
      return {
        checked: true,
        quality_label: label,
        is_usable: usable,
        quality_model_version: apiJson?.quality_model_version ?? overrides.quality_model_version ?? "unknown",
        checked_at: new Date().toISOString(),
      };
    },
    []
  );

  const screenFrame = async (blob) => {
    setStatus("processing");
    setPatientMessage(null);
    setStrabismusResult(null);
    const formData = new FormData();
    formData.append("file", blob, "frame.jpg");
    if (sessionId) formData.append("session_id", sessionId);
    if (testName) formData.append("test_name", testName);

    try {
      const response = await fetch(`${base}/ai/screen-quality`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
        body: formData,
      });

      if (response.status === 503) {
        setPatientMessage(t("ai_gate_unavailable_body"));
        setStatus("unavailable");
        return;
      }

      if (!response.ok) throw new Error("screening_failed");

      const result = await response.json();
      const usable = result?.quality?.is_usable === true;
      const hint = result?.patient_hint || "retake_image";
      const label = result?.quality?.label || "unknown";

      if (usable) {
        let strabismusJson = null;
        try {
          const fdStrab = new FormData();
          fdStrab.append("file", blob, "frame.jpg");
          if (sessionId) fdStrab.append("session_id", sessionId);
          if (testName) fdStrab.append("test_name", testName);
          const strabRes = await fetch(`${base}/ai/analyze-strabismus`, {
            method: "POST",
            headers: { Authorization: `Bearer ${token}` },
            body: fdStrab,
          });
          if (strabRes.ok) {
            strabismusJson = await strabRes.json();
          }
        } catch (strabErr) {
          console.warn("analyze-strabismus skipped", strabErr);
        }
        setStrabismusResult(strabismusJson);
        setStatus("passed");
        setTimeout(() => onPassed(buildQualityGatePayload(result)), 400);
      } else {
        setStatus("failed");
        const key = hintToKey(hint, label);
        setPatientMessage(t(key));
      }
    } catch (err) {
      console.error(err);
      setStatus("failed");
      setPatientMessage(t("ai_hint_retake_image"));
    }
  };

  const captureAndVerify = () => {
    const v = videoRef.current;
    if (!v || v.readyState < 2) return;
    const canvas = document.createElement("canvas");
    canvas.width = v.videoWidth;
    canvas.height = v.videoHeight;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    ctx.drawImage(v, 0, 0);
    canvas.toBlob((blob) => {
      if (blob) screenFrame(blob);
    }, "image/jpeg", 0.92);
  };

  const continueWithoutAi = () => {
    const fallback = buildQualityGatePayload(
      {},
      { quality_label: "unknown", is_usable: true, quality_model_version: "unavailable" }
    );
    onPassed(fallback);
  };

  return (
    <div
      className="flex flex-col items-center gap-6 p-8 bg-white/5 backdrop-blur-xl rounded-3xl border border-white/10 max-w-lg mx-auto"
      data-testid="ai-screening-gate"
    >
      <div className="text-center space-y-2">
        <h3 className="text-2xl font-bold text-white">{t("ai_gate_title")}</h3>
        <p className="text-slate-400 text-sm">
          {t("ai_gate_subtitle")}
        </p>
      </div>

      <div className="w-full aspect-[4/3] rounded-2xl overflow-hidden bg-black/40 relative">
        <WebRTCCamera
          onReady={(el) => {
            videoRef.current = el;
          }}
          className="absolute inset-0 w-full h-full"
          mirrored
        />
      </div>

      {status === "processing" ? (
        <div className="flex flex-col items-center gap-4 py-6 w-full" data-testid="gate-processing">
          <Loader2 className="w-12 h-12 text-teal-400 animate-spin" />
          <span className="text-teal-300 font-medium">{t("checking")}</span>
        </div>
      ) : (
        <div className="w-full space-y-4">
          {status === "failed" && (
            <Alert variant="destructive" className="bg-amber-500/10 border-amber-500/30 text-amber-100">
              <XCircle className="h-4 w-4" />
              <AlertTitle>{t("ai_gate_adjust_try_again")}</AlertTitle>
              <AlertDescription>{patientMessage || t("ai_hint_retake_image")}</AlertDescription>
            </Alert>
          )}

          {status === "unavailable" && (
            <Alert className="bg-slate-500/10 border-slate-500/30 text-slate-200">
              <AlertTitle>{t("continue")}</AlertTitle>
              <AlertDescription>{patientMessage}</AlertDescription>
            </Alert>
          )}

          {status === "passed" && (
            <div className="flex w-full flex-col items-center gap-4 py-4" data-testid="gate-passed">
              {strabismusResult?.risk === "urgent" && (
                <div className="w-full">
                  <UrgentBanner
                    findings={[
                      strabismusResult.recommendation ||
                        "Important findings detected. Please see an eye doctor as soon as possible.",
                    ]}
                  />
                </div>
              )}
              {strabismusResult?.risk === "moderate" && (
                <div
                  className="rounded-full border border-amber-400/35 bg-amber-500/10 px-4 py-2 text-center text-xs font-medium text-amber-100 shadow-sm"
                  data-testid="gate-strabismus-moderate-pill"
                  role="status"
                >
                  {strabismusResult?.recommendation ||
                    "Some findings require attention. Please visit an eye specialist soon."}
                </div>
              )}
              <div className="flex flex-col items-center gap-3 text-emerald-400">
                <CheckCircle2 className="w-14 h-14" />
                <span className="text-lg font-semibold">{t("starting")}</span>
              </div>
            </div>
          )}

          {status !== "passed" && status !== "processing" && (
            <div className="flex flex-col gap-3">
              <Button
                type="button"
                data-testid="gate-capture-btn"
                onClick={captureAndVerify}
                className="w-full h-12 text-base bg-teal-600 hover:bg-teal-500 text-[#0A0F1C] font-semibold rounded-2xl"
              >
                <Camera className="mr-2 h-5 w-5" />
                {t("ai_gate_capture_check")}
              </Button>
              {(status === "failed" || status === "unavailable") && (
                <Button
                  type="button"
                  variant="outline"
                  data-testid="gate-continue-without-ai"
                  onClick={continueWithoutAi}
                  className="w-full border-white/20 text-slate-200 hover:bg-white/10"
                >
                  {t("ai_gate_continue_without")}
                </Button>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default AIScreeningGate;
