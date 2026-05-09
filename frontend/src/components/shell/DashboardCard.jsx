/** White / card panel used across staff and patient dashboards. */
export default function DashboardCard({ children, className = "", as: Tag = "div", ...rest }) {
  return (
    <Tag
      className={`rounded-2xl border border-border bg-card text-card-foreground shadow-sm ${className}`}
      {...rest}
    >
      {children}
    </Tag>
  );
}
