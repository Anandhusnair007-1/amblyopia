import { useEffect, useMemo, useState } from "react";
import { NavLink, Outlet, useLocation, useNavigate, useSearchParams } from "react-router-dom";
import { useAuthStore } from "@/core/auth/AuthStore";
import AmbyoEyeLogo from "@/components/ambyo/AmbyoEyeLogo";
import OfflineBadge from "@/components/ambyo/OfflineBadge";
import LanguageSwitcher from "@/components/ambyo/LanguageSwitcher";
import SessionIdleGuard from "@/components/shell/SessionIdleGuard";
import { useTheme } from "next-themes";
import { useI18n } from "@/core/i18n/translations";
import {
  LayoutDashboard,
  Shield,
  Building2,
  Tent,
  Users,
  Send,
  CalendarCheck,
  LogOut,
  Stethoscope,
  Menu,
  X,
  Search,
  HeartPulse,
  Sun,
  Moon,
} from "lucide-react";

const CLINICAL_ROLES = ["doctor", "optometrist", "field_worker"];
const ADMIN_NAV_ROLES = ["super_admin", "hospital_admin", "admin", "doctor", "optometrist"];
const OPS_ROLES = ["super_admin", "hospital_admin", "admin"];

const linkCls = ({ isActive }) =>
  `flex items-center gap-2.5 rounded-xl px-3 py-2.5 text-sm font-medium transition-colors ${
    isActive
      ? "bg-primary text-primary-foreground shadow-sm"
      : "text-muted-foreground hover:bg-muted hover:text-foreground"
  }`;

function pageTitle(pathname) {
  if (pathname.startsWith("/doctor/audit")) return "staff_title_audit_logs";
  if (pathname.startsWith("/doctor/patient/")) return "staff_title_patient_record";
  if (pathname.startsWith("/doctor/session/")) return "staff_title_session_report";
  if (pathname === "/doctor") return "staff_title_clinical_worklist";
  if (pathname.startsWith("/admin/camps")) return "staff_title_camps";
  if (pathname.startsWith("/admin/staff")) return "staff_title_staff";
  if (pathname.startsWith("/admin/referrals")) return "staff_title_referrals";
  if (pathname.startsWith("/admin/followups")) return "staff_title_followups";
  if (pathname === "/admin" || pathname === "/admin/") return "staff_title_operations_overview";
  return "AmbyoAI";
}

function ClinicalPatientSearch() {
  const nav = useNavigate();
  const [searchParams] = useSearchParams();
  const qUrl = searchParams.get("q") || "";
  const [value, setValue] = useState(qUrl);
  const { t } = useI18n();

  useEffect(() => {
    setValue(qUrl);
  }, [qUrl]);

  const submit = (e) => {
    e.preventDefault();
    const q = value.trim();
    nav(q ? `/doctor?${new URLSearchParams({ q }).toString()}` : "/doctor");
  };

  return (
    <form onSubmit={submit} className="relative mx-4 hidden max-w-md flex-1 lg:block">
      <label className="relative block">
        <span className="sr-only">{t("search_patients")}</span>
        <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" aria-hidden />
        <input
          type="search"
          value={value}
          onChange={(e) => setValue(e.target.value)}
          placeholder={t("search_patients_placeholder")}
          className="w-full rounded-xl border border-border bg-background py-2.5 pl-10 pr-3 text-sm text-foreground shadow-inner placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring/40"
          data-testid="staff-global-search"
        />
      </label>
    </form>
  );
}

