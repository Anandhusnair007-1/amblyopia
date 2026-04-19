import { useEffect, useRef, useState } from "react";
import { animate } from "framer-motion";

/** Animates a number from 0 → value on mount. */
export default function CountUp({ value, duration = 1.2, className = "", suffix = "" }) {
  const [display, setDisplay] = useState(0);
  const controlRef = useRef(null);
  useEffect(() => {
    if (value == null) return;
    controlRef.current?.stop?.();
    controlRef.current = animate(0, Number(value) || 0, {
      duration,
      ease: [0.22, 1, 0.36, 1],
      onUpdate: (v) => setDisplay(v),
    });
    return () => controlRef.current?.stop?.();
  }, [value, duration]);
  const rounded = Number.isFinite(display) ? Math.round(display) : 0;
  return <span className={className}>{rounded}{suffix}</span>;
}
