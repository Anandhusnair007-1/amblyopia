import { CheckCircle2, Loader2, WifiOff } from "lucide-react";
import { useOfflineSyncStore } from "@/core/offline/useOfflineSync";

export default function OfflineBadge() {
  const online = useOfflineSyncStore((s) => s.online);
  const syncing = useOfflineSyncStore((s) => s.syncing);
  const lastSyncAt = useOfflineSyncStore((s) => s.lastSyncAt);

  const state = !online ? "offline" : syncing ? "syncing" : lastSyncAt ? "synced" : "synced";
  const label = state === "offline" ? "Offline" : state === "syncing" ? "Syncing" : "Synced";
  const cls =
    state === "offline"
      ? "bg-slate-100 text-slate-600 border-slate-200"
      : state === "syncing"
        ? "bg-amber-50 text-amber-800 border-amber-200"
        : "bg-emerald-50 text-emerald-700 border-emerald-200";

  return (
    <span
      data-testid="offline-badge"
      className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-semibold uppercase tracking-wider border ${cls}`}
    >
      {state === "offline" ? (
        <WifiOff size={12} />
      ) : state === "syncing" ? (
        <Loader2 size={12} className="animate-spin" />
      ) : (
        <CheckCircle2 size={12} />
      )}
      {label}
    </span>
  );
}
