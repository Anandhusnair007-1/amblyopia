import Dexie from "dexie";

export const db = new Dexie("ambyoai");
db.version(1).stores({
  queued_sessions: "++id, session_id, created_at",
  cached_results: "++id, session_id, test_name",
});

export async function queueSession(payload) {
  return db.queued_sessions.add({ session_id: payload.session_id, payload, created_at: Date.now() });
}
