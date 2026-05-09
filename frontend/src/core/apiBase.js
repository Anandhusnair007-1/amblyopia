/**
 * API base path embedded at build time.
 * Empty REACT_APP_BACKEND_URL → same-origin `/api` (use with nginx reverse proxy in Docker).
 */
export function getApiBasePath() {
  const raw = process.env.REACT_APP_BACKEND_URL;
  if (raw == null || String(raw).trim() === "" || String(raw) === "undefined") {
    if (process.env.NODE_ENV === "development" && window.location.port === "3000") {
      return "http://localhost:8001/api";
    }
    return "/api";
  }
  return `${String(raw).replace(/\/$/, "")}/api`;
}
