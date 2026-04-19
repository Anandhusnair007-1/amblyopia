import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Bug, Dog, Check, X } from "lucide-react";
import { speak } from "@/core/audio/AudioGuide";
import { useI18n } from "@/core/i18n/translations";

const ANIMALS = ["Cat", "Duck", "Rabbit"];

function FlyPattern() {
  return (
    <motion.div
      initial={{ scale: 0.9, opacity: 0 }} animate={{ scale: 1, opacity: 1 }}
      className="relative w-72 h-72 mx-auto"
    >
      <div className="absolute inset-0 bg-gradient-to-br from-sky-400/30 to-teal-400/10 rounded-3xl blur-lg" />
      <div className="absolute inset-2 bg-slate-800 rounded-3xl flex items-center justify-center border border-white/10">
        <motion.div animate={{ rotateY: [0, 8, 0, -8, 0] }} transition={{ duration: 3, repeat: Infinity }}>
          <Bug size={150} className="text-white drop-shadow-[0_0_30px_rgba(45,212,191,0.6)]" />
        </motion.div>
      </div>
    </motion.div>
  );
}

function CirclesPattern({ correctIdx = 1 }) {
  return (
    <div className="flex items-center gap-5 justify-center">
      {[0,1,2,3,4].map((i) => (
        <motion.div key={i} initial={{ y: 10, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ delay: i * 0.08 }}>
          <div className={`w-20 h-20 rounded-full border-2 transition-all ${i === correctIdx ? "bg-white shadow-[0_0_40px_10px_rgba(255,255,255,0.25)] border-white scale-110" : "bg-white/20 border-white/40"}`} />
        </motion.div>
      ))}
    </div>
  );
}

function AnimalPattern({ correctIdx }) {
  return (
    <div className="flex items-center gap-8 justify-center">
      {ANIMALS.map((a, i) => (
        <motion.div key={a} initial={{ y: 12, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ delay: i * 0.1 }}
          className={`flex flex-col items-center gap-2 ${i === correctIdx ? "scale-110" : ""}`}>
          <div className={`w-28 h-28 rounded-3xl flex items-center justify-center border-2 transition-all ${i === correctIdx ? "bg-teal-500/20 border-teal-400 shadow-[0_0_30px_6px_rgba(45,212,191,0.35)]" : "bg-white/10 border-white/15"}`}>
            <Dog size={56} className="text-white" />
          </div>
          <span className="text-white text-sm font-semibold">{a}</span>
        </motion.div>
      ))}
    </div>
  );
}

export default function TitmusTest({ patient, onComplete }) {
  const { lang } = useI18n();
  const age = patient?.age ?? 8;
  const profile = age <= 4 ? "A" : age <= 7 ? "B" : "C";
  const subTests = profile === "A" ? ["fly"] : profile === "B" ? ["fly", "animal"] : ["fly", "animal", "circles"];
  const [step, setStep] = useState(0);
  const [answers, setAnswers] = useState([]);
  const [reveal, setReveal] = useState(null);
  const circlesCorrect = 2, animalCorrect = 1;

  const answer = (name, correct) => {
    setReveal(correct ? "correct" : "wrong");
    setTimeout(() => {
      const newA = [...answers, { name, correct }];
      setAnswers(newA); setReveal(null);
      if (step + 1 >= subTests.length) finish(newA);
      else setStep(step + 1);
    }, 700);
  };

  const finish = (arr) => {
    const passed = arr.filter((a) => a.correct).length;
    const normalized = Math.max(0, Math.min(1, passed / subTests.length));
    speak(`You got ${passed} of ${subTests.length} correct.`, { lang });
    onComplete({
      raw_score: passed, normalized_score: 1 - normalized,
      details: { passed, total: subTests.length, results: arr, profile },
    });
  };

  const current = subTests[step];

  return (
    <div className="relative flex-1 flex flex-col items-center justify-center px-6 py-24">
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute -top-40 left-1/2 -translate-x-1/2 w-[40rem] h-[40rem] rounded-full bg-violet-400/10 blur-3xl" />
      </div>

      <div className="absolute top-24 left-1/2 -translate-x-1/2 text-center pointer-events-none">
        <p className="text-xs uppercase tracking-[0.3em] text-violet-400 font-bold">Titmus Stereo · {step + 1}/{subTests.length}</p>
      </div>

      <AnimatePresence mode="wait">
        <motion.div
          key={current}
          initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -10 }}
          transition={{ duration: 0.35 }}
          className="flex flex-col items-center gap-8 relative"
        >
          {current === "fly" && (
            <>
              <h2 className="text-2xl sm:text-3xl font-bold text-white tracking-tight text-center">Do the fly's wings pop out at you?</h2>
              <FlyPattern />
              <div className="flex items-center gap-3">
                <button data-testid="fly-yes" onClick={() => answer("fly", true)}  className="px-8 py-3 rounded-2xl bg-emerald-500 text-white font-bold shadow-lg hover:bg-emerald-400 active:scale-95 transition-all">Yes, I see wings</button>
                <button data-testid="fly-no"  onClick={() => answer("fly", false)} className="px-8 py-3 rounded-2xl bg-white/10 text-white font-bold border border-white/20 hover:bg-white/20 active:scale-95 transition-all">No</button>
              </div>
            </>
          )}
          {current === "animal" && (
            <>
              <h2 className="text-2xl sm:text-3xl font-bold text-white tracking-tight text-center">Which animal is closest to you?</h2>
              <AnimalPattern correctIdx={animalCorrect} />
              <div className="flex items-center gap-3">
                {ANIMALS.map((a, i) => (
                  <button key={a} data-testid={`animal-${a.toLowerCase()}`} onClick={() => answer(a, i === animalCorrect)} className="px-5 py-2.5 rounded-xl bg-white/10 text-white font-semibold border border-white/20 hover:bg-white/20 active:scale-95 transition-all">{a}</button>
                ))}
              </div>
            </>
          )}
          {current === "circles" && (
            <>
              <h2 className="text-2xl sm:text-3xl font-bold text-white tracking-tight text-center">Which circle pops forward?</h2>
              <CirclesPattern correctIdx={circlesCorrect} />
              <div className="flex items-center gap-2">
                {[1,2,3,4,5].map((i) => (
                  <button key={i} data-testid={`circle-${i}`} onClick={() => answer(`c${i}`, i - 1 === circlesCorrect)} className="w-14 h-14 rounded-2xl bg-white/10 text-white font-bold border border-white/20 hover:bg-white/20 active:scale-95 transition-all">{i}</button>
                ))}
              </div>
            </>
          )}
        </motion.div>
      </AnimatePresence>

      {reveal && (
        <motion.div initial={{ scale: 0.5, opacity: 0 }} animate={{ scale: 1, opacity: 1 }}
          className={`absolute ${reveal === "correct" ? "text-emerald-400" : "text-red-400"}`}
        >
          {reveal === "correct" ? <Check size={100} /> : <X size={100} />}
        </motion.div>
      )}
    </div>
  );
}
