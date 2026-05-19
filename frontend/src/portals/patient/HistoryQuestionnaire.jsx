import { useState } from "react";
import { useNavigate, useParams, useSearchParams } from "react-router-dom";
import { api } from "@/core/auth/AuthStore";
import { useI18n } from "@/core/i18n/translations";
import { toast } from "sonner";
import PageHeader from "@/components/shell/PageHeader";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { ArrowLeft, ClipboardList } from "lucide-react";
import { motion } from "framer-motion";

const QUESTIONS = [
  { key: "family_strabismus", tKey: "history_family_strabismus" },
  { key: "family_amblyopia", tKey: "history_family_amblyopia" },
  { key: "premature_birth", tKey: "history_premature_birth" },
  { key: "cataract_history", tKey: "history_cataract" },
  { key: "squint_noticed", tKey: "history_squint_noticed" },
  { key: "white_pupil_noticed", tKey: "history_white_pupil" },
  { key: "patching_before", tKey: "history_patching" },
  { key: "wears_glasses", tKey: "history_wears_glasses" },
  { key: "eye_surgery", tKey: "history_eye_surgery" },
  { key: "head_turn", tKey: "history_head_turn" },
];

export default function HistoryQuestionnaire() {
  const { sessionId } = useParams();
  const [search] = useSearchParams();
  const quickTarget = search.get("quick");
  const nav = useNavigate();
  const { t } = useI18n();
  const [answers, setAnswers] = useState(() =>
    Object.fromEntries(QUESTIONS.map((q) => [q.key, false]))
  );
  const [submitting, setSubmitting] = useState(false);

  const toggle = (key) => setAnswers((a) => ({ ...a, [key]: !a[key] }));

  const submit = async () => {
    setSubmitting(true);
    try {
      await api.post(`/sessions/${sessionId}/history`, { answers });
      if (quickTarget) {
        nav(`/patient/quick/${quickTarget}`);
        return;
      }
      nav(`/patient/session/${sessionId}/test/0`);
    } catch (e) {
      toast.error(e?.response?.data?.detail || t("err_could_not_save_history"));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen bg-background page-enter">
      <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} className="max-w-lg mx-auto px-4 py-8">
        <Button variant="ghost" className="mb-4 -ml-2" onClick={() => nav("/patient/consent")}>
          <ArrowLeft size={18} className="mr-2" /> {t("back")}
        </Button>
        <PageHeader
          icon={ClipboardList}
          eyebrow={t("history_eyebrow")}
          title={t("history_title")}
          subtitle={t("history_subtitle")}
        />
        <div className="mt-6 space-y-3">
          {QUESTIONS.map((q) => (
            <label
              key={q.key}
              className="flex items-center justify-between gap-4 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm cursor-pointer"
            >
              <span className="text-sm font-medium text-slate-800">{t(q.tKey)}</span>
              <Switch checked={!!answers[q.key]} onCheckedChange={() => toggle(q.key)} />
            </label>
          ))}
        </div>
        <Button
          data-testid="history-continue"
          className="mt-8 w-full h-12 rounded-xl"
          disabled={submitting}
          onClick={submit}
        >
          {submitting ? t("saving") : t("history_continue")}
        </Button>
      </motion.div>
    </div>
  );
}
