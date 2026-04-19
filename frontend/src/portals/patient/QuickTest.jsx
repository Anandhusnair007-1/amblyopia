import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { api } from "@/core/auth/AuthStore";
import { toast } from "sonner";

// Boots a single-test session and forwards to the test runner in ?quick=1 mode.
export default function QuickTest() {
  const nav = useNavigate();
  const { testId } = useParams();
  const [error, setError] = useState(null);

  const IDX = {
    visual_acuity: 0, gaze: 1, hirschberg: 2, prism: 3, titmus: 4, red_reflex: 5,
  };

  useEffect(() => {
    const run = async () => {
      try {
        const me = await api.get("/patient/me");
        if (!me.data.patient) { setError("Register first"); return nav("/patient"); }
        // ensure consent
        const consent = await api.get(`/consent/${me.data.patient.id}`);
        if (!consent.data || consent.data.exists === false) {
          nav(`/patient/consent?quick=${testId}`);
          return;
        }
        const s = await api.post("/sessions", { patient_id: me.data.patient.id });
        const idx = IDX[testId] ?? 0;
        nav(`/patient/session/${s.data.id}/test/${idx}?quick=1`);
      } catch (e) {
        toast.error(e?.response?.data?.detail || "Could not start test");
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
        <p className="mt-4 text-sm">{error || "Preparing your test…"}</p>
      </div>
    </div>
  );
}
