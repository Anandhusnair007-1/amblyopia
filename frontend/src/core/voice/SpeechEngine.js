// Web Speech API — one-shot recognition with TTS coordination.
import { stopSpeaking, waitForSpeechIdle } from "@/core/audio/AudioGuide";

export function isSpeechRecognitionSupported() {
  return !!(window.SpeechRecognition || window.webkitSpeechRecognition);
}

export function speechLangFor(code) {
  return { en: "en-IN", ta: "ta-IN", ml: "ml-IN", hi: "hi-IN" }[code] || "en-IN";
}

/**
 * Listen once for a spoken answer.
 * - Stops TTS first (mic + speaker conflict on mobile Chrome).
 * - Uses continuous mode so short pauses do not end the session early.
 * - Resolves on timeout, final transcript, or unrecoverable error.
 */
export async function recognizeOnce({
  lang = "en-IN",
  listenMs = 10000,
  minListenMs = 1200,
  silenceMs = 1400,
} = {}) {
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!SR) {
    return { transcript: "", ok: false, reason: "unsupported" };
  }

  stopSpeaking();
  await waitForSpeechIdle(400);

  return new Promise((resolve) => {
    const rec = new SR();
    rec.lang = lang;
    rec.interimResults = true;
    rec.continuous = true;
    rec.maxAlternatives = 5;

    const finals = [];
    let interim = "";
    let settled = false;
    const startedAt = performance.now();
    let silenceTimer = null;

    const transcript = () => finals.join(" ").trim() || interim.trim();

    const finish = (reason) => {
      if (settled) return;
      settled = true;
      if (silenceTimer) clearTimeout(silenceTimer);
      clearTimeout(hardTimeout);
      try {
        rec.onresult = null;
        rec.onerror = null;
        rec.onend = null;
        rec.stop();
      } catch {
        /* ignore */
      }
      const text = transcript();
      resolve({ transcript: text, ok: !!text, reason });
    };

    const scheduleSilenceFinish = () => {
      if (silenceTimer) clearTimeout(silenceTimer);
      if (!transcript()) return;
      if (performance.now() - startedAt < minListenMs) return;
      silenceTimer = setTimeout(() => finish("silence"), silenceMs);
    };

    const hardTimeout = setTimeout(() => finish("timeout"), listenMs);

    rec.onresult = (e) => {
      for (let i = e.resultIndex; i < e.results.length; i++) {
        const r = e.results[i];
        const piece = (r[0]?.transcript || "").trim();
        if (!piece) continue;
        if (r.isFinal) {
          finals.push(piece);
          interim = "";
        } else {
          interim = piece;
        }
      }
      scheduleSilenceFinish();
    };

    rec.onerror = (e) => {
      const err = e?.error || "unknown";
      // no-speech / aborted are common when user is quiet or we stop() — wait for timeout unless we already have text
      if ((err === "no-speech" || err === "aborted") && transcript()) {
        scheduleSilenceFinish();
        return;
      }
      if (err === "not-allowed" || err === "service-not-allowed") {
        finish(`error:${err}`);
        return;
      }
      if (transcript() && performance.now() - startedAt >= minListenMs) {
        finish(`error:${err}`);
      }
    };

    rec.onend = () => {
      // Chrome often ends the session after a pause; restart until timeout if we are still listening.
      if (settled) return;
      if (transcript() && performance.now() - startedAt >= minListenMs) {
        finish("end");
        return;
      }
      if (performance.now() - startedAt < listenMs - 300) {
        try {
          rec.start();
        } catch {
          finish("end");
        }
      }
    };

    try {
      rec.start();
    } catch {
      finish("start-failed");
    }
  });
}
