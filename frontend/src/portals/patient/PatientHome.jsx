import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api, useAuthStore } from "@/core/auth/AuthStore";
import { toast } from "sonner";
import LanguageSwitcher from "@/components/ambyo/LanguageSwitcher";
import OfflineBadge from "@/components/ambyo/OfflineBadge";
import AudioToggle from "@/components/ambyo/AudioToggle";
import RiskBadge from "@/components/ambyo/RiskBadge";
import { queueSessionCreate } from "@/core/offline/db";
import { shouldQueue } from "@/core/offline/useOfflineSync";
import { useTheme } from "next-themes";
import AmbyoEyeLogo from "@/components/ambyo/AmbyoEyeLogo";
import { useI18n } from "@/core/i18n/translations";
import {
  LogOut,
  PlayCircle,
  FileText,
  ChevronRight,
  Shield,
  Sparkles,
  Hospital,
  ScanEye,
  Crosshair,
  Flashlight,
  Ruler,
  Layers,
  Sun,
  ArrowRight,
  UserPen,
  HeartPulse,
  ListChecks,
  LifeBuoy,
  ChevronDown,
  Moon,
} from "lucide-react";
import { motion } from "framer-motion";
import ScoreRing from "@/components/ambyo/ScoreRing";
import { Skeleton } from "@/components/ui/skeleton";
import { getTestFlowForAge, isTestAllowedForAge } from "@/core/clinical/ageTestRouter";

const TESTS = [
  { id: "visual_acuity", nameKey: "test_visual_acuity", descKey: "test_visual_acuity_desc", icon: ScanEye, color: "from-sky-500 to-blue-600", dur: "~60s" },
  { id: "gaze",          nameKey: "test_gaze",          descKey: "test_gaze_desc",          icon: Crosshair, color: "from-teal-400 to-emerald-600", dur: "~30s" },
  { id: "hirschberg",    nameKey: "test_hirschberg",    descKey: "test_hirschberg_desc",    icon: Flashlight, color: "from-amber-400 to-orange-500", dur: "~15s" },
  { id: "prism",         nameKey: "test_prism",         descKey: "test_prism_desc",         icon: Ruler,      color: "from-amber-300 to-amber-500", dur: "~5s"  },
  { id: "titmus",        nameKey: "test_titmus",        descKey: "test_titmus_desc",        icon: Layers,     color: "from-slate-500 to-teal-700", dur: "~60s" },
  { id: "red_reflex",    nameKey: "test_red_reflex",    descKey: "test_red_reflex_desc",    icon: Sun,        color: "from-rose-400 to-red-600", dur: "~15s" },
];

function testOrderForAge(age) {
  return getTestFlowForAge(age ?? 8).map((s) => s.id);
}

const inputCls =
  "w-full h-12 px-4 rounded-xl border border-slate-200 bg-white focus:outline-none focus:ring-2 focus:ring-[#0A2540]/20 focus:border-[#0A2540] transition-all";

function dobToDateInput(dob) {
  if (!dob || typeof dob !== "string") return "";
  return dob.length >= 10 ? dob.slice(0, 10) : "";
}

