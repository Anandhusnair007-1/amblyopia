/**
 * Shared page title block for patient and staff surfaces (healthcare dashboard rhythm).
 */
export default function PageHeader({
  eyebrow,
  title,
  description,
  actions,
  className = "",
}) {
  return (
    <div className={`flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between ${className}`}>
      <div className="min-w-0">
        {eyebrow && (
          <p className="text-xs uppercase tracking-widest text-teal-700 font-bold">{eyebrow}</p>
        )}
        <h1 className="text-2xl sm:text-3xl font-bold text-[#0A2540] tracking-tight mt-0.5">{title}</h1>
        {description && (
          <p className="text-sm text-muted-foreground mt-1 max-w-2xl">{description}</p>
        )}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2 shrink-0">{actions}</div>}
    </div>
  );
}
