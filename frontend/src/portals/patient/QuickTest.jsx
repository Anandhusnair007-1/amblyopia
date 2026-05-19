import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { api } from "@/core/auth/AuthStore";
import { toast } from "sonner";
import { queueSessionCreate } from "@/core/offline/db";
import { shouldQueue } from "@/core/offline/useOfflineSync";
import { useI18n } from "@/core/i18n/translations";
import { getTestFlowForAge, isTestAllowedForAge } from "@/core/clinical/ageTestRouter";

// Boots a single-test session and forwards to the test runner in ?quick=1 mode.
export default function QuickTest() {
  const nav = useNavigate();
  const { testId } = useParams();
  const [error, setError] = useState(null);
  const { t } = useI18n();

  useEffect(() => {
    const run = async () => {
      try {
        const me = await api.get("/patient/me");
        if (!me.data.patient) { setError(t("quick_test_register_first")); return nav("/patient"); }
        // ensure consent
        const consent = await api.get(`/consent/${me.data.patient.id}`);
        if (!consent.data || consent.data.exists === false) {
          nav(`/patient/consent?quick=${testId}`);
          return;
        }
        let s;
        try {
          s = await api.post("/sessions", { patient_id: me.data.patient.id });
        } catch (e) {
          if (shouldQueue(e)) {
            await queueSessionCreate({ patient_id: me.data.patient.id });
            toast.message(t("offline_session_queued"));
            nav("/patient");
            return;
          }
          throw e;
        }
        const age = me.data.patient?.age ?? 8;
        if (!isTestAllowedForAge(testId, age)) {
          toast.error(t("quick_test_not_for_age"));
          nav("/patient");
          return;
        }
        const flow = getTestFlowForAge(age);
        const idx = flow.findIndex((s) => s.id === testId);
        nav(`/patient/session/${s.data.id}/test/${idx >= 0 ? idx : 0}?quick=1`);
      } catch (e) {
        toast.error(e?.response?.data?.detail || t("quick_test_could_not_start"));
        nav("/patient");
      }
    };
    run();
    // eslint-disable-next-line
  }, [testId]);

  return (
    <div className="min-h-screen bg-[#0A0F1C] text-slate-300 flex items-center justify-center">
      <div className="text-center">
        <div className="w-12 h-12 mx-auto rounded-full border-4 border-teal-500/30 border-t-teal-400 animate-spin" />
        <p className="mt-4 text-sm">{error || t("quick_test_preparing")}</p>
      </div>
    </div>
  );
}
