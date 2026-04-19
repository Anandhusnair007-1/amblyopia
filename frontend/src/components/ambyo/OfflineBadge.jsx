import { useEffect, useState } from "react";
import { Wifi, WifiOff } from "lucide-react";

export default function OfflineBadge() {
  const [online, setOnline] = useState(navigator.onLine);
  useEffect(() => {
    const on = () => setOnline(true);
    const off = () => setOnline(false);
    window.addEventListener("online", on);
    window.addEventListener("offline", off);
    return () => {
      window.removeEventListener("online", on);
      window.removeEventListener("offline", off);
    };
  }, []);
  return (
    <span
      data-testid="offline-badge"
      className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-semibold uppercase tracking-wider border ${
        online ? "bg-emerald-50 text-emerald-700 border-emerald-200" : "bg-slate-100 text-slate-600 border-slate-200"
      }`}
    >
      {online ? <Wifi size={12} /> : <WifiOff size={12} />}
      {online ? "Online" : "Offline"}
    </span>
  );
}
