import { useI18n, LANGS } from "@/core/i18n/translations";

export default function LanguageSwitcher({ variant = "light" }) {
  const { lang, setLang } = useI18n();
  const inactive = variant === "dark" ? "text-slate-400 hover:text-slate-100" : "text-slate-500 hover:text-slate-700";
  const active = variant === "dark" ? "bg-slate-700 text-white" : "bg-white text-slate-900 shadow-sm";
  const wrap = variant === "dark" ? "bg-slate-800/70 border-slate-700" : "bg-slate-100 border-slate-200";
  return (
    <div className={`inline-flex items-center gap-1 p-1 rounded-lg border ${wrap}`} data-testid="language-switcher">
      {LANGS.map((l) => (
        <button
          key={l.code}
          data-testid={`lang-${l.code}`}
          onClick={() => setLang(l.code)}
          className={`px-3 py-1.5 rounded-md text-xs font-semibold tracking-wide transition-all ${lang === l.code ? active : inactive}`}
        >
          {l.label}
        </button>
      ))}
    </div>
  );
}
