import { Mic, MicOff } from "lucide-react";

export default function MicIndicator({ active, transcript, listening }) {
  return (
    <div className="inline-flex items-center gap-3" data-testid="mic-indicator">
      <div className={`relative w-11 h-11 rounded-full flex items-center justify-center border ${
        active ? "bg-sky-500/20 border-sky-400/60 text-sky-300" : "bg-slate-800/70 border-slate-700 text-slate-400"
      }`}>
        {active ? <Mic size={18} /> : <MicOff size={18} />}
        {listening && (
          <span className="absolute inset-0 rounded-full border-2 border-sky-400/60 animate-pulse-ring" />
        )}
      </div>
      {transcript ? (
        <span className="text-sm text-slate-200 max-w-[260px] truncate font-mono">“{transcript}”</span>
      ) : null}
    </div>
  );
}
