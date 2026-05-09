import { useEffect, useState, useRef, useCallback, useMemo } from "react";
import { useNavigate, useParams, useSearchParams } from "react-router-dom";
import { api } from "@/core/auth/AuthStore";
import { useI18n } from "@/core/i18n/translations";
import { toast } from "sonner";
import TestProgressBar from "@/components/ambyo/TestProgressBar";
import LanguageSwitcher from "@/components/ambyo/LanguageSwitcher";
import OfflineBadge from "@/components/ambyo/OfflineBadge";
import AudioToggle from "@/components/ambyo/AudioToggle";
import { ChevronLeft, Home, SkipForward } from "lucide-react";
import { Button } from "@/components/ui/button";
import MedicalDisclaimer from "@/components/MedicalDisclaimer";
import { motion, AnimatePresence } from "framer-motion";
import VisualAcuityTest from "@/tests/VisualAcuityTest";
import GazeTest from "@/tests/GazeTest";
import HirschbergTest from "@/tests/HirschbergTest";
import PrismDiopterTest from "@/tests/PrismDiopterTest";
import RedReflexTest from "@/tests/RedReflexTest";
import TitmusTest from "@/tests/TitmusTest";
import HeidelbergTest from "@/tests/HeidelbergTest";
import { AIScreeningGate } from "@/components/ambyo/AIScreeningGate";
import { normalizeAgeYears } from "@/core/camera/MediaPipeSetup";
import { cacheResult } from "@/core/offline/db";
import { shouldQueue } from "@/core/offline/useOfflineSync";

/** Camera-based steps that use the server quality model before starting */
export const CAMERA_QUALITY_GATE_TESTS = new Set(["gaze", "hirschberg", "red_reflex"]);

export const TEST_FLOW = [
  { id: "visual_acuity", labelKey: "test_visual_acuity", comp: VisualAcuityTest, distance: [35, 45] },
  { id: "gaze",          labelKey: "test_gaze",          comp: GazeTest, distance: [40, 60] },
  { id: "hirschberg",    labelKey: "test_hirschberg",    comp: HirschbergTest, distance: [30, 45] },
  { id: "prism",         labelKey: "test_prism",         comp: PrismDiopterTest, distance: [0, 0] },
  { id: "titmus",        labelKey: "test_titmus",        comp: TitmusTest, distance: [40, 60] },
  { id: "red_reflex",    labelKey: "test_red_reflex",    comp: RedReflexTest, distance: [25, 35] },
  // Optional 7th test (proxy for Heidelberg retinal imaging / OCT).
  { id: "heidelberg",    labelKey: "test_heidelberg_proxy", comp: HeidelbergTest, distance: [25, 35] },
];

function TestRunnerTopBar({ onBack, onHome, t, right }) {
  return (
    <header className="fixed left-0 right-0 top-0 z-40 border-b border-white/[0.07] bg-[#0A0F1C]/85 px-4 pb-3 pt-[max(1rem,env(safe-area-inset-top))] backdrop-blur-md supports-[backdrop-filter]:bg-[#0A0F1C]/70 sm:px-6">
      <div className="max-w-7xl mx-auto flex items-center justify-between gap-2 sm:gap-3">
        <div className="flex items-center gap-2 flex-shrink-0">
          <Button
            type="button"
            variant="outline"
            data-testid="test-back"
            onClick={onBack}
            className="h-11 min-h-[44px] px-3 sm:px-4 rounded-xl border-white/20 bg-white/[0.07] text-slate-100 hover:bg-white/12 hover:text-white shadow-sm gap-1.5 focus-visible:ring-2 focus-visible:ring-teal-400/60 focus-visible:ring-offset-2 focus-visible:ring-offset-[#0A0F1C]"
            aria-label={t("back")}
          >
            <ChevronLeft className="h-4 w-4 shrink-0 opacity-90" aria-hidden />
            <span className="text-sm font-semibold tracking-tight">{t("back")}</span>
          </Button>
          <Button
            type="button"
            variant="outline"
            size="icon"
            data-testid="test-exit-home"
            onClick={onHome}
            className="h-11 w-11 min-h-[44px] min-w-[44px] rounded-xl border-white/20 bg-white/[0.05] text-slate-200 hover:bg-white/12 hover:text-white focus-visible:ring-2 focus-visible:ring-teal-400/60 focus-visible:ring-offset-2 focus-visible:ring-offset-[#0A0F1C]"
            aria-label={t("exit_home")}
            title={t("exit_home")}
          >
            <Home className="h-4 w-4" aria-hidden />
          </Button>
        </div>
        <div className="min-w-[2rem] flex-1" />
        {right}
      </div>
    </header>
  );
}

