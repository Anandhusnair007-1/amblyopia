// AudioGuide — Text-to-Speech narration for tests (multilingual)
// Uses Web Speech Synthesis API with language-matched voice selection.
import { create } from "zustand";

const LANG_MAP = { en: "en-IN", ta: "ta-IN", ml: "ml-IN", hi: "hi-IN" };

let voicesCache = null;
let loadingVoices = null;

const loadVoices = () =>
  new Promise((resolve) => {
    if (!("speechSynthesis" in window)) return resolve([]);
    const v = window.speechSynthesis.getVoices();
    if (v && v.length) return resolve(v);
    const handler = () => {
      resolve(window.speechSynthesis.getVoices());
      window.speechSynthesis.removeEventListener("voiceschanged", handler);
    };
    window.speechSynthesis.addEventListener("voiceschanged", handler);
    setTimeout(() => resolve(window.speechSynthesis.getVoices() || []), 800);
  });

const ensureVoices = async () => {
  if (voicesCache) return voicesCache;
  if (!loadingVoices) loadingVoices = loadVoices();
  voicesCache = await loadingVoices;
  return voicesCache;
};

const pickVoice = (voices, bcp47) => {
  if (!voices?.length) return null;
  const exact = voices.find((v) => v.lang?.toLowerCase() === bcp47.toLowerCase());
  if (exact) return exact;
  const prefix = bcp47.split("-")[0].toLowerCase();
  return voices.find((v) => v.lang?.toLowerCase().startsWith(prefix)) || null;
};

export const useAudioStore = create((set, get) => ({
  muted: localStorage.getItem("ambyoai.muted") === "1",
  speakingKey: null,
  setMuted: (m) => {
    localStorage.setItem("ambyoai.muted", m ? "1" : "0");
    if (m) window.speechSynthesis?.cancel?.();
    set({ muted: m });
  },
  toggle: () => get().setMuted(!get().muted),
}));

/** Speak a string in the current language. Resolves when done (or immediately if muted). */
export async function speak(text, { lang = "en", rate = 0.95, pitch = 1.0, key = null } = {}) {
  if (!("speechSynthesis" in window)) return;
  if (useAudioStore.getState().muted) return;
  try {
    window.speechSynthesis.cancel(); // interrupt any previous
  } catch (e) {}
  const voices = await ensureVoices();
  const utter = new SpeechSynthesisUtterance(text);
  const bcp47 = LANG_MAP[lang] || "en-IN";
  const v = pickVoice(voices, bcp47);
  if (v) utter.voice = v;
  utter.lang = bcp47;
  utter.rate = rate;
  utter.pitch = pitch;
  useAudioStore.setState({ speakingKey: key });
  return new Promise((resolve) => {
    utter.onend = () => {
      useAudioStore.setState({ speakingKey: null });
      resolve();
    };
    utter.onerror = () => {
      useAudioStore.setState({ speakingKey: null });
      resolve();
    };
    try { window.speechSynthesis.speak(utter); } catch { resolve(); }
  });
}

export function stopSpeaking() {
  try { window.speechSynthesis.cancel(); } catch (e) {}
}