export default function StaffShell() {
  const { user, logout } = useAuthStore();
  const { theme, setTheme } = useTheme();
  const { t } = useI18n();
  const nav = useNavigate();
  const { pathname } = useLocation();
  const [drawerOpen, setDrawerOpen] = useState(false);

  useEffect(() => {
    setDrawerOpen(false);
  }, [pathname]);

  const ops = OPS_ROLES.includes(user?.role);
  const showClinical = CLINICAL_ROLES.includes(user?.role);
  const showAdmin = ADMIN_NAV_ROLES.includes(user?.role);

  const titleKey = useMemo(() => pageTitle(pathname), [pathname]);
  const title = titleKey === "AmbyoAI" ? t("app_name") : t(titleKey);
  const showClinicalPatientSearch =
    CLINICAL_ROLES.includes(user?.role) && pathname.startsWith("/doctor");

  const signOut = () => {
    logout();
    nav("/");
  };

  const NavBody = () => (
    <>
      <div className="flex items-center gap-3 px-1">
        <div
          className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-rose-400 via-rose-500 to-red-500 shadow-md shadow-rose-500/30"
          aria-hidden
          title="Eye care"
        >
          <HeartPulse className="size-6 text-white" strokeWidth={2.25} />
        </div>
        <div className="flex min-w-0 flex-1 items-center gap-2.5">
          <AmbyoEyeLogo size={36} />
          <div className="min-w-0">
            <div className="truncate font-bold text-[#0A2540]">{t("app_name")}</div>
            <div className="truncate text-xs text-muted-foreground">{t("staff_shell_subtitle")}</div>
          </div>
        </div>
      </div>
      <div className="mt-1 truncate rounded-lg border border-border bg-muted/50 px-2 py-1.5 text-xs text-muted-foreground">
        <span className="font-medium text-foreground">{user?.name || user?.email}</span>
        <span className="ml-1 font-mono uppercase text-[10px] tracking-wide">· {user?.role}</span>
      </div>

      {showClinical && (
        <nav data-testid="staff-nav-clinical" className="mt-6 flex flex-col gap-0.5 border-t border-border pt-4">
          <p className="mb-1 px-2 text-[10px] font-bold uppercase tracking-widest text-muted-foreground">{t("clinical")}</p>
          <NavLink to="/doctor" end className={linkCls} onClick={() => setDrawerOpen(false)}>
            <LayoutDashboard size={18} /> {t("worklist")}
          </NavLink>
          <NavLink
            to="/doctor/audit"
            data-testid="audit-link"
            className={linkCls}
            onClick={() => setDrawerOpen(false)}
          >
            <Shield size={18} /> {t("audit_logs")}
          </NavLink>
        </nav>
      )}

      {showAdmin && (
        <nav data-testid="staff-nav-admin" className="mt-6 flex flex-col gap-0.5 border-t border-border pt-4">
          <p className="mb-1 px-2 text-[10px] font-bold uppercase tracking-widest text-muted-foreground">{t("operations")}</p>
          <NavLink to="/admin" end className={linkCls} onClick={() => setDrawerOpen(false)}>
            <Building2 size={18} /> {t("overview")}
          </NavLink>
          {ops && (
            <>
              <NavLink to="/admin/camps" className={linkCls} onClick={() => setDrawerOpen(false)}>
                <Tent size={18} /> {t("camps")}
              </NavLink>
              <NavLink to="/admin/staff" className={linkCls} onClick={() => setDrawerOpen(false)}>
                <Users size={18} /> {t("staff")}
              </NavLink>
            </>
          )}
          <NavLink to="/admin/referrals" className={linkCls} onClick={() => setDrawerOpen(false)}>
            <Send size={18} /> {t("referrals")}
          </NavLink>
          <NavLink to="/admin/followups" className={linkCls} onClick={() => setDrawerOpen(false)}>
            <CalendarCheck size={18} /> {t("followups")}
          </NavLink>
        </nav>
      )}

      <div className="mt-auto flex flex-col gap-1 border-t border-border pt-4">
        {showClinical && showAdmin && (
          <button
            type="button"
            onClick={() => {
              nav(pathname.startsWith("/admin") ? "/doctor" : "/admin");
              setDrawerOpen(false);
            }}
            className="flex items-center gap-2 rounded-xl px-3 py-2 text-sm text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
          >
            <Stethoscope size={16} />
            {pathname.startsWith("/admin") ? t("clinical_portal") : t("operations")}
          </button>
        )}
        <button
          type="button"
          data-testid="logout-btn"
          onClick={signOut}
          className="flex items-center gap-2 rounded-xl px-3 py-2 text-sm text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
        >
          <LogOut size={16} /> {t("sign_out")}
        </button>
      </div>
    </>
  );

  return (
    <div className="flex min-h-screen bg-background text-foreground">
      <SessionIdleGuard onLogout={signOut} />
      {drawerOpen && (
        <button
          type="button"
          aria-label="Close menu"
          className="fixed inset-0 z-40 bg-black/40 md:hidden"
          onClick={() => setDrawerOpen(false)}
        />
      )}

      <aside
        className={`fixed inset-y-0 left-0 z-50 flex w-64 flex-col gap-4 border-r border-slate-200/80 bg-gradient-to-b from-slate-50 via-card to-slate-50 p-4 shadow-xl transition-transform duration-200 md:static md:z-0 md:my-3 md:ml-3 md:h-[calc(100vh-1.5rem)] md:rounded-2xl md:border md:shadow-md ${
          drawerOpen ? "translate-x-0" : "-translate-x-full md:translate-x-0"
        }`}
      >
        <button
          type="button"
          className="absolute right-3 top-3 rounded-lg p-2 text-muted-foreground hover:bg-muted md:hidden"
          onClick={() => setDrawerOpen(false)}
          aria-label="Close navigation"
        >
          <X size={20} />
        </button>
        <div className="flex flex-1 flex-col gap-4 overflow-y-auto pr-1 pt-10 md:pt-0">
          <NavBody />
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-30 flex h-16 items-center justify-between gap-3 border-b border-border bg-card/95 px-4 shadow-sm backdrop-blur supports-[backdrop-filter]:bg-card/90 md:px-6">
          <div className="flex min-w-0 flex-1 items-center gap-3">
            <button
              type="button"
              className="rounded-lg p-2 text-muted-foreground hover:bg-muted md:hidden"
              aria-label="Open menu"
              onClick={() => setDrawerOpen(true)}
            >
              <Menu size={22} />
            </button>
            <div className="hidden min-w-0 flex-col sm:flex">
              <span className="text-[10px] font-bold uppercase tracking-widest text-muted-foreground">Overview</span>
              <h1 className="truncate text-base font-semibold text-[#0A2540] md:text-lg">{title}</h1>
            </div>
            <h1 className="truncate text-sm font-semibold text-[#0A2540] sm:hidden">{title}</h1>
          </div>
          {showClinicalPatientSearch ? <ClinicalPatientSearch /> : <div className="mx-4 hidden max-w-md flex-1 lg:block" />}
          <div className="flex shrink-0 items-center gap-2">
            <button
              type="button"
              data-testid="theme-toggle"
              onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
              className="inline-flex items-center justify-center rounded-lg border border-border bg-background p-2 text-muted-foreground shadow-sm hover:bg-muted hover:text-foreground"
              aria-label={t("toggle_theme")}
              title={t("toggle_theme")}
            >
              {theme === "dark" ? <Sun size={16} /> : <Moon size={16} />}
            </button>
            <OfflineBadge />
            <LanguageSwitcher variant="light" />
          </div>
        </header>

        <main className="flex-1 overflow-auto bg-gradient-to-br from-slate-50/80 via-background to-teal-50/20 p-4 md:p-6 lg:p-8">
          <div className="mx-auto max-w-7xl">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
}
