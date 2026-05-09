import { useCallback, useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { api, useAuthStore } from "@/core/auth/AuthStore";
import RiskBadge from "@/components/ambyo/RiskBadge";
import PageHeader from "@/components/shell/PageHeader";
import KpiCard from "@/components/shell/KpiCard";
import DashboardCard from "@/components/shell/DashboardCard";
import MedicalDisclaimer from "@/components/MedicalDisclaimer";
import ScoreRing from "@/components/ambyo/ScoreRing";
import CountUp from "@/components/ambyo/CountUp";
import { Skeleton } from "@/components/ui/skeleton";
import { motion } from "framer-motion";
import {
  AlertOctagon,
  ClipboardList,
  Search,
  Filter,
  ChevronRight,
  CalendarClock,
  CheckCircle2,
} from "lucide-react";
import {
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  Tooltip,
} from "recharts";

const QUEUES = [
  { key: "all", label: "All sessions" },
  { key: "urgent_unreviewed", label: "Urgent · unreviewed" },
  { key: "pending_review", label: "Pending review" },
  { key: "followups_due", label: "Follow-ups due" },
];

const RISK_FILTERS = [
  { key: "", label: "All risks" },
  { key: "urgent", label: "Urgent" },
  { key: "moderate", label: "Moderate" },
  { key: "mild", label: "Mild" },
  { key: "normal", label: "Normal" },
];

const REVIEW_FILTERS = [
  { key: "", label: "Any status" },
  { key: "pending", label: "Pending" },
  { key: "reviewed", label: "Reviewed" },
];

export default function DoctorDashboard() {
  const nav = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const { user } = useAuthStore();
  const [stats, setStats] = useState({});
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);

  const queue = searchParams.get("queue") || "all";
  const risk = searchParams.get("risk") || "";
  const reviewStatus = searchParams.get("review") || "";
  const q = searchParams.get("q") || "";
  const pageParam = Number(searchParams.get("page") || "1");
  const pageSizeParam = Number(searchParams.get("pageSize") || "25");
  const page = Number.isFinite(pageParam) && pageParam > 0 ? Math.floor(pageParam) : 1;
  const pageSize = [25, 50, 100].includes(pageSizeParam) ? pageSizeParam : 25;

  const setParam = (key, value) => {
    const next = new URLSearchParams(searchParams);
    if (value) next.set(key, value);
    else next.delete(key);
    setSearchParams(next, { replace: true });
  };

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const params = { queue };
      if (risk) params.risk = risk;
      if (reviewStatus) params.review_status = reviewStatus;
      if (q.trim()) params.q = q.trim();
      const [s, w] = await Promise.all([api.get("/doctor/stats"), api.get("/doctor/worklist", { params })]);
      setStats(s.data);
      setRows(w.data || []);
    } finally {
      setLoading(false);
    }
  }, [queue, risk, reviewStatus, q]);

  useEffect(() => {
    load();
  }, [load]);

  // Reset pagination when the filters change (UI only).
  useEffect(() => {
    const next = new URLSearchParams(searchParams);
    if (next.get("page") && next.get("page") !== "1") {
      next.set("page", "1");
      setSearchParams(next, { replace: true });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [queue, risk, reviewStatus, q]);

  const localSearch = useMemo(() => q, [q]);
  const [searchDraft, setSearchDraft] = useState(localSearch);

  useEffect(() => {
    setSearchDraft(localSearch);
  }, [localSearch]);

  const applySearch = (e) => {
    e.preventDefault();
    setParam("q", searchDraft.trim());
  };

  const slaBadge = (status) => {
    if (status === "breached")
      return <span className="rounded-full bg-red-100 px-2 py-0.5 text-xs font-medium text-red-800">SLA overdue</span>;
    if (status === "at_risk")
      return <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-900">SLA at risk</span>;
    if (status === "on_track")
      return <span className="rounded-full bg-emerald-50 px-2 py-0.5 text-xs font-medium text-emerald-800">On track</span>;
    return <span className="text-xs text-muted-foreground">—</span>;
  };

  const riskBorder = (level) => {
    const v = (level || "").toLowerCase();
    if (v === "urgent") return "border-l-red-500";
    if (v === "moderate") return "border-l-orange-500";
    if (v === "mild") return "border-l-amber-500";
    if (v === "normal") return "border-l-emerald-500";
    return "border-l-slate-300";
  };

  // UI-only derived values (does not change API calls or filtering behavior).
  const riskDonut = useMemo(() => {
    const counts = { normal: 0, mild: 0, moderate: 0, urgent: 0 };
    (rows || []).forEach((r) => {
      const k = String(r.risk_level || "").toLowerCase();
      if (k in counts) counts[k] += 1;
    });
    const colors = {
      normal: "#10B981",
      mild: "#F59E0B",
      moderate: "#F97316",
      urgent: "#EF4444",
    };
    return (["normal", "mild", "moderate", "urgent"] || []).map((k) => ({
      key: k,
      name: k,
      value: counts[k],
      color: colors[k],
    })).filter((x) => x.value > 0);
  }, [rows]);

  const totalRows = rows.length;
  const totalPages = Math.max(1, Math.ceil(totalRows / pageSize));
  const safePage = Math.min(page, totalPages);
  const startIdx = (safePage - 1) * pageSize;
  const endIdx = Math.min(startIdx + pageSize, totalRows);
  const pagedRows = useMemo(() => (rows || []).slice(startIdx, endIdx), [rows, startIdx, endIdx]);

  const clearFilters = () => {
    const next = new URLSearchParams(searchParams);
    next.delete("risk");
    next.delete("review");
    next.delete("q");
    next.delete("page");
    next.delete("pageSize");
    setSearchParams(next, { replace: true });
  };

  return (
    <div className="page-enter space-y-8">
      <PageHeader
        eyebrow="Clinical worklist"
        title="Screening queue"
        description={`${user?.hospital_name || "Hospital"} · Prioritized sessions and reviews`}
      />

      <MedicalDisclaimer />

      {/* KPI cards (responsive: 1-col mobile, 2-col tablet, 3-col desktop) */}
      <motion.div
        initial="hidden"
        animate="show"
        variants={{ hidden: {}, show: { transition: { staggerChildren: 0.1, delayChildren: 0.05 } } }}
        className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3"
      >
        {[
          {
            key: "urgent",
            label: "Urgent · unreviewed",
            value: stats.urgent_unreviewed ?? 0,
            color: "red",
            icon: AlertOctagon,
            ring: 88,
            testid: "stat-urgent-unreviewed",
          },
          {
            key: "pending",
            label: "Pending review",
            value: stats.pending_review ?? 0,
            color: "slate",
            icon: ClipboardList,
            ring: 62,
            testid: "stat-pending",
          },
          {
            key: "followups",
            label: "Follow-ups due",
            value: stats.followups_due ?? 0,
            color: "amber",
            icon: CalendarClock,
            ring: 54,
            testid: "stat-followups-due",
          },
          {
            key: "reviewed",
            label: "Reviewed today",
            value: stats.reviewed_today ?? 0,
            color: "teal",
            icon: CheckCircle2,
            ring: 74,
            testid: "stat-reviewed-today",
          },
        ].map((kpi, i) => (
          <motion.div
            key={kpi.key}
            variants={{ hidden: { opacity: 0, y: 12 }, show: { opacity: 1, y: 0 } }}
            transition={{ delay: i * 0.1 }}
            className="relative"
          >
            {/* Keep KpiCard as the base component */}
            <KpiCard icon={kpi.icon} label={kpi.label} value={kpi.value} color={kpi.color} testid={kpi.testid} />
            {/* Add ScoreRing overlay + animated CountUp label (visual-only) */}
            <div className="pointer-events-none absolute bottom-4 right-4">
              <div className="relative h-14 w-14">
                <ScoreRing score={kpi.ring} level="normal" size={56} stroke={6} />
              </div>
            </div>
            <div className="pointer-events-none absolute left-5 bottom-5 text-xs text-muted-foreground">
              <span className="font-mono">
                <CountUp end={Number(kpi.value || 0)} />
              </span>
            </div>
          </motion.div>
        ))}

        {/* Donut chart card */}
        <motion.div
          variants={{ hidden: { opacity: 0, y: 12 }, show: { opacity: 1, y: 0 } }}
          className="sm:col-span-2 lg:col-span-1"
        >
          <DashboardCard className="p-5">
            <div className="flex items-center justify-between">
              <div>
                <div className="text-[10px] font-bold uppercase tracking-widest text-muted-foreground">
                  Risk distribution
                </div>
                <div className="mt-1 text-sm font-semibold text-[#0A2540] dark:text-foreground">
                  Today&apos;s worklist
                </div>
              </div>
              <div className="font-mono text-xs text-muted-foreground">n={rows.length}</div>
            </div>
            <div className="mt-4 grid grid-cols-[140px_1fr] items-center gap-4">
              <div className="h-[140px] w-[140px]">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={riskDonut.length ? riskDonut : [{ name: "none", value: 1, color: "#E2E8F0" }]}
                      dataKey="value"
                      nameKey="name"
                      innerRadius={44}
                      outerRadius={64}
                      paddingAngle={2}
                      stroke="transparent"
                    >
                      {(riskDonut.length ? riskDonut : [{ name: "none", value: 1, color: "#E2E8F0" }]).map((entry) => (
                        <Cell key={entry.name} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip
                      contentStyle={{
                        borderRadius: 12,
                        border: "1px solid rgba(148,163,184,0.3)",
                        background: "rgba(255,255,255,0.92)",
                        fontSize: 12,
                      }}
                      formatter={(val, name) => [val, String(name).toUpperCase()]}
                    />
                  </PieChart>
                </ResponsiveContainer>
              </div>
              <div className="space-y-2">
                {[
                  ["urgent", "#EF4444"],
                  ["moderate", "#F97316"],
                  ["mild", "#F59E0B"],
                  ["normal", "#10B981"],
                ].map(([k, c]) => (
                  <div key={k} className="flex items-center justify-between text-sm">
                    <div className="flex items-center gap-2">
                      <span className="h-2.5 w-2.5 rounded-full" style={{ background: c }} />
                      <span className="capitalize text-muted-foreground">{k}</span>
                    </div>
                    <span className="font-mono text-xs text-foreground">
                      {riskDonut.find((x) => x.name === k)?.value ?? 0}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          </DashboardCard>
        </motion.div>
      </motion.div>

      <section className="space-y-4">
        <div className="flex flex-col gap-3 lg:flex-row lg:flex-wrap lg:items-end lg:justify-between">
          <div className="flex flex-wrap gap-2">
            {QUEUES.map((item) => (
              <button
                key={item.key}
                type="button"
                data-testid={`queue-${item.key}`}
                onClick={() => setParam("queue", item.key === "all" ? "" : item.key)}
                className={`rounded-full border px-3 py-1.5 text-sm font-medium transition-colors ${
                  (item.key === "all" && queue === "all") || queue === item.key
                    ? "border-[#0A2540] bg-[#0A2540] text-white"
                    : "border-border bg-background text-muted-foreground hover:bg-muted"
                }`}
              >
                {item.label}
              </button>
            ))}
          </div>
          <form onSubmit={applySearch} className="relative w-full max-w-sm lg:w-72">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
            <input
              data-testid="search-patient"
              value={searchDraft}
              onChange={(e) => setSearchDraft(e.target.value)}
              placeholder="Search by patient name"
              className="h-10 w-full rounded-xl border border-input bg-background pl-9 pr-3 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring/40"
            />
          </form>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <Filter size={14} className="text-muted-foreground" />
          <span className="text-xs text-muted-foreground">Risk</span>
          {RISK_FILTERS.map((f) => (
            <button
              key={f.key || "all-risk"}
              type="button"
              data-testid={`filter-risk-${f.key || "all"}`}
              onClick={() => setParam("risk", f.key)}
              className={`rounded-lg px-2.5 py-1 text-xs font-medium ${
                risk === f.key ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:bg-muted"
              }`}
            >
              {f.label}
            </button>
          ))}
          <span className="ml-2 text-xs text-muted-foreground">Review</span>
          {REVIEW_FILTERS.map((f) => (
            <button
              key={f.key || "all-rev"}
              type="button"
              data-testid={`filter-review-${f.key || "all"}`}
              onClick={() => setParam("review", f.key)}
              className={`rounded-lg px-2.5 py-1 text-xs font-medium ${
                reviewStatus === f.key ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:bg-muted"
              }`}
            >
              {f.label}
            </button>
          ))}
        </div>

        <DashboardCard className="overflow-hidden p-0">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[1080px] table-fixed text-left text-sm">
              <colgroup>
                <col style={{ width: 220 }} />
                <col style={{ width: 120 }} />
                <col style={{ width: 130 }} />
                <col style={{ width: 130 }} />
                <col style={{ width: 110 }} />
                <col style={{ width: 190 }} />
                <col style={{ width: 120 }} />
                <col style={{ width: 100 }} />
                <col style={{ width: 130 }} />
                <col style={{ width: 170 }} />
              </colgroup>
              <thead>
                <tr className="border-b border-border bg-muted/40 text-muted-foreground">
                  <th className="sticky top-0 z-10 bg-muted/40 px-4 py-3 font-medium">Patient</th>
                  <th className="sticky top-0 z-10 bg-muted/40 px-4 py-3 font-medium">Age / sex</th>
                  <th className="sticky top-0 z-10 bg-muted/40 px-4 py-3 font-medium">Phone</th>
                  <th className="sticky top-0 z-10 bg-muted/40 px-4 py-3 font-medium">MRN</th>
                  <th className="sticky top-0 z-10 bg-muted/40 px-4 py-3 font-medium">Risk</th>
                  <th className="sticky top-0 z-10 bg-muted/40 px-4 py-3 font-medium">Last screening</th>
                  <th className="sticky top-0 z-10 bg-muted/40 px-4 py-3 font-medium">Camp</th>
                  <th className="sticky top-0 z-10 bg-muted/40 px-4 py-3 font-medium">Review</th>
                  <th className="sticky top-0 z-10 bg-muted/40 px-4 py-3 font-medium">SLA</th>
                  <th className="sticky top-0 z-10 bg-muted/40 px-4 py-3 font-medium text-right">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {loading &&
                  Array.from({ length: 8 }).map((_, i) => (
                    <tr key={`sk-${i}`} className="border-l-4 border-l-slate-200">
                      <td className="px-4 py-3">
                        <Skeleton className="h-4 w-[160px]" />
                      </td>
                      <td className="px-4 py-3">
                        <Skeleton className="h-4 w-[80px]" />
                      </td>
                      <td className="px-4 py-3">
                        <Skeleton className="h-4 w-[90px]" />
                      </td>
                      <td className="px-4 py-3">
                        <Skeleton className="h-4 w-[90px]" />
                      </td>
                      <td className="px-4 py-3">
                        <Skeleton className="h-6 w-[84px] rounded-full" />
                      </td>
                      <td className="px-4 py-3">
                        <Skeleton className="h-4 w-[150px]" />
                      </td>
                      <td className="px-4 py-3">
                        <Skeleton className="h-4 w-[80px]" />
                      </td>
                      <td className="px-4 py-3">
                        <Skeleton className="h-4 w-[60px]" />
                      </td>
                      <td className="px-4 py-3">
                        <Skeleton className="h-4 w-[90px]" />
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex justify-end gap-2">
                          <Skeleton className="h-8 w-[80px] rounded-lg" />
                          <Skeleton className="h-8 w-[84px] rounded-lg" />
                        </div>
                      </td>
                    </tr>
                  ))}

                {!loading && rows.length === 0 && (
                  <tr>
                    <td colSpan={10} className="px-6 py-10">
                      <div className="mx-auto flex max-w-2xl flex-col items-center rounded-2xl border border-border bg-background p-8 text-center">
                        <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-muted/60">
                          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" aria-hidden>
                            <path
                              d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12Z"
                              stroke="currentColor"
                              strokeWidth="1.8"
                              className="text-muted-foreground"
                            />
                            <path
                              d="M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Z"
                              stroke="currentColor"
                              strokeWidth="1.8"
                              className="text-muted-foreground"
                            />
                            <path
                              d="M12 12h.01"
                              stroke="currentColor"
                              strokeWidth="3"
                              strokeLinecap="round"
                              className="text-muted-foreground"
                            />
                          </svg>
                        </div>
                        <div className="mt-4 text-base font-semibold text-foreground">
                          No screenings match your filters
                        </div>
                        <div className="mt-1 text-sm text-muted-foreground">
                          Try adjusting risk/review filters or clearing search terms.
                        </div>
                        <div className="mt-5 flex flex-wrap items-center justify-center gap-2">
                          <button
                            type="button"
                            onClick={clearFilters}
                            className="rounded-xl border border-border bg-background px-4 py-2 text-sm font-semibold text-foreground hover:bg-muted"
                          >
                            Clear filters
                          </button>
                          <button
                            type="button"
                            onClick={() => setParam("queue", "")}
                            className="rounded-xl bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground hover:opacity-95"
                          >
                            View all sessions
                          </button>
                        </div>
                      </div>
                    </td>
                  </tr>
                )}
                {!loading &&
                  pagedRows.map((row) => (
                    <tr
                      key={`${row.session_id}-${row.patient_id}`}
                      className={`hover:bg-muted/40 border-l-4 ${riskBorder(row.risk_level)}`}
                    >
                      <td className="px-4 py-3 font-medium text-[#0A2540]">
                        <div className="truncate">{row.patient_name}</div>
                      </td>
                      <td className="px-4 py-3 text-muted-foreground">
                        {row.age ?? "—"} · {row.gender || "—"}
                      </td>
                      <td className="px-4 py-3 font-mono text-xs text-muted-foreground">
                        {row.phone_masked || "—"}
                      </td>
                      <td className="px-4 py-3 font-mono text-xs text-muted-foreground">{row.mrn_display}</td>
                      <td className="px-4 py-3">
                        <RiskBadge level={row.risk_level} />
                      </td>
                      <td className="px-4 py-3 font-mono text-xs text-muted-foreground">
                        {row.last_screening_at ? new Date(row.last_screening_at).toLocaleString() : "—"}
                      </td>
                      <td className="px-4 py-3 font-mono text-xs">
                        <div className="truncate">{row.camp_id || "—"}</div>
                      </td>
                      <td className="px-4 py-3 text-xs capitalize">{row.review_status}</td>
                      <td className="px-4 py-3">{slaBadge(row.sla_status)}</td>
                      <td className="px-4 py-3 text-right">
                        <div className="flex justify-end gap-2">
                        <button
                          type="button"
                          data-testid={`open-patient-${row.patient_id}`}
                          className="inline-flex items-center gap-1 rounded-lg border border-input bg-background px-3 py-1.5 text-xs font-semibold hover:bg-muted"
                          onClick={() => nav(`/doctor/patient/${row.patient_id}`)}
                        >
                          Patient
                        </button>
                        <button
                          type="button"
                          data-testid={`review-session-${row.session_id}`}
                          className="inline-flex items-center gap-1 rounded-lg border border-input bg-background px-3 py-1.5 text-xs font-semibold hover:bg-muted"
                          onClick={() => nav(`/doctor/session/${row.session_id}`)}
                        >
                          Review
                          <ChevronRight size={14} />
                        </button>
                        </div>
                      </td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
          {!loading && rows.length > 0 && (
            <div className="flex flex-col gap-3 border-t border-border bg-background px-4 py-3 sm:flex-row sm:items-center sm:justify-between">
              <div className="text-xs text-muted-foreground">
                Showing{" "}
                <span className="font-mono text-foreground">
                  {startIdx + 1}–{endIdx}
                </span>{" "}
                of <span className="font-mono text-foreground">{totalRows}</span>
              </div>
              <div className="flex flex-wrap items-center justify-between gap-2 sm:justify-end">
                <div className="flex items-center gap-2">
                  <span className="text-xs text-muted-foreground">Rows</span>
                  <select
                    value={pageSize}
                    onChange={(e) => {
                      setParam("pageSize", String(e.target.value));
                      setParam("page", "1");
                    }}
                    className="h-9 rounded-xl border border-border bg-background px-2 text-sm text-foreground"
                    aria-label="Rows per page"
                  >
                    {[25, 50, 100].map((n) => (
                      <option key={n} value={n}>
                        {n}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() => setParam("page", String(Math.max(1, safePage - 1)))}
                    disabled={safePage <= 1}
                    className="h-9 rounded-xl border border-border bg-background px-3 text-sm font-semibold text-foreground hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    Prev
                  </button>
                  <div className="text-xs text-muted-foreground">
                    Page <span className="font-mono text-foreground">{safePage}</span> /{" "}
                    <span className="font-mono text-foreground">{totalPages}</span>
                  </div>
                  <button
                    type="button"
                    onClick={() => setParam("page", String(Math.min(totalPages, safePage + 1)))}
                    disabled={safePage >= totalPages}
                    className="h-9 rounded-xl border border-border bg-background px-3 text-sm font-semibold text-foreground hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    Next
                  </button>
                </div>
              </div>
            </div>
          )}
        </DashboardCard>
      </section>
    </div>
  );
}