// Pre-written narration scripts per test, per language.
// Keep sentences short and slow — children comprehension.
export const NARRATION = {
  visual_acuity: {
    en: "Visual acuity test. Sit about forty centimetres from the screen. When a letter appears, tell me which direction it points. Up, down, left, or right.",
    ta: "பார்வை சோதனை. திரைக்கு நாற்பது சென்டிமீட்டர் தூரத்தில் உட்காரவும். எழுத்து தோன்றும்போது அது எந்த திசையை நோக்கியது என சொல்லுங்கள்.",
    ml: "കാഴ്ച പരിശോധന. സ്ക്രീനിൽ നിന്ന് നാല്‍പ്പത് സെന്റിമീറ്റർ ദൂരത്തിൽ ഇരിക്കുക. അക്ഷരം കാണുമ്പോൾ ദിശ പറയുക.",
  },
  gaze: {
    en: "Gaze test. Keep your head still and follow the blue dot with only your eyes. Nine dots will appear.",
    ta: "கண் பார்வை சோதனை. தலையை அசைக்காதீர்கள். கண்களால் மட்டும் நீல புள்ளியை பின்தொடருங்கள்.",
    ml: "നോട്ടം പരിശോധന. തല അനക്കാതെ കണ്ണുകൾ കൊണ്ട് നീല പൊട്ട് പിന്തുടരുക.",
  },
  hirschberg: {
    en: "Hirschberg test. A bright white flash will appear for two seconds. Keep your eyes open and look at the centre of the screen.",
    ta: "ஹிர்ஷ்பர்க் சோதனை. ஒளி வெளிச்சம் இரண்டு விநாடிகள் தோன்றும். கண்களை திறந்து திரையின் மையத்தை பார்க்கவும்.",
    ml: "ഹിര്‍ഷ്ബര്‍ഗ് പരിശോധന. രണ്ട് സെക്കൻ്റ് വെളുത്ത വെളിച്ചം തിളങ്ങും. സ്ക്രീൻ്റെ മധ്യഭാഗത്ത് നോക്കുക.",
  },
  prism: {
    en: "Prism diopter measurement. Calculated from your previous results. Please wait.",
    ta: "ப்ரிஸ்ம் அளவீடு. முந்தைய முடிவுகளிலிருந்து கணக்கிடப்படுகிறது.",
    ml: "പ്രിസം അളവ്. മുൻ ഫലങ്ങളിൽ നിന്ന് കണക്കാക്കുന്നു.",
  },
  titmus: {
    en: "Depth perception test. Look at the pictures and tell me what you see.",
    ta: "ஆழம் பார்வை சோதனை. படத்தை பார்த்து உங்களுக்கு என்ன தெரிகிறது என சொல்லுங்கள்.",
    ml: "ആഴം പരിശോധന. ചിത്രങ്ങൾ കണ്ട് എന്ത് കാണുന്നുവെന്ന് പറയുക.",
  },
  red_reflex: {
    en: "Red reflex test. Set your device to full brightness. A bright white flash will appear for two seconds. Keep your eyes open.",
    ta: "சிவப்பு பிரதிபலிப்பு சோதனை. பிரகாசத்தை அதிகமாக்கவும். இரண்டு விநாடிகள் வெளிச்சம் தோன்றும். கண்களை திறந்திருக்கவும்.",
    ml: "റെഡ് റിഫ്ലക്സ് പരിശോധന. സ്ക്രീൻ പൂർണ്ണ തെളിച്ചത്തിലാക്കുക. രണ്ട് സെക്കൻ്റ് വെളിച്ചം തിളങ്ങും. കണ്ണുകൾ തുറന്നു വയ്ക്കുക.",
  },
  positioning: {
    too_close: { en: "You are too close. Please move back.", ta: "மிகவும் அருகில் இருக்கிறீர்கள். பின்னால் நகருங்கள்.", ml: "നിങ്ങൾ വളരെ അടുത്താണ്. പിന്നോട്ട് നീങ്ങുക." },
    too_far:   { en: "Please move closer to the camera.", ta: "கேமராவிற்கு அருகில் வாருங்கள்.", ml: "ക്യാമറയിലേക്ക് അടുത്ത് വരൂ." },
    no_face:   { en: "I can't see your face. Please face the camera.", ta: "உங்கள் முகம் தெரியவில்லை. கேமராவை நோக்கவும்.", ml: "മുഖം കാണാനില്ല. ക്യാമറയെ നോക്കുക." },
    good:      { en: "Perfect, hold still.", ta: "நன்றாக உள்ளது, அசையாதீர்கள்.", ml: "നല്ലത്, അനക്കരുത്." },
  },
  countdown: {
    en: ["Three", "Two", "One", "Go"],
    ta: ["மூன்று", "இரண்டு", "ஒன்று", "போ"],
    ml: ["മൂന്ന്", "രണ്ട്", "ഒന്ന്", "പോകൂ"],
  },
};
