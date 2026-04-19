// Voice parsing helpers for Snellen directions (multilingual) + Titmus answers
const DIRS = {
  up:    ["up","mele","upar","mele","മുകളിൽ","മേലെ","மேலே"],
  down:  ["down","kizhe","neeche","கீழே","താഴെ","കീഴെ"],
  left:  ["left","idam","baye","இடம்","இடது","ഇടത്"],
  right: ["right","valad","valamaa","daaye","வலது","വലത്"],
};

export function parseDirection(text = "") {
  const s = text.toLowerCase().trim();
  if (!s) return null;
  for (const [dir, syns] of Object.entries(DIRS)) {
    for (const syn of syns) {
      if (s.includes(syn.toLowerCase())) return dir;
    }
  }
  return null;
}

export function parseYes(text = "") {
  const s = text.toLowerCase().trim();
  return /^(yes|yep|yeah|ok|haan|hawn|aanu|ആഉ|ഉണ്ട്|ஆம்|sari|seri|ஆமா|ja)/.test(s);
}

export function parseNo(text = "") {
  const s = text.toLowerCase().trim();
  return /^(no|nope|nah|illa|illai|ഇല്ല|இல்லை|nahi)/.test(s);
}