function TestRunnerBottomBar({ totalSteps, displayIdx, labels, quick, testLabel }) {
  return (
    <footer className="fixed bottom-0 left-0 right-0 z-30 border-t border-white/[0.07] bg-[#0A0F1C]/90 px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-3 backdrop-blur-md supports-[backdrop-filter]:bg-[#0A0F1C]/75 sm:px-6">
      <div className="mx-auto flex w-full max-w-4xl flex-col gap-3">
        <TestProgressBar total={totalSteps} index={displayIdx} labels={quick ? [testLabel] : labels} />
        <MedicalDisclaimer className="border-white/10 bg-white/5 text-slate-300" />
      </div>
    </footer>
  );
}

export default function TestRunner() {
  const nav = useNavigate();
  const { sessionId, testIndex } = useParams();
  const [search] = useSearchParams();
  const quick = search.get("quick") === "1";
  const { t } = useI18n();
  const idx = (() => {
    const n = parseInt(testIndex || "0", 10);
    if (Number.isFinite(n) && String(n) === String(testIndex || "0")) return n;
    const byId = TEST_FLOW.findIndex((t) => t.id === String(testIndex || "").toLowerCase());
    return byId >= 0 ? byId : 0;
  })();
  const test = TEST_FLOW[idx];
  const [session, setSession] = useState(null);
  const [patient, setPatient] = useState(null);
  const [loading, setLoading] = useState(true);
  const [cameraGateDone, setCameraGateDone] = useState(false);
  const qualityGateMetaRef = useRef(null);

  useEffect(() => {
    let mounted = true;
    api.get(`/sessions/${sessionId}`).then((r) => {
      if (!mounted) return;
      setSession(r.data.session);
      setPatient(r.data.patient);
      setLoading(false);
    }).catch(() => toast.error(t("err_session_not_found")));
    return () => { mounted = false; };
  }, [sessionId, t]);

  useEffect(() => {
    qualityGateMetaRef.current = null;
    setCameraGateDone(!CAMERA_QUALITY_GATE_TESTS.has(test?.id || ""));
  }, [test?.id]);

  const submitResult = useCallback(async (payload) => {
    if (!test) return;
    const details = { ...(payload.details || {}) };
    const qMeta = qualityGateMetaRef.current;
    if (qMeta && CAMERA_QUALITY_GATE_TESTS.has(test.id)) {
      details.quality_gate = { ...qMeta };
    }
    const body = {
      test_name: test.id,
      raw_score: payload.raw_score ?? 0,
      normalized_score: payload.normalized_score ?? 0,
      details,
    };
    try {
      await api.post(`/sessions/${sessionId}/results`, body);
    } catch (e) {
      if (shouldQueue(e)) {
        await cacheResult({ session_id: sessionId, test_name: test.id, payload: body });
        toast.message(t("offline_result_saved"));
        return;
      }
      toast.error(t("err_could_not_save_result"));
    }
  }, [sessionId, test, t]);

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

  const querySuffix = quick ? "?quick=1" : "";

  /** Previous step in the screening flow, or patient home when on the first step / quick mode. */
  const goBack = useCallback(() => {
    if (quick) {
      nav("/patient");
      return;
    }
    if (idx <= 0) {
      nav("/patient");
      return;
    }
    nav(`/patient/session/${sessionId}/test/${idx - 1}${querySuffix}`);
  }, [idx, sessionId, nav, quick, querySuffix]);

  const goPatientHome = useCallback(() => {
    nav("/patient");
  }, [nav]);

  const patientForTests = useMemo(() => {
    if (!patient) return null;
    return { ...patient, age: normalizeAgeYears(patient.age, 8) };
  }, [patient]);

  const labels = useMemo(() => TEST_FLOW.map((f) => t(f.labelKey)), [t]);
  const testLabel = test ? t(test.labelKey) : "";

  if (loading || !test) {
    return (
      <div className="relative h-[100dvh] overflow-hidden bg-[#0A0F1C] text-slate-100">
        <div className="pointer-events-none absolute inset-0 z-0 bg-[#0A0F1C]" />
        <TestRunnerTopBar onBack={goBack} onHome={goPatientHome} t={t} right={null} />
        <main className="absolute inset-0 z-20 flex items-center justify-center px-4 pb-[var(--test-bottombar-height,8rem)] pt-[var(--test-topbar-height,5.5rem)] text-slate-400">
          Loading test…
        </main>
      </div>
    );
  }

  const needsCameraGate = CAMERA_QUALITY_GATE_TESTS.has(test.id);
  if (needsCameraGate && !cameraGateDone) {
    return (
      <div className="relative h-[100dvh] overflow-hidden bg-[#0A0F1C] text-slate-100">
        <div className="pointer-events-none absolute inset-0 z-0 bg-[#0A0F1C]" />
        <TestRunnerTopBar onBack={goBack} onHome={goPatientHome} t={t} right={null} />
        <main className="absolute inset-0 z-20 flex min-h-0 flex-col items-center justify-center overflow-hidden px-4 pb-[max(1.5rem,env(safe-area-inset-bottom))] pt-[var(--test-topbar-height,5.5rem)]">
          <AIScreeningGate
            sessionId={sessionId}
            testName={test.id}
            onPassed={(meta) => {
              qualityGateMetaRef.current = meta;
              setCameraGateDone(true);
            }}
          />
        </main>
      </div>
    );
  }

  const TestComp = test.comp;
  const totalSteps = quick ? 1 : TEST_FLOW.length;
  const displayIdx = quick ? 0 : idx;

  return (
    <div
      className="test-runner-root page-enter relative h-[100dvh] overflow-hidden bg-[#0A0F1C] text-slate-100"
      style={{
        "--test-topbar-height": "5.5rem",
        "--test-bottombar-height": "9.5rem",
      }}
    >
      <div className="pointer-events-none absolute inset-0 z-0 overflow-hidden">
        <div className="absolute -top-40 -right-40 h-[48rem] w-[48rem] rounded-full bg-teal-500/5 blur-3xl" />
        <div className="absolute -bottom-40 -left-40 h-[36rem] w-[36rem] rounded-full bg-sky-500/5 blur-3xl" />
      </div>

      <TestRunnerTopBar
        onBack={goBack}
        onHome={goPatientHome}
        t={t}
        right={
          <div className="flex items-center gap-1.5 sm:gap-2 flex-shrink-0">
            <AudioToggle variant="dark" />
            <OfflineBadge />
            <LanguageSwitcher variant="dark" />
            {!quick && (
              <Button
                type="button"
                variant="outline"
                data-testid="skip-test"
                onClick={skip}
                aria-label={t("skip")}
                className="h-10 min-h-[40px] px-2 sm:px-3 rounded-xl border-white/15 bg-transparent text-slate-300 hover:bg-white/10 hover:text-slate-100 text-xs gap-1.5"
              >
                <SkipForward className="h-3.5 w-3.5 shrink-0" aria-hidden />
                <span className="hidden sm:inline">{t("skip")}</span>
              </Button>
            )}
          </div>
        }
      />

      <main className="absolute inset-0 z-20 flex min-h-0 flex-col overflow-hidden pb-[var(--test-bottombar-height)] pt-[var(--test-topbar-height)]">
        <AnimatePresence mode="wait">
          <motion.div
            key={test.id}
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -16 }}
            transition={{ duration: 0.38, ease: [0.22, 1, 0.36, 1] }}
            className="relative z-20 flex min-h-0 flex-1 flex-col"
          >
            <div className="relative flex min-h-0 flex-1 flex-col overflow-hidden">
              <TestComp
                patient={patientForTests}
                session={session}
                testMeta={test}
                flowIndex={displayIdx}
                flowTotal={totalSteps}
                flowLabels={quick ? [testLabel] : labels}
                onComplete={goNext}
              />
            </div>
          </motion.div>
        </AnimatePresence>
      </main>

      <TestRunnerBottomBar
        totalSteps={totalSteps}
        displayIdx={displayIdx}
        labels={labels}
        quick={quick}
        testLabel={testLabel}
      />
    </div>
  );
}
