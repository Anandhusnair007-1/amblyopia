export default function TestProgressBar({ total, index, labels = [] }) {
  return (
    <div className="w-full" data-testid="test-progress">
      <div className="flex items-center justify-between text-[11px] uppercase tracking-widest text-slate-400 mb-2 font-semibold">
        <span>Step {Math.min(index + 1, total)} / {total}</span>
        <span className="font-mono">{labels[index] || ""}</span>
      </div>
      <div className="w-full flex gap-1.5 h-2 rounded-full overflow-hidden">
        {Array.from({ length: total }).map((_, i) => (
          <div
            key={i}
            className={`flex-1 rounded-full transition-all duration-500 ${
              i < index ? "bg-teal-400" :
              i === index ? "bg-sky-400 animate-pulse" :
              "bg-slate-700/60"
            }`}
          />
        ))}
      </div>
    </div>
  );
}
