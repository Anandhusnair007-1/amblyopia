import { useEffect, useRef, useState, useLayoutEffect } from "react";

/**
 * Try progressively looser constraints — "user" facingMode fails on many laptops / external cams.
 */
async function acquireVideoStream(signal) {
  if (!navigator.mediaDevices?.getUserMedia) {
    throw new Error("Camera API not available (use HTTPS or localhost, or update your browser)");
  }

  const attempts = [
    { video: { facingMode: { ideal: "user" }, width: { ideal: 640 }, height: { ideal: 480 } }, audio: false },
    { video: { width: { ideal: 640 }, height: { ideal: 480 } }, audio: false },
    { video: true, audio: false },
  ];

  let lastErr;
  for (const constraints of attempts) {
    if (signal.aborted) throw new DOMException("Aborted", "AbortError");
    try {
      return await navigator.mediaDevices.getUserMedia(constraints);
    } catch (e) {
      lastErr = e;
      if (e?.name === "NotAllowedError" || e?.name === "SecurityError") break;
    }
  }
  throw lastErr;
}

/**
 * WebRTC camera feed with optional per-frame callback.
 * Handles React Strict Mode (double mount): aborts in-flight getUserMedia and avoids double-open races.
 */
export default function WebRTCCamera({ onFrame, onReady, className = "", mirrored = true, hidden = false }) {
  const videoRef = useRef(null);
  const rafRef = useRef(0);
  const [error, setError] = useState(null);
  const onFrameRef = useRef(onFrame);
  const onReadyRef = useRef(onReady);

  useLayoutEffect(() => {
    onFrameRef.current = onFrame;
    onReadyRef.current = onReady;
  });

  useEffect(() => {
    const ac = new AbortController();
    const { signal } = ac;
    let stream;

    const start = async () => {
      setError(null);
      try {
        // One short retry helps after Strict Mode tears down the first stream (camera still releasing).
        const tryOpen = async () => {
          try {
            return await acquireVideoStream(signal);
          } catch (e) {
            if (signal.aborted) throw e;
            if (e?.name === "NotReadableError" || e?.name === "TrackStartError") {
              await new Promise((r) => setTimeout(r, 400));
              if (signal.aborted) throw new DOMException("Aborted", "AbortError");
              return acquireVideoStream(signal);
            }
            throw e;
          }
        };

        stream = await tryOpen();
        if (signal.aborted) {
          stream.getTracks().forEach((t) => t.stop());
          return;
        }

        const v = videoRef.current;
        if (!v) {
          stream.getTracks().forEach((t) => t.stop());
          return;
        }

        v.srcObject = stream;
        await v.play();
        if (signal.aborted) {
          stream.getTracks().forEach((t) => t.stop());
          return;
        }

        onReadyRef.current?.(v);

        const loop = (ts) => {
          if (signal.aborted) return;
          const fn = onFrameRef.current;
          if (fn && v.readyState >= 2) fn(v, ts);
          rafRef.current = requestAnimationFrame(loop);
        };
        rafRef.current = requestAnimationFrame(loop);
      } catch (e) {
        if (signal.aborted) return;
        console.error("Camera error", e);
        const name = e?.name || "";
        let msg = e?.message || "Camera unavailable";
        if (name === "NotAllowedError") msg = "Camera permission denied — allow camera for this site.";
        else if (name === "NotFoundError" || name === "DevicesNotFoundError") msg = "No camera found.";
        else if (name === "NotReadableError" || name === "TrackStartError") {
          msg = "Camera is in use or unavailable — close other apps/tabs using the camera and try again.";
        }
        setError(msg);
      }
    };

    start();

    return () => {
      ac.abort();
      cancelAnimationFrame(rafRef.current);
      rafRef.current = 0;
      if (stream) stream.getTracks().forEach((t) => t.stop());
      const v = videoRef.current;
      if (v) v.srcObject = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className={`${className} pointer-events-none overflow-hidden ${hidden ? "opacity-0" : ""}`}>
      {error ? (
        <div
          role="alert"
          className="pointer-events-auto fixed bottom-[calc(var(--test-bottombar-height,8rem)+1rem)] left-4 right-4 z-50 mx-auto max-w-lg rounded-xl border border-red-500/40 bg-red-950/90 p-4 text-sm text-red-100 shadow-2xl sm:left-1/2 sm:right-auto sm:w-full sm:-translate-x-1/2"
        >
          Camera error: {error}
        </div>
      ) : (
        <video
          ref={videoRef}
          playsInline
          muted
          autoPlay
          data-testid="camera-feed"
          className={`h-full w-full object-cover ${mirrored ? "scale-x-[-1]" : ""}`}
        />
      )}
    </div>
  );
}
