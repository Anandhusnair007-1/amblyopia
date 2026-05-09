/** Shown before logged clinical or export actions. */
export default function AuditActionNotice({ className = "" }) {
  return (
    <p className={`text-xs text-muted-foreground ${className}`} role="note">
      This action is recorded in the audit log.
    </p>
  );
}
