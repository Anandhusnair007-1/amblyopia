import { useEffect, useRef } from "react";
import { create } from "zustand";
import { api } from "@/core/auth/AuthStore";
import {
  listQueuedSessions,
  deleteQueuedSession,
  listCachedResults,
  deleteCachedResult,
  recordSyncConflict,
} from "@/core/offline/db";

const SYNCED_BANNER_MS = 4500;

export const useOfflineSyncStore = create((set) => ({
  online: typeof navigator !== "undefined" ? navigator.onLine : true,
  syncing: false,
  lastSyncAt: null,
  setOnline: (online) => set({ online }),
  setSyncing: (syncing) => set({ syncing }),
  markSynced: () => set({ lastSyncAt: Date.now() }),
}));

function shouldQueue(err) {
  // Offline / network errors typically have no response.
  if (!navigator.onLine) return true;
  if (!err) return false;
  if (err?.response) return false;
  const msg = String(err?.message || "");
  return msg.includes("Network Error") || msg.includes("Failed to fetch");
}

async function flushQueuedSessions() {
  const rows = await listQueuedSessions();
  for (const row of rows) {
    try {
      if (row.kind === "create_session") {
        await api.post("/sessions", row.payload);
      }
      await deleteQueuedSession(row.id);
    } catch (e) {
      // Stop on first non-queueable failure; try again later.
      if (!shouldQueue(e)) throw e;
      return;
    }
  }
}

async function flushCachedResults() {
  const rows = await listCachedResults();
  for (const row of rows) {
    try {
      const payload = JSON.parse(row.payload || "{}");
      await api.post(`/sessions/${row.session_id}/results`, payload);
      await deleteCachedResult(row.id);
    } catch (e) {
      if (!shouldQueue(e)) {
        const payload = JSON.parse(row.payload || "{}");
        await recordSyncConflict({
          session_id: row.session_id,
          test_name: row.test_name,
          payload,
          error: e?.response?.data?.detail || e?.message || "sync conflict",
        });
        await deleteCachedResult(row.id);
        continue;
      }
      return;
    }
  }
}

export function useOfflineSync() {
  const setOnline = useOfflineSyncStore((s) => s.setOnline);
  const setSyncing = useOfflineSyncStore((s) => s.setSyncing);
  const markSynced = useOfflineSyncStore((s) => s.markSynced);
  const syncInFlightRef = useRef(false);
  const syncedTimerRef = useRef(null);

  const runSync = async () => {
    if (!navigator.onLine) return;
    if (syncInFlightRef.current) return;
    syncInFlightRef.current = true;
    setSyncing(true);
    try {
      await flushQueuedSessions();
      await flushCachedResults();
      markSynced();
      if (syncedTimerRef.current) clearTimeout(syncedTimerRef.current);
      syncedTimerRef.current = setTimeout(() => {
        // Let badge return to "Online" after a short "Synced" state.
        useOfflineSyncStore.setState((s) => ({ ...s, lastSyncAt: null }));
      }, SYNCED_BANNER_MS);
    } finally {
      setSyncing(false);
      syncInFlightRef.current = false;
    }
  };

  useEffect(() => {
    const on = () => {
      setOnline(true);
      runSync();
    };
    const off = () => setOnline(false);
    window.addEventListener("online", on);
    window.addEventListener("offline", off);
    setOnline(navigator.onLine);
    if (navigator.onLine) runSync();
    return () => {
      window.removeEventListener("online", on);
      window.removeEventListener("offline", off);
      if (syncedTimerRef.current) clearTimeout(syncedTimerRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
}

export { shouldQueue };
