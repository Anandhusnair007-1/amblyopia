import { useState, useEffect } from "react";
import { X } from "lucide-react";
import { Button } from "@/components/ui/button";
import ContactAttemptTimeline from "@/components/referrals/ContactAttemptTimeline";
import AuditActionNotice from "@/components/clinical/AuditActionNotice";

const STATUSES = [
  "new",
  "assigned",
  "contacted",
  "appointment_scheduled",
  "completed",
  "closed",
];

export default function ReferralDetailDrawer({ row, open, onClose, canPatch, onUpdated }) {
  const [note, setNote] = useState("");
  const [outcome, setOutcome] = useState("");
  const [nextFollowUp, setNextFollowUp] = useState("");
  const [status, setStatus] = useState(row?.status || "new");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (row) setStatus(row.status || "new");
  }, [row]);

  if (!open || !row) return null;

  const overdue =
    row.sla_due_at && row.sla_status === "breached" ? true : false;

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <button type="button" className="absolute inset-0 bg-black/40" aria-label="Close drawer" onClick={onClose} />
      <div className="relative flex h-full w-full max-w-md flex-col border-l border-border bg-card shadow-2xl">
        <div className="flex items-center justify-between border-b border-border px-4 py-3">
          <h2 className="text-lg font-semibold text-[#0A2540]">Referral</h2>
          <button type="button" className="rounded-lg p-2 text-muted-foreground hover:bg-muted" onClick={onClose}>
            <X size={20} />
          </button>
        </div>
        <div className="flex-1 space-y-6 overflow-y-auto p-4">
          {overdue && (
            <div className="rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm font-medium text-red-900">
              SLA overdue — escalate if still unresolved.
            </div>
          )}
          {row.escalation_flag && (
            <div className="rounded-xl border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-950">
              Escalation flagged
            </div>
          )}
          <div className="text-sm">
            <div className="font-mono text-xs text-muted-foreground">Session</div>
            <div className="font-medium">{row.session_id}</div>
          </div>
          <div>
            <div className="text-xs font-medium text-muted-foreground">Pipeline status</div>
            <div className="mt-2 flex flex-wrap gap-1">
              {STATUSES.map((s) => (
                <span
                  key={s}
                  className={`rounded-full px-2 py-0.5 text-xs ${
                    s === row.status ? "bg-[#0A2540] text-white" : "bg-muted text-muted-foreground"
                  }`}
                >
                  {s.replace(/_/g, " ")}
                </span>
              ))}
            </div>
          </div>
          <div className="text-sm">
            <span className="text-muted-foreground">SLA due</span>{" "}
            <span className="font-mono">{row.sla_due_at || "—"}</span> ({row.sla_status || "—"})
          </div>
          <div>
            <h3 className="text-sm font-semibold text-[#0A2540]">Contact timeline</h3>
            <div className="mt-2">
              <ContactAttemptTimeline attempts={row.contact_attempts || []} />
            </div>
          </div>
          {canPatch && (
            <div className="space-y-3 border-t border-border pt-4">
              <AuditActionNotice />
              <label className="block text-xs font-medium text-muted-foreground">
                Set status
                <select
                  className="mt-1 w-full rounded-lg border border-input bg-background px-2 py-2 text-sm"
                  value={status}
                  onChange={(e) => setStatus(e.target.value)}
                >
                  {STATUSES.map((s) => (
                    <option key={s} value={s}>
                      {s}
                    </option>
                  ))}
                </select>
              </label>
              <label className="block text-xs font-medium text-muted-foreground">
                Contact note
                <textarea
                  className="mt-1 w-full rounded-lg border border-input bg-background px-2 py-2 text-sm"
                  rows={2}
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                />
              </label>
              <label className="block text-xs font-medium text-muted-foreground">
                Outcome
                <input
                  className="mt-1 w-full rounded-lg border border-input bg-background px-2 py-2 text-sm"
                  value={outcome}
                  onChange={(e) => setOutcome(e.target.value)}
                />
              </label>
              <label className="block text-xs font-medium text-muted-foreground">
                Next follow-up (date)
                <input
                  type="date"
                  className="mt-1 w-full rounded-lg border border-input bg-background px-2 py-2 text-sm"
                  value={nextFollowUp}
                  onChange={(e) => setNextFollowUp(e.target.value)}
                />
              </label>
              <Button
                type="button"
                disabled={saving}
                className="w-full"
                onClick={async () => {
                  setSaving(true);
                  try {
                    await onUpdated(row.id, {
                      status,
                      next_follow_up_at: nextFollowUp || null,
                      contact_attempt:
                        note || outcome
                          ? { channel: "phone", note: note || "—", outcome: outcome || "—" }
                          : undefined,
                    });
                    setNote("");
                    setOutcome("");
                  } finally {
                    setSaving(false);
                  }
                }}
              >
                {saving ? "Saving…" : "Save update"}
              </Button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
