import { useEffect, useRef, useState } from "react";

/**
 * WebRTC front-camera feed with callback on each animation frame.
 * onFrame(videoEl, tsMs) fires inside requestAnimationFrame.
 */
export default function WebRTCCamera({ onFrame, onReady, className = "", mirrored = true, hidden = false }) {
  const videoRef = useRef(null);
  const rafRef = useRef(0);
  const [error, setError] = useState(null);

  useEffect(() => {
    let stream;
    const start = async () => {
      try {
        stream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: "user", width: { ideal: 640 }, height: { ideal: 480 } },
          audio: false,
        });
        const v = videoRef.current;
        if (!v) return;
        v.srcObject = stream;
        await v.play();
        onReady && onReady(v);
        const loop = (ts) => {
          if (onFrame && v.readyState >= 2) onFrame(v, ts);
          rafRef.current = requestAnimationFrame(loop);
        };
        rafRef.current = requestAnimationFrame(loop);
      } catch (e) {
        console.error("Camera error", e);
        setError(e.message || "Camera unavailable");
      }
    };
    start();
    return () => {
      cancelAnimationFrame(rafRef.current);
      if (stream) stream.getTracks().forEach((t) => t.stop());
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className={`${className} ${hidden ? "opacity-0 pointer-events-none absolute" : ""}`}>
      {error ? (
        <div className="p-4 text-sm text-red-400 bg-red-500/10 rounded-xl border border-red-500/30">
          Camera error: {error}
        </div>
      ) : (
        <video
          ref={videoRef}
          playsInline
          muted
          data-testid="camera-feed"
          className={`w-full h-full object-cover rounded-xl ${mirrored ? "scale-x-[-1]" : ""}`}
        />
      )}
    </div>
  );
}
