import { useNavigate } from "react-router-dom";
import { useAuthStore } from "@/core/auth/AuthStore";
import { Button } from "@/components/ui/button";
import PageHeader from "@/components/shell/PageHeader";

export default function AccessDenied() {
  const nav = useNavigate();
  const { user, logout } = useAuthStore();

  const goHome = () => {
    if (["super_admin", "hospital_admin", "admin"].includes(user?.role)) nav("/admin");
    else if (["doctor", "optometrist", "field_worker"].includes(user?.role)) nav("/doctor");
    else if (user?.role === "patient" || user?.role === "patient_pending") nav("/patient");
    else nav("/");
  };

  return (
    <div className="flex min-h-[100dvh] flex-col bg-background">
      <div className="mx-auto max-w-lg flex-1 px-6 py-16">
        <PageHeader eyebrow="Access" title="You don’t have access to this page" />
        <p className="mt-4 text-sm text-muted-foreground">
          Signed in as <span className="font-mono text-foreground">{user?.role}</span>. If you need a different role,
          contact your hospital administrator.
        </p>
        <div className="mt-8 flex flex-wrap gap-3">
          <Button type="button" onClick={goHome}>
            Go to your home portal
          </Button>
          <Button type="button" variant="outline" onClick={() => { logout(); nav("/"); }}>
            Sign out
          </Button>
        </div>
      </div>
    </div>
  );
}
