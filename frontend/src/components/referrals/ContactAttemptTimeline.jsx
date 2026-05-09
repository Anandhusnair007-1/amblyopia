export default function ContactAttemptTimeline({ attempts = [] }) {
  if (!attempts.length) {
    return <p className="text-sm text-muted-foreground">No contact attempts logged yet.</p>;
  }
  return (
    <ol className="relative space-y-4 border-l border-border pl-6">
      {attempts.map((a, i) => (
        <li key={`${a.at}-${i}`} className="text-sm">
          <span className="absolute -left-[5px] mt-1.5 h-2.5 w-2.5 rounded-full border border-background bg-teal-600" />
          <div className="font-mono text-xs text-muted-foreground">{a.at}</div>
          <div className="mt-0.5 text-foreground">
            <span className="font-medium">{a.channel || "phone"}</span>
            {a.outcome ? ` · ${a.outcome}` : ""}
          </div>
          {a.note ? <p className="mt-1 text-muted-foreground">{a.note}</p> : null}
        </li>
      ))}
    </ol>
  );
}
