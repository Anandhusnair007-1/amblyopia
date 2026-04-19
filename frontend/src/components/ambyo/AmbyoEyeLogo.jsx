import { useEffect, useRef, useState } from "react";
import { motion } from "framer-motion";

/**
 * Signature AmbyoAI logo — an eye whose iris tracks the cursor.
 * Size scales uniformly. Use anywhere we want a living brand mark.
 */
export default function AmbyoEyeLogo({ size = 40, color = "#0A2540", irisColor = "#0D9488" }) {
  const wrapRef = useRef(null);
  const [offset, setOffset] = useState({ x: 0, y: 0 });

  useEffect(() => {
    const onMove = (e) => {
      const el = wrapRef.current;
      if (!el) return;
      const r = el.getBoundingClientRect();
      const cx = r.left + r.width / 2;
      const cy = r.top + r.height / 2;
      const dx = (e.clientX - cx) / 40;
      const dy = (e.clientY - cy) / 40;
      const max = size * 0.08;
      setOffset({
        x: Math.max(-max, Math.min(max, dx)),
        y: Math.max(-max, Math.min(max, dy)),
      });
    };
    window.addEventListener("mousemove", onMove);
    return () => window.removeEventListener("mousemove", onMove);
  }, [size]);

  const w = size, h = size;
  return (
    <div
      ref={wrapRef}
      className="relative inline-flex items-center justify-center rounded-xl overflow-hidden shadow-md"
      style={{ width: w, height: h, background: color }}
    >
      {/* eye white */}
      <svg width={w} height={h} viewBox="0 0 40 40">
        <defs>
          <radialGradient id="eyeWhite" cx="50%" cy="50%" r="50%">
            <stop offset="0" stopColor="#F8FAFC" />
            <stop offset="1" stopColor="#CBD5E1" />
          </radialGradient>
          <radialGradient id="iris" cx="50%" cy="50%" r="50%">
            <stop offset="0" stopColor={irisColor} />
            <stop offset="0.7" stopColor={irisColor} />
            <stop offset="1" stopColor="#0A2540" />
          </radialGradient>
        </defs>
        {/* Almond eye shape */}
        <path
          d="M4 20 Q20 6 36 20 Q20 34 4 20 Z"
          fill="url(#eyeWhite)"
        />
      </svg>
      {/* iris that tracks */}
      <motion.div
        animate={{ x: offset.x, y: offset.y }}
        transition={{ type: "spring", stiffness: 180, damping: 18 }}
        className="absolute"
        style={{ width: size * 0.42, height: size * 0.42 }}
      >
        <div
          className="w-full h-full rounded-full relative"
          style={{ background: `radial-gradient(circle at 35% 35%, ${irisColor}, ${color})` }}
        >
          <div className="absolute top-[18%] left-[18%] w-[28%] h-[28%] rounded-full bg-white" />
          <div className="absolute top-[60%] left-[60%] w-[14%] h-[14%] rounded-full bg-white/60" />
        </div>
      </motion.div>
    </div>
  );
}
