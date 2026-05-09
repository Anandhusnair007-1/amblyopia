import RiskBadge from "@/components/ambyo/RiskBadge";
import { maskPhone } from "@/lib/maskPhone";

/**
 * Hospital-style patient strip for clinical and referral surfaces.
 * Props mirror session + patient payloads from `/sessions/:id`.
 */
export default function PatientContextBar({
  patient,
  session,
  prediction,
  consentSummary,
  className = "",
  phoneMode = "masked",
}) {
  if (!patient) return null;
  const risk = prediction?.risk_level || patient.last_risk_level || "normal";
  const lastScreen =
    session?.completed_at || session?.created_at || patient.last_session_date || "—";
  const consent = consentSummary ?? "On file";
  const phone =
    phoneMode === "full" ? patient.phone || "—" : maskPhone(patient.phone);
  const mrn = patient.mrn?.trim() || `ID …${(patient.id || "").slice(-6)}`;

  return (
    <div
      className={`flex flex-wrap items-center gap-x-4 gap-y-2 border-b border-border bg-muted/30 px-4 py-3 text-sm md:px-6 ${className}`}
      data-testid="patient-context-bar"
    >
      <div className="min-w-0 font-semibold text-[#0A2540]">
        <span className="truncate">{patient.name}</span>
        <span className="ml-2 font-normal text-muted-foreground">
          {patient.age != null ? `${patient.age}y` : ""}{" "}
          {patient.gender && patient.gender !== "unspecified" ? `· ${patient.gender}` : ""}
        </span>
      </div>
      <span className="hidden h-4 w-px bg-border sm:inline" aria-hidden />
      <span className="font-mono text-xs text-muted-foreground">MRN {mrn}</span>
      <span className="hidden h-4 w-px bg-border sm:inline" aria-hidden />
      <span className="text-muted-foreground">
        Phone <span className="font-mono text-foreground">{phone}</span>
      </span>
      <span className="hidden h-4 w-px bg-border sm:inline" aria-hidden />
      <RiskBadge level={risk} />
      <span className="hidden h-4 w-px bg-border sm:inline" aria-hidden />
      <span className="text-xs text-muted-foreground">
        Last screening:{" "}
        <span className="font-medium text-foreground">
          {typeof lastScreen === "string" && lastScreen.includes("T")
            ? new Date(lastScreen).toLocaleString()
            : lastScreen}
        </span>
      </span>
      <span className="hidden h-4 w-px bg-border md:inline" aria-hidden />
      <span className="text-xs text-muted-foreground">
        Consent: <span className="font-medium text-foreground">{consent}</span>
      </span>
    </div>
  );
}
