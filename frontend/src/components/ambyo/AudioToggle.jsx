import { Volume2, VolumeX } from "lucide-react";
import { useAudioStore } from "@/core/audio/AudioGuide";

export default function AudioToggle({ variant = "dark" }) {
  const { muted, toggle, speakingKey } = useAudioStore();
  const base = "relative inline-flex items-center justify-center w-10 h-10 rounded-full transition-all";
  const style = variant === "dark"
    ? "bg-white/5 border border-white/10 text-slate-200 hover:bg-white/10"
    : "bg-slate-100 border border-slate-200 text-slate-600 hover:bg-slate-200";
  return (
    <button
      data-testid="audio-toggle"
      onClick={toggle}
      aria-label={muted ? "Unmute audio" : "Mute audio"}
      title={muted ? "Unmute audio" : "Mute audio"}
      className={`${base} ${style}`}
    >
      {muted ? <VolumeX size={16} /> : <Volume2 size={16} />}
      {!muted && speakingKey && (
        <span className="absolute inset-0 rounded-full border-2 border-teal-400/60 animate-pulse-ring" />
      )}
    </button>
  );
}
