/** Mask phone for display in shared clinical areas (last 4 only). */
export function maskPhone(phone) {
  if (!phone || typeof phone !== "string") return "—";
  const digits = phone.replace(/\D/g, "");
  if (digits.length <= 4) return "••••";
  return `••••${digits.slice(-4)}`;
}
