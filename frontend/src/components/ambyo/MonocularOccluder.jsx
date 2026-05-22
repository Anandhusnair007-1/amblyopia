import { motion } from "framer-motion";
import { Eye } from "lucide-react";
import { useI18n } from "@/core/i18n/translations";

/**
 * @param {{ testingEye: 'OD' | 'OS', onContinue: () => void }} props
 * OD = right eye tested → cover left
 */
export default function MonocularOccluder({ testingEye, onContinue }) {
  const { t } = useI18n();
  const coverSide = testingEye === "OD" ? "left" : "right";

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="absolute inset-0 z-50 flex flex-col items-center justify-center bg-[#0A0F1C]/95 px-6"
    >
      <motion.div
        initial={{ scale: 0.9, y: 12 }}
        animate={{ scale: 1, y: 0 }}
        className="max-w-md w-full rounded-3xl border border-white/10 bg-white/5 p-8 text-center backdrop-blur-xl"
      >
        <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-2xl bg-sky-500/20 text-sky-300">
          <Eye size={32} />
        </div>
        <p className="text-xs font-bold uppercase tracking-[0.25em] text-sky-400">
          {t("va_testing_eye", { eye: testingEye })}
        </p>
        <h2 className="mt-3 text-2xl font-bold text-white">
          {t(`va_cover_${coverSide}`)}
        </h2>
        <p className="mt-3 text-sm text-slate-300 leading-relaxed">
          {t("va_cover_instruction")}
        </p>
        <p className="mt-2 text-xs text-slate-500">{t("va_distance_40cm")}</p>
        <button
          type="button"
          data-testid="occluder-continue"
          onClick={onContinue}
          className="mt-8 w-full rounded-2xl bg-teal-500 py-3.5 font-bold text-[#0A0F1C] shadow-lg hover:bg-teal-400 active:scale-[0.99] transition-all"
        >
          {t("va_ready_continue")}
        </button>
      </motion.div>
    </motion.div>
  );
}
