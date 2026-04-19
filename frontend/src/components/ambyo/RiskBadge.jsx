const STYLES = {
  normal: "bg-emerald-50 text-emerald-700 border-emerald-200",
  mild: "bg-amber-50 text-amber-700 border-amber-200",
  moderate: "bg-orange-50 text-orange-700 border-orange-200",
  urgent: "bg-red-50 text-red-700 border-red-300",
};
const LABEL = { normal: "Normal", mild: "Mild", moderate: "Moderate", urgent: "Urgent" };

export default function RiskBadge({ level = "normal", className = "" }) {
  return (
    <span
      data-testid={`risk-badge-${level}`}
      className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-md text-xs font-bold uppercase tracking-wider border ${STYLES[level] || STYLES.normal} ${className} ${level === "urgent" ? "animate-pulse" : ""}`}
    >
      {level === "urgent" && <span>●</span>}
      {LABEL[level] || level}
    </span>
  );
}
