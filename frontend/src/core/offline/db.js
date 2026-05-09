import Dexie from "dexie";

export const db = new Dexie("ambyoai");
db.version(1).stores({
  queued_sessions: "++id, kind, created_at",
  cached_results: "++id, session_id, test_name, created_at",
});

function safeStringify(value) {
  try {
    return JSON.stringify(value);
  } catch {
    return JSON.stringify({ error: "stringify_failed" });
  }
}

/** Queue a session creation attempt (POST /sessions). */
export async function queueSessionCreate({ patient_id }) {
  return db.queued_sessions.add({
    kind: "create_session",
    payload: { patient_id },
    created_at: Date.now(),
  });
}

/** Cache a single test result (POST /sessions/:id/results). */
export async function cacheResult({ session_id, test_name, payload }) {
  return db.cached_results.add({
    session_id,
    test_name,
    payload: safeStringify(payload),
    created_at: Date.now(),
  });
}

export async function listQueuedSessions() {
  return db.queued_sessions.orderBy("created_at").toArray();
}

export async function deleteQueuedSession(id) {
  return db.queued_sessions.delete(id);
}

export async function listCachedResults() {
  return db.cached_results.orderBy("created_at").toArray();
}

export async function deleteCachedResult(id) {
  return db.cached_results.delete(id);
}
