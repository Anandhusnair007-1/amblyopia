import { useEffect, useState, useRef, useCallback } from "react";
import { useNavigate, useParams, useSearchParams } from "react-router-dom";
import { api } from "@/core/auth/AuthStore";
import { useI18n } from "@/core/i18n/translations";
import { toast } from "sonner";
import TestProgressBar from "@/components/ambyo/TestProgressBar";
import LanguageSwitcher from "@/components/ambyo/LanguageSwitcher";
import OfflineBadge from "@/components/ambyo/OfflineBadge";
import AudioToggle from "@/components/ambyo/AudioToggle";
import { X, SkipForward } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import VisualAcuityTest from "@/tests/VisualAcuityTest";
import GazeTest from "@/tests/GazeTest";
import HirschbergTest from "@/tests/HirschbergTest";
import PrismDiopterTest from "@/tests/PrismDiopterTest";
import RedReflexTest from "@/tests/RedReflexTest";
import TitmusTest from "@/tests/TitmusTest";

export const TEST_FLOW = [
  { id: "visual_acuity", label: "Visual Acuity", comp: VisualAcuityTest, distance: [35, 45] },
  { id: "gaze",          label: "Gaze Detection", comp: GazeTest, distance: [40, 60] },
  { id: "hirschberg",    label: "Hirschberg",     comp: HirschbergTest, distance: [30, 45] },
  { id: "prism",         label: "Prism Diopter",  comp: PrismDiopterTest, distance: [0, 0] },
  { id: "titmus",        label: "Titmus",         comp: TitmusTest, distance: [40, 60] },
  { id: "red_reflex",    label: "Red Reflex",     comp: RedReflexTest, distance: [25, 35] },
];

export default function TestRunner() {
  const nav = useNavigate();
  const { sessionId, testIndex } = useParams();
  const [search] = useSearchParams();
  const quick = search.get("quick") === "1";
  const { t } = useI18n();
  const idx = parseInt(testIndex || "0", 10);
  const test = TEST_FLOW[idx];
  const [session, setSession] = useState(null);
  const [patient, setPatient] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let mounted = true;
    api.get(`/sessions/${sessionId}`).then((r) => {
      if (!mounted) return;
      setSession(r.data.session);
      setPatient(r.data.patient);
      setLoading(false);
    }).catch(() => toast.error("Session not found"));
    return () => { mounted = false; };
  }, [sessionId]);

  const submitResult = useCallback(async (payload) => {
    try {
      await api.post(`/sessions/${sessionId}/results`, {
        test_name: test.id,
        raw_score: payload.raw_score ?? 0,
        normalized_score: payload.normalized_score ?? 0,
        details: payload.details || {},
      });
    } catch (e) { toast.error("Could not save result"); }
  }, [sessionId, test]);

  const goNext = useCallback(async (payload) => {
    if (payload) await submitResult(payload);
    // Quick mode: end after this single test
    if (quick) {
      try { await api.post(`/sessions/${sessionId}/complete`); } catch (e) {}
      nav(`/patient/session/${sessionId}/results`);
      return;
    }
    const next = idx + 1;
    if (next >= TEST_FLOW.length) {
      try { await api.post(`/sessions/${sessionId}/complete`); } catch (e) {}
      nav(`/patient/session/${sessionId}/results`);
    } else {
      nav(`/patient/session/${sessionId}/test/${next}${quick ? "?quick=1" : ""}`);
    }
  }, [idx, sessionId, nav, submitResult, quick]);

  const skip = async () => { await goNext({ raw_score: 0, normalized_score: 0, details: { skipped: true } }); };

  if (loading || !test) {
    return <div className="min-h-screen bg-[#0A0F1C] text-slate-300 flex items-center justify-center">Loading test…</div>;
  }

  const TestComp = test.comp;
  const totalSteps = quick ? 1 : TEST_FLOW.length;
  const displayIdx = quick ? 0 : idx;

  return (
    <div className="min-h-screen bg-[#0A0F1C] text-slate-100 page-enter overflow-hidden">
      {/* Ambient background glow */}
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute -top-40 -right-40 w-[48rem] h-[48rem] rounded-full bg-teal-500/5 blur-3xl" />
        <div className="absolute -bottom-40 -left-40 w-[36rem] h-[36rem] rounded-full bg-sky-500/5 blur-3xl" />
      </div>

      {/* Top bar */}
      <div className="relative z-30 px-4 sm:px-6 pt-4">
        <div className="max-w-7xl mx-auto flex items-center justify-between gap-3">
          <button
            data-testid="exit-test"
            onClick={() => nav("/patient")}
            className="inline-flex items-center gap-1.5 w-10 h-10 justify-center rounded-full bg-white/5 border border-white/10 text-slate-300 hover:bg-white/10 transition-colors"
            aria-label="Exit"
          ><X size={16} /></button>
          <div className="flex-1 max-w-xl">
            <TestProgressBar total={totalSteps} index={displayIdx} labels={quick ? [test.label] : TEST_FLOW.map(f => f.label)} />
          </div>
          <div className="flex items-center gap-2">
            <AudioToggle variant="dark" />
            <OfflineBadge />
            <LanguageSwitcher variant="dark" />
            {!quick && (
              <button
                data-testid="skip-test"
                onClick={skip}
                className="inline-flex items-center gap-1.5 px-3 h-10 rounded-full text-xs text-slate-400 hover:bg-white/10 transition-colors border border-white/10"
              ><SkipForward size={12} /> {t("skip")}</button>
            )}
          </div>
        </div>
      </div>

      {/* Test area */}
      <AnimatePresence mode="wait">
        <motion.div
          key={test.id}
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -16 }}
          transition={{ duration: 0.38, ease: [0.22, 1, 0.36, 1] }}
          className="relative min-h-[calc(100vh-5rem)] flex flex-col"
        >
          <TestComp
            patient={patient}
            session={session}
            testMeta={test}
            onComplete={goNext}
          />
        </motion.div>
      </AnimatePresence>
    </div>
  );
}