export default function PatientHome() {
  const nav = useNavigate();
  const { logout, patchUserPartial } = useAuthStore();
  const { theme, setTheme } = useTheme();
  const { t } = useI18n();
  const [data, setData] = useState({ patient: null, sessions: [] });
  const [loading, setLoading] = useState(true);
  const [profileForm, setProfileForm] = useState({
    name: "",
    date_of_birth: "",
    gender: "unspecified",
    guardian_name: "",
    guardian_relation: "Parent",
  });
  const [profileSaving, setProfileSaving] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);

  useEffect(() => {
    api.get("/patient/me").then((r) => setData(r.data)).catch(() => toast.error(t("err_could_not_load_profile"))).finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    const p = data.patient;
    if (!p) return;
    setProfileForm({
      name: p.name || "",
      date_of_birth: dobToDateInput(p.date_of_birth),
      gender: p.gender || "unspecified",
      guardian_name: p.guardian_name || "",
      guardian_relation: p.guardian_relation || "Parent",
    });
  }, [data.patient]);

  const nextTestIndexForSession = async (sessionId) => {
    try {
      const r = await api.get(`/sessions/${sessionId}`);
      const done = new Set((r.data.results || []).map((x) => x.test_name));
      const order = testOrderForAge(r.data.patient?.age ?? data.patient?.age);
      const next = order.findIndex((id) => !done.has(id));
      return next >= 0 ? next : 0;
    } catch {
      return 0;
    }
  };

  const resumeScreening = async (sessionId) => {
    const nextIndex = await nextTestIndexForSession(sessionId);
    nav(`/patient/session/${sessionId}/test/${nextIndex}`);
  };

  const startFullScreening = async () => {
    try {
      const c = await api.get(`/consent/${data.patient.id}`);
      if (!c.data || c.data.exists === false) { nav("/patient/consent"); return; }
      if (resumeSession) {
        await resumeScreening(resumeSession.id);
        return;
      }
      const s = await api.post("/sessions", { patient_id: data.patient.id });
      nav(`/patient/session/${s.data.id}/history`);
    } catch (e) {
      if (shouldQueue(e)) {
        await queueSessionCreate({ patient_id: data.patient.id });
        toast.message(t("offline_session_queued"));
        return;
      }
      toast.error(e?.response?.data?.detail || "Could not start");
    }
  };

  const startQuick = (testId) => { nav(`/patient/quick/${testId}`); };

  const setProfile = (k, v) => setProfileForm((f) => ({ ...f, [k]: v }));

  const saveProfile = async (e) => {
    e.preventDefault();
    if (!profileForm.name.trim() || !profileForm.date_of_birth) {
      toast.error(t("err_name_dob_required"));
      return;
    }
    setProfileSaving(true);
    try {
      const r = await api.patch("/patient/me", {
        name: profileForm.name.trim(),
        date_of_birth: profileForm.date_of_birth,
        gender: profileForm.gender,
        guardian_name: profileForm.guardian_name.trim() || null,
        guardian_relation: profileForm.guardian_relation.trim() || null,
      });
      setData((d) => ({ ...d, patient: r.data.patient }));
      patchUserPartial({ name: r.data.patient.name });
      toast.success(t("profile_updated"));
    } catch (err) {
      toast.error(err?.response?.data?.detail || t("err_could_not_save_profile"));
    } finally {
      setProfileSaving(false);
    }
  };

  const { patient, sessions } = data;
  const resumeSession = sessions.find((s) => s.status && s.status !== "completed");
  const lastCompleted = sessions.find((s) => s.status === "completed") || null;
  const lastAny = sessions[0] || null;
  const lastRisk = lastAny?.risk_level || patient?.last_risk_level || "normal";
  const lastDate = lastAny?.created_at ? new Date(lastAny.created_at) : null;
  const completedCountApprox =
    lastAny?.completed_tests_count ??
    (typeof lastAny?.tests_completed === "number" ? lastAny.tests_completed : null) ??
    null;

  const PREP = [
    t("prep_lighting"),
    t("prep_hold_steady"),
    t("prep_keep_face_in_frame"),
    t("prep_eye_level"),
    t("prep_reduce_distractions"),
    t("prep_guardian_help"),
  ];

  return (
    <div className="min-h-screen bg-slate-50 page-enter">
      <header className="bg-white/80 backdrop-blur border-b border-slate-200 sticky top-0 z-20">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div
              className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-rose-400 to-red-500 shadow-md shadow-rose-500/25"
              aria-hidden
              title="Eye care"
            >
              <HeartPulse className="size-5 text-white" strokeWidth={2.25} />
            </div>
            <AmbyoEyeLogo size={40} />
            <div>
              <div className="font-bold text-[#0A2540] leading-none tracking-tight">{t("app_name")}</div>
              <div className="text-[11px] text-slate-500 mt-0.5 flex items-center gap-1">
                <Hospital size={10} />
                <span className="inline-flex min-w-[140px]">
                  {loading ? <Skeleton className="h-3 w-[180px]" /> : (patient?.hospital_name || t("hospital"))}
                </span>
              </div>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <AudioToggle variant="light" />
            <button
              type="button"
              data-testid="theme-toggle"
              onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
              className="inline-flex items-center justify-center rounded-full border border-slate-200 bg-white px-2.5 py-2 text-slate-600 shadow-sm hover:bg-slate-100 transition-colors"
              aria-label={t("toggle_theme")}
              title={t("toggle_theme")}
            >
              <Moon size={16} />
            </button>
            <OfflineBadge />
            <LanguageSwitcher />
            <button data-testid="logout-btn" onClick={() => { logout(); nav("/"); }} className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm text-slate-600 hover:bg-slate-100 transition-colors">
              <LogOut size={14} /> {t("sign_out")}
            </button>
          </div>
        </div>
      </header>

      <main className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-10">
        {/* Big greeting card + health score */}
        <motion.section
          initial={{ y: 10, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          className="relative overflow-hidden rounded-3xl border border-slate-200 bg-gradient-to-br from-white via-white to-teal-50/40 p-6 shadow-sm sm:p-8"
        >
          <div className="pointer-events-none absolute inset-0 scan-grid opacity-25" />
          <div className="pointer-events-none absolute -top-24 -right-24 h-80 w-80 rounded-full bg-teal-400/15 blur-3xl" />
          <div className="pointer-events-none absolute -bottom-24 -left-24 h-72 w-72 rounded-full bg-sky-400/10 blur-3xl" />

          <div className="relative grid gap-6 md:grid-cols-[1fr_auto] md:items-center">
            <div>
              <div className="inline-flex items-center gap-2 rounded-full border border-slate-200 bg-white px-3 py-1 text-[11px] font-bold uppercase tracking-widest text-teal-700 shadow-sm">
                <Sparkles size={12} /> {t("patient_eye_health_dashboard")}
              </div>
              <h1 className="mt-4 text-3xl font-extrabold tracking-tight text-[#0A2540] sm:text-4xl">
                {t("patient_greeting_prefix", {
                  time:
                    new Date().getHours() < 12 ? t("morning") : new Date().getHours() < 18 ? t("afternoon") : t("evening"),
                })}{" "}
                <span className="bg-gradient-to-br from-teal-700 to-emerald-600 bg-clip-text text-transparent">
                  {loading ? "…" : (patient?.name?.split(" ")?.[0] || t("friend"))}
                </span>
              </h1>
              <p className="mt-2 max-w-2xl text-sm text-slate-600">
                {t("patient_home_intro")}
              </p>

              <div className="mt-5 grid gap-3 sm:grid-cols-2">
                <div className="rounded-2xl border border-slate-200 bg-white/70 p-4">
                  <div className="text-[10px] font-bold uppercase tracking-widest text-slate-500">{t("last_screening")}</div>
                  <div className="mt-2 flex items-center justify-between gap-3">
                    <div className="min-w-0">
                      <div className="text-sm font-semibold text-[#0A2540] truncate">
                        {lastDate ? lastDate.toLocaleString() : "—"}
                      </div>
                      <div className="mt-1 text-xs text-slate-500">
                        {lastCompleted ? t("completed_session") : lastAny ? t("in_progress_recent") : t("no_sessions_yet")}
                      </div>
                    </div>
                    <RiskBadge level={lastRisk} />
                  </div>
                </div>

                <div className="rounded-2xl border border-slate-200 bg-white/70 p-4">
                  <div className="text-[10px] font-bold uppercase tracking-widest text-slate-500">{t("progress")}</div>
                  <div className="mt-2 flex items-center justify-between gap-3">
                    <div className="text-sm font-semibold text-[#0A2540]">
                      {typeof completedCountApprox === "number"
                        ? t("tests_completed_of_6", { n: String(completedCountApprox) })
                        : t("continue_where_left_off")}
                    </div>
                    <span className="font-mono text-xs text-slate-500">
                      {resumeSession ? t("resume") : t("new")}
                    </span>
                  </div>
                </div>
              </div>

              {/* Start screening CTA (full-width, gradient, pulsing ring) */}
              <motion.button
                data-testid="start-screening"
                onClick={startFullScreening}
                whileHover={{ y: -2 }}
                whileTap={{ scale: 0.99 }}
                className="relative mt-6 w-full overflow-hidden rounded-3xl bg-gradient-to-r from-teal-500 via-emerald-500 to-sky-500 px-6 py-5 text-left font-bold text-white shadow-xl shadow-teal-500/20"
              >
                <motion.span
                  aria-hidden
                  className="absolute inset-0"
                  animate={{ opacity: [0.25, 0.55, 0.25] }}
                  transition={{ duration: 2.4, repeat: Infinity, ease: "easeInOut" }}
                  style={{
                    background:
                      "radial-gradient(900px circle at 30% 40%, rgba(255,255,255,0.22), transparent 40%)",
                  }}
                />
                <motion.span
                  aria-hidden
                  className="absolute right-6 top-1/2 h-20 w-20 -translate-y-1/2 rounded-full border-2 border-white/30"
                  animate={{ scale: [1, 1.18, 1], opacity: [0.55, 0, 0.55] }}
                  transition={{ duration: 1.8, repeat: Infinity, ease: "easeOut" }}
                />
                <span className="relative flex items-center justify-between gap-4">
                  <span className="flex items-center gap-3">
                    <span className="inline-flex h-11 w-11 items-center justify-center rounded-2xl bg-white/15">
                      <PlayCircle size={22} />
                    </span>
                    <span className="flex flex-col">
                      <span className="text-lg tracking-tight">
                        {resumeSession ? t("resume_screening") : t("start_full_screening")}
                      </span>
                      <span className="text-xs font-semibold text-white/85">
                        {resumeSession ? t("resume_next_test") : t("best_for_complete_check")}
                      </span>
                    </span>
                  </span>
                  <ArrowRight size={22} className="opacity-90" />
                </span>
              </motion.button>

              <div className="mt-3 inline-flex items-center gap-2 text-xs text-slate-500">
                <Shield size={14} className="text-teal-700" /> {t("encrypted_shared_care_team")}
              </div>
            </div>

            <div className="justify-self-center md:justify-self-end">
              <ScoreRing level={lastRisk} size={190} stroke={14} qualitative />
            </div>
          </div>
        </motion.section>

        <motion.section
          initial={{ y: 8, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.04 }}
          className="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8"
        >
          <div className="flex items-center gap-3">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-[#0A2540]/5 text-[#0A2540]">
              <ListChecks size={22} />
            </div>
            <div>
              <h2 className="text-xl font-bold tracking-tight text-[#0A2540]">{t("before_you_start")}</h2>
              <p className="text-sm text-slate-500">{t("before_you_start_subtitle")}</p>
            </div>
          </div>
          <ul className="mt-5 grid gap-3 sm:grid-cols-2">
            {PREP.map((line) => (
              <li key={line} className="flex gap-2 text-sm text-slate-700">
                <span className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-teal-500" />
                {line}
              </li>
            ))}
          </ul>
        </motion.section>

        {patient && (
          <motion.section
            initial={{ y: 8, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ delay: 0.05 }}
            className="overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-sm"
          >
            <button
              type="button"
              onClick={() => setProfileOpen((o) => !o)}
              className="flex w-full items-center justify-between gap-3 p-6 text-left sm:p-8"
            >
              <div className="flex items-center gap-3">
                <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-teal-50 text-teal-700">
                  <UserPen size={22} />
                </div>
                <div>
                  <h2 className="text-xl font-bold tracking-tight text-[#0A2540]">Your profile</h2>
                  <p className="text-sm text-slate-500">{t("your_profile_subtitle")}</p>
                </div>
              </div>
              <ChevronDown className={`text-slate-400 transition-transform ${profileOpen ? "rotate-180" : ""}`} size={22} />
            </button>
            {profileOpen && (
            <form onSubmit={saveProfile} className="space-y-5 border-t border-slate-100 px-6 pb-8 pt-2 sm:px-8">
              <label className="block">
                <span className="text-xs uppercase tracking-widest text-slate-500 font-semibold">{t("full_name")}</span>
                <input
                  data-testid="profile-name"
                  className={inputCls + " mt-2"}
                  value={profileForm.name}
                  onChange={(e) => setProfile("name", e.target.value)}
                  required
                />
              </label>
              <div className="grid sm:grid-cols-2 gap-5">
                <label className="block">
                  <span className="text-xs uppercase tracking-widest text-slate-500 font-semibold">{t("date_of_birth")}</span>
                  <input
                    data-testid="profile-dob"
                    type="date"
                    className={inputCls + " mt-2"}
                    value={profileForm.date_of_birth}
                    onChange={(e) => setProfile("date_of_birth", e.target.value)}
                    max={new Date().toISOString().split("T")[0]}
                    required
                  />
                </label>
                <label className="block">
                  <span className="text-xs uppercase tracking-widest text-slate-500 font-semibold">{t("gender")}</span>
                  <select
                    data-testid="profile-gender"
                    className={inputCls + " mt-2"}
                    value={profileForm.gender}
                    onChange={(e) => setProfile("gender", e.target.value)}
                  >
                    <option value="unspecified">{t("unspecified")}</option>
                    <option value="male">{t("male")}</option>
                    <option value="female">{t("female")}</option>
                  </select>
                </label>
              </div>
              <div className="grid sm:grid-cols-2 gap-5">
                <label className="block">
                  <span className="text-xs uppercase tracking-widest text-slate-500 font-semibold">{t("guardian_name")}</span>
                  <input
                    data-testid="profile-guardian-name"
                    className={inputCls + " mt-2"}
                    value={profileForm.guardian_name}
                    onChange={(e) => setProfile("guardian_name", e.target.value)}
                    placeholder={t("guardian_name_placeholder")}
                  />
                </label>
                <label className="block">
                  <span className="text-xs uppercase tracking-widest text-slate-500 font-semibold">{t("guardian_relation")}</span>
                  <select
                    data-testid="profile-guardian-relation"
                    className={inputCls + " mt-2"}
                    value={profileForm.guardian_relation}
                    onChange={(e) => setProfile("guardian_relation", e.target.value)}
                  >
                    <option>{t("relation_parent")}</option>
                    <option>{t("relation_mother")}</option>
                    <option>{t("relation_father")}</option>
                    <option>{t("relation_grandparent")}</option>
                    <option>{t("relation_guardian")}</option>
                    <option>{t("relation_self")}</option>
                  </select>
                </label>
              </div>
              <div className="pt-2 flex justify-end">
                <button
                  type="submit"
                  data-testid="save-profile-btn"
                  disabled={profileSaving}
                  className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-[#0A2540] text-white font-semibold shadow-md hover:bg-[#0D2E52] transition-all disabled:opacity-60"
                >
                  {profileSaving ? t("saving") : t("save_profile")}
                </button>
              </div>
            </form>
            )}
          </motion.section>
        )}

        {/* Quick tests grid (6 icon cards) */}
        <section className="space-y-4">
          <div className="flex items-end justify-between gap-3 flex-wrap">
            <div>
              <p className="text-xs uppercase tracking-widest text-teal-700 font-bold">{t("quick_tests")}</p>
              <h2 className="mt-1 text-2xl font-bold text-[#0A2540] tracking-tight">{t("run_single_test")}</h2>
              <p className="mt-1 text-sm text-slate-500">{t("quick_tests_subtitle")}</p>
            </div>
          </div>

          <motion.div
            initial="hidden"
            animate="show"
            variants={{ hidden: {}, show: { transition: { staggerChildren: 0.06 } } }}
            className="grid grid-cols-2 gap-4 md:grid-cols-3"
          >
            {TESTS.filter((item) => isTestAllowedForAge(item.id, data.patient?.age)).map((testItem) => {
              const Icon = testItem.icon;
              return (
                <motion.button
                  key={testItem.id}
                  variants={{ hidden: { y: 10, opacity: 0 }, show: { y: 0, opacity: 1 } }}
                  data-testid={`quick-${testItem.id}`}
                  onClick={() => startQuick(testItem.id)}
                  className="group relative overflow-hidden rounded-3xl border border-slate-200 bg-white p-5 text-left shadow-sm transition-all hover:-translate-y-0.5 hover:border-teal-300 hover:shadow-lg"
                >
                  <div className={`absolute inset-0 bg-gradient-to-br ${testItem.color} opacity-0 transition-opacity group-hover:opacity-[0.08]`} />
                  <div className="relative flex items-start justify-between gap-3">
                    <div className={`h-12 w-12 rounded-2xl bg-gradient-to-br ${testItem.color} flex items-center justify-center text-white shadow-md`}>
                      <Icon size={22} />
                    </div>
                    <span className="font-mono text-[10px] uppercase tracking-widest text-slate-400">{testItem.dur}</span>
                  </div>
                  <div className="relative">
                    <h3 className="mt-4 font-bold text-[#0A2540] tracking-tight">{t(testItem.nameKey)}</h3>
                    <p className="mt-1 text-sm text-slate-500 leading-snug">{t(testItem.descKey)}</p>
                    <div className="mt-4 inline-flex items-center gap-1 text-sm font-semibold text-teal-700">
                      {t("start")} <ChevronRight size={16} className="transition-transform group-hover:translate-x-0.5" />
                    </div>
                  </div>
                </motion.button>
              );
            })}
          </motion.div>
        </section>

        {/* Past screenings */}
        <section>
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-bold text-[#0A2540] tracking-tight">{t("past_screenings")}</h2>
            <span className="text-xs text-slate-400 font-mono">{t("session_count", { n: String(sessions.length) })}</span>
          </div>
          <div className="mt-4 bg-white border border-slate-200 rounded-2xl overflow-hidden divide-y divide-slate-100">
            {loading && (
              <div className="p-6 sm:p-8 space-y-4">
                {Array.from({ length: 3 }).map((_, i) => (
                  <div key={i} className="flex items-center justify-between gap-4">
                    <div className="flex items-center gap-4 min-w-0">
                      <Skeleton className="h-10 w-10 rounded-full" />
                      <div className="min-w-0 space-y-2">
                        <Skeleton className="h-4 w-[180px]" />
                        <Skeleton className="h-3 w-[240px]" />
                      </div>
                    </div>
                    <Skeleton className="h-6 w-[72px] rounded-full" />
                  </div>
                ))}
              </div>
            )}
            {!loading && sessions.length === 0 && (
              <div className="p-10 text-center"><p className="text-slate-500">{t("no_screenings_yet")}</p></div>
            )}
            {sessions.map((s) => (
              <button key={s.id}
                data-testid={`session-row-${s.id}`}
                onClick={() => s.status === "completed" ? nav(`/patient/session/${s.id}/results`) : resumeScreening(s.id)}
                className="w-full flex items-center justify-between gap-4 px-5 py-4 hover:bg-slate-50 transition-colors text-left"
              >
                <div className="flex items-center gap-4 min-w-0">
                  <div className="w-10 h-10 rounded-full bg-slate-100 text-slate-600 flex items-center justify-center"><FileText size={18} /></div>
                  <div className="min-w-0">
                    <div className="font-semibold text-[#0A2540] truncate">{t("screening_number", { n: s.id.slice(0, 6) })}</div>
                    <div className="text-xs text-slate-500 font-mono">{new Date(s.created_at).toLocaleString()} · {s.status}</div>
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  {s.risk_level && <RiskBadge level={s.risk_level} />}
                  <ChevronRight size={16} className="text-slate-400" />
                </div>
              </button>
            ))}
          </div>
        </section>

        <section className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <div className="flex items-center gap-3">
            <LifeBuoy className="text-teal-700" size={22} />
            <div>
              <h2 className="text-lg font-bold text-[#0A2540]">{t("help_support")}</h2>
              <p className="text-sm text-slate-500">
                {t("help_support_body_prefix")}{" "}
                <button type="button" className="font-medium text-teal-700 underline" onClick={() => nav("/patient/consent")}>
                  {t("consent_privacy")}
                </button>
                .
              </p>
            </div>
          </div>
        </section>
      </main>
    </div>
  );
}
