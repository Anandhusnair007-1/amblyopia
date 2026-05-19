// Voice parsing: Snellen directions, yes/no, Titmus animal names (EN / TA / ML / HI).

const DIRS = {
  up: [
    "up", "upward", "top", "above", "north",
    "mele", "mel", "upar", "uupar", "ooopar",
    "மேலே", "மேல", "மேல்",
    "മുകളിൽ", "മേലെ", "മുകളിലേക്ക്",
    "ऊपर", "upar",
  ],
  down: [
    "down", "downward", "bottom", "below", "south",
    "kizhe", "keezh", "neeche", "niche", "thazhe",
    "கீழே", "கீழ", "கீழ்",
    "താഴെ", "കീഴെ", "താഴേക്ക്",
    "नीचे", "neeche",
  ],
  left: [
    "left", "west", "idam", "idathu", "baye", "baen",
    "இடம்", "இடது", "இடத்தில்",
    "ഇടത്", "ഇടത്തേക്ക്",
    "बाएं", "baen",
  ],
  right: [
    "right", "east", "valad", "valathu", "valamaa", "daaye", "daye",
    "வலது", "வலது பக்கம்",
    "വലത്", "വലത്തേക്ക്",
    "दाएं", "daaye",
  ],
};

const ANIMALS = {
  cat: ["cat", "poonai", "poocha", "பூனை", "പൂച്ച", "billi"],
  duck: ["duck", "vathu", "thara", "வாத்து", "താറാവ്", "batkh"],
  rabbit: ["rabbit", "bunny", "muyal", "pulli", "முயல்", "മുയൽ", "khargosh"],
};

function normalize(text = "") {
  return text
    .toLowerCase()
    .replace(/[^\w\s\u0B80-\u0BFF\u0D00-\u0D7F\u0900-\u097F]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function parseDirection(text = "") {
  const s = normalize(text);
  if (!s) return null;
  for (const [dir, syns] of Object.entries(DIRS)) {
    for (const syn of syns) {
      const token = syn.toLowerCase();
      if (s === token || s.includes(` ${token} `) || s.startsWith(`${token} `) || s.endsWith(` ${token}`)) {
        return dir;
      }
    }
  }
  return null;
}

export function parseYes(text = "") {
  const s = normalize(text);
  return /^(yes|yep|yeah|yup|ok|okay|correct|haan|ha|aanu|aam|aama|sari|seri|ஆம்|ஆமா|ഉണ്ട്|ആണ്|ആണു|हाँ|हां|haan|ji)\b/.test(s) || /\b(yes|haan|aanu|ஆம்|ഉണ്ട്)\b/.test(s);
}

export function parseNo(text = "") {
  const s = normalize(text);
  return /^(no|nope|nah|wrong|illa|illai|இல்லை|ഇല്ല|नहीं|nahi)\b/.test(s) || /\b(no|illa|illai|இல்லை|ഇല്ല)\b/.test(s);
}

export function parseAnimal(text = "") {
  const s = normalize(text);
  if (!s) return null;
  for (const [animal, syns] of Object.entries(ANIMALS)) {
    for (const syn of syns) {
      if (s.includes(syn.toLowerCase())) return animal;
    }
  }
  return null;
}

export function parseCircleNumber(text = "") {
  const s = normalize(text);
  const words = {
    one: 1, two: 2, three: 3, four: 4, five: 5,
    onnu: 1, rendu: 2, moonu: 3, naalu: 4, anju: 5,
    ஒன்று: 1, இரண்டு: 2, மூன்று: 3, நான்கு: 4, ஐந்து: 5,
    ഒന്ന്: 1, രണ്ട്: 2, മൂന്ന്: 3, നാല്: 4, അഞ്ച്: 5,
  };
  for (const [w, n] of Object.entries(words)) {
    if (s.includes(w)) return n;
  }
  const m = s.match(/\b([1-5])\b/);
  return m ? parseInt(m[1], 10) : null;
}
