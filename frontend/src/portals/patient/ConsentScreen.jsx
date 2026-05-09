import { useEffect, useState, useMemo } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { api } from "@/core/auth/AuthStore";
import { useI18n } from "@/core/i18n/translations";
import { toast } from "sonner";
import { Switch } from "@/components/ui/switch";
import { queueSessionCreate } from "@/core/offline/db";
import { shouldQueue } from "@/core/offline/useOfflineSync";
import { ArrowLeft, ShieldCheck, Camera, Database, Microscope, Stethoscope, Send, FileText } from "lucide-react";
import MedicalDisclaimer from "@/components/MedicalDisclaimer";
import PageHeader from "@/components/shell/PageHeader";
import { motion } from "framer-motion";
import { Skeleton } from "@/components/ui/skeleton";

const REQUIRED_TOGGLES = [
  { key: "camera", icon: Camera, tKey: "consent_camera" },
  { key: "storage", icon: Database, tKey: "consent_storage" },
  { key: "doctor_share", icon: Stethoscope, tKey: "consent_doctor" },
  { key: "referral_communication", icon: Send, tKey: "consent_referral" },
];

const OPTIONAL_TOGGLES = [
  { key: "research", icon: Microscope, tKey: "consent_research" },
  { key: "product_improvement", icon: FileText, tKey: "consent_product_improvement" },
];

const CONSENT_VERSION = "v1.1";

