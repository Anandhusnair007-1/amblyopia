import Dexie from "dexie";

export const db = new Dexie("ambyoai");
db.version(1).stores({
  queued_sessions: "++id, kind, created_at",
  cached_results: "++id, session_id, test_name, created_at",
});
db.version(2).stores({
  queued_sessions: "++id, kind, created_at",
  cached_results: "++id, session_id, test_name, created_at",
  sync_conflicts: "++id, session_id, test_name, created_at",
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
  const minimized = {
    ...payload,
    details: {
      test_status: payload?.details?.test_status,
      result_state: payload?.details?.result_state,
      measurement_valid: payload?.details?.measurement_valid,
      measurement_type: payload?.details?.measurement_type,
      test_distance_cm: payload?.details?.test_distance_cm,
      calibrated: payload?.details?.calibrated,
      quality_gate: payload?.details?.quality_gate,
      offline_minimized: true,
    },
  };
  return db.cached_results.add({
    session_id,
    test_name,
    payload: safeStringify(minimized),
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

export async function recordSyncConflict({ session_id, test_name, payload, error }) {
  return db.sync_conflicts.add({
    session_id,
    test_name,
    payload: safeStringify(payload || {}),
    error: String(error || "sync_failed").slice(0, 500),
    created_at: Date.now(),
  });
}
