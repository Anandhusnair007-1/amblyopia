// Web Speech API wrapper – simple one-shot recognition
// Returns last transcript or empty string after listenFor ms.
export function recognizeOnce({ lang = "en-IN", listenMs = 12000 } = {}) {
  return new Promise((resolve) => {
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SR) return resolve({ transcript: "", ok: false, reason: "unsupported" });
    const rec = new SR();
    rec.lang = lang;
    rec.interimResults = true;
    rec.maxAlternatives = 3;
    rec.continuous = false;

    let final = "";
    let settled = false;

    const finish = (reason) => {
      if (settled) return;
      settled = true;
      try { rec.stop(); } catch (e) {}
      resolve({ transcript: final.trim(), ok: !!final.trim(), reason });
    };

    rec.onresult = (e) => {
      for (let i = e.resultIndex; i < e.results.length; i++) {
        const r = e.results[i];
        if (r.isFinal) final += " " + r[0].transcript;
        else final = r[0].transcript;
      }
    };
    rec.onerror = (e) => finish(`error:${e.error}`);
    rec.onend = () => finish("end");
    try { rec.start(); } catch { return finish("start-failed"); }
    setTimeout(() => finish("timeout"), listenMs);
  });
}

export function speechLangFor(code) {
  return { en: "en-IN", ta: "ta-IN", ml: "ml-IN", hi: "hi-IN" }[code] || "en-IN";
}
