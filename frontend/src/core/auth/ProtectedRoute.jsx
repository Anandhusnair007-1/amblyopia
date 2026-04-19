import { Navigate, Outlet } from "react-router-dom";
import { useAuthStore } from "@/core/auth/AuthStore";

export default function ProtectedRoute({ allow = [] }) {
  const { token, user, ready } = useAuthStore();
  if (!ready) return <div className="min-h-screen flex items-center justify-center text-slate-500">Loading…</div>;
  if (!token) return <Navigate to="/" replace />;
  if (allow.length && !allow.includes(user?.role)) {
    return <Navigate to={user?.role === "doctor" ? "/doctor" : "/patient"} replace />;
  }
  return <Outlet />;
}
