import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuthStore } from "@/core/auth/AuthStore";

function homeForRole(role) {
  if (["super_admin", "hospital_admin", "admin"].includes(role)) return "/admin";
  if (["doctor", "optometrist", "field_worker"].includes(role)) return "/doctor";
  if (role === "patient" || role === "patient_pending") return "/patient";
  return "/";
}

export default function ProtectedRoute({ allow = [] }) {
  const { token, user, ready } = useAuthStore();
  const { pathname } = useLocation();
  if (!ready) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background text-muted-foreground">
        Loading…
      </div>
    );
  }
  if (!token) return <Navigate to="/" replace />;
  if (allow.length && !allow.includes(user?.role)) {
    if (pathname !== "/access-denied") {
      return <Navigate to="/access-denied" replace state={{ from: pathname }} />;
    }
  }
  return <Outlet />;
}