export default function ConsentScreen() {
  const nav = useNavigate();
  const [search] = useSearchParams();
  const quickTarget = search.get("quick");
  const { t, lang } = useI18n();
  const [patient, setPatient] = useState(null);
  const [toggles, setToggles] = useState({
    camera: false,
    storage: false,
    research: false,
    doctor_share: false,
    referral_communication: false,
    product_improvement: false,
  });
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    api.get("/patient/me").then((r) => setPatient(r.data.patient)).catch(() => {});
  }, []);

  const requiredOk = useMemo(
    () => REQUIRED_TOGGLES.every(({ key }) => toggles[key]),
    [toggles]
  );

  const submit = async () => {
    if (!requiredOk || !patient) return;
    setSubmitting(true);
    try {
      await api.post("/consent", {
        patient_id: patient.id,
        toggles,
        language: lang,
        app_version: "2.0.0",
        consent_version: CONSENT_VERSION,
        consent_scope: {
          camera_screening: toggles.camera,
          medical_record_storage: toggles.storage,
          doctor_review: toggles.doctor_share,
          referral_communication: toggles.referral_communication,
          anonymized_ai_training: toggles.research,
          product_improvement_contact: toggles.product_improvement,
        },
        guardian_name: patient.guardian_name,
      });
      toast.success("Consent saved");
      if (quickTarget) {
        nav(`/patient/quick/${quickTarget}`);
        return;
      }
      try {
        const s = await api.post("/sessions", { patient_id: patient.id });
        nav(`/patient/session/${s.data.id}/test/0`);
      } catch (e) {
        if (shouldQueue(e)) {
          await queueSessionCreate({ patient_id: patient.id });
          toast.message("You appear offline. Session creation queued and will sync when online.");
          nav("/patient");
          return;
        }
        throw e;
      }
    } catch (e) {
      toast.error(e?.response?.data?.detail || "Failed");
    } finally {
      setSubmitting(false);
    }
  };

  const renderToggleRow = (row, optional) => (
    <label
      key={row.key}
      className={`flex cursor-pointer items-center justify-between gap-4 rounded-xl border p-4 transition-all ${
        toggles[row.key]
          ? "border-teal-300 bg-teal-50/50"
          : "border-slate-200 hover:bg-slate-50"
      } ${optional ? "border-dashed" : ""}`}
    >
      <div className="flex min-w-0 items-center gap-3">
        <div
          className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-lg ${
            toggles[row.key] ? "bg-teal-600 text-white" : "bg-slate-100 text-slate-500"
          }`}
        >
          <row.icon size={18} />
        </div>
        <span className="text-sm text-slate-800 sm:text-base">{t(row.tKey)}</span>
      </div>
      <Switch
        data-testid={`consent-toggle-${row.key}`}
        checked={!!toggles[row.key]}
        onCheckedChange={(v) => setToggles((s) => ({ ...s, [row.key]: v }))}
      />
    </label>
  );

  return (
    <div className="min-h-screen bg-background page-enter">
      <header className="border-b border-border bg-card">
        <div className="mx-auto max-w-3xl px-4 py-4 sm:px-6 lg:px-8">
          <PageHeader
            eyebrow={t("consent_eyebrow")}
            title={t("consent_title")}
            actions={
              <button
                onClick={() => nav(-1)}
                data-testid="back-btn"
                type="button"
                className="inline-flex items-center gap-1 rounded-xl border border-input bg-background px-3 py-2 text-sm font-medium shadow-sm hover:bg-muted/50"
              >
                <ArrowLeft size={16} /> {t("back")}
              </button>
            }
          />
        </div>
      </header>
      <main className="mx-auto max-w-3xl px-4 py-8 sm:px-6 lg:px-8">
        <MedicalDisclaimer className="mb-6" />
        <motion.div
          initial={{ y: 8, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          className="overflow-hidden rounded-2xl border border-border bg-card shadow-sm"
        >
          <div className="bg-gradient-to-br from-[#0A2540] to-[#0D2E52] p-6 text-white sm:p-8">
            <div className="flex items-center gap-3">
              <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-white/10">
                <ShieldCheck size={24} />
              </div>
              <div className="min-w-0">
                <div className="text-xs font-semibold tracking-wide text-teal-200">{t("patient")}</div>
                {patient ? (
                  <>
                    <h2 className="truncate text-2xl font-bold tracking-tight text-white">{patient.name || "—"}</h2>
                    <p className="mt-0.5 text-sm text-white/80">
                      {t("age_dob_line", { age: String(patient.age), dob: String(patient.date_of_birth) })}
                    </p>
                  </>
                ) : (
                  <div className="mt-1 space-y-2">
                    <Skeleton className="h-7 w-[220px] bg-white/15" />
                    <Skeleton className="h-4 w-[260px] bg-white/10" />
                  </div>
                )}
              </div>
            </div>
            <p className="mt-4 text-xs text-white/70">
              Consent version <span className="font-mono text-white/90">{CONSENT_VERSION}</span> · Language{" "}
              <span className="font-mono text-white/90">{lang}</span>
            </p>
          </div>
          <div className="p-6 sm:p-8">
            <p className="text-sm leading-relaxed text-slate-600">{t("consent_intro")}</p>

            <div className="mt-8">
              <h3 className="text-sm font-semibold text-[#0A2540]">{t("required_for_screening")}</h3>
              <p className="mt-1 text-xs text-muted-foreground">
                {t("required_for_screening_subtitle")}
              </p>
              <div className="mt-3 space-y-3">{REQUIRED_TOGGLES.map((row) => renderToggleRow(row, false))}</div>
            </div>

            <div className="mt-8 border-t border-slate-100 pt-8">
              <h3 className="text-sm font-semibold text-[#0A2540]">{t("optional")}</h3>
              <p className="mt-1 text-xs text-muted-foreground">{t("optional_subtitle")}</p>
              <div className="mt-3 space-y-3">{OPTIONAL_TOGGLES.map((row) => renderToggleRow(row, true))}</div>
            </div>

            <p className="mt-6 text-xs text-muted-foreground">
              <button
                type="button"
                className="font-medium text-teal-700 underline-offset-2 hover:underline"
                onClick={() => toast.message("Full consent text: request from your hospital or support.")}
              >
                {t("view_full_consent_text")}
              </button>
              {" · "}
              <button
                type="button"
                className="font-medium text-teal-700 underline-offset-2 hover:underline"
                onClick={() => nav("/patient")}
              >
                {t("consent_history_revoke")}
              </button>{" "}
              {t("consent_history_revoke_hint")}
            </p>

            <div className="mt-6 flex justify-end gap-3 border-t border-slate-100 pt-6">
              <button
                onClick={() => nav(-1)}
                type="button"
                className="rounded-xl border border-border px-4 py-2.5 text-muted-foreground hover:bg-muted/50"
              >
                {t("cancel")}
              </button>
              <button
                data-testid="submit-consent"
                disabled={!requiredOk || submitting}
                onClick={submit}
                className="inline-flex items-center gap-2 rounded-xl bg-teal-600 px-5 py-2.5 font-semibold text-white shadow-md transition-all hover:bg-teal-700 disabled:opacity-40"
              >
                {submitting ? t("saving") : t("i_consent")}
              </button>
            </div>
          </div>
        </motion.div>
      </main>
    </div>
  );
}
