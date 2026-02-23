#!/usr/bin/env bash
# =============================================================================
# Amblyopia Care System — Server Security Hardening Script
# =============================================================================
# Applies hospital-grade security hardening on a fresh Ubuntu 22.04 LTS host.
#
# WHAT THIS SCRIPT DOES:
#   1. System updates & minimal package install
#   2. UFW firewall (allow 22/TCP inbound SSH, 80/TCP, 443/TCP only)
#   3. fail2ban — brute-force protection (SSH, API, Nginx)
#   4. SSH hardening (disable root login, password auth, set key-only)
#   5. Kernel hardening (sysctl — disable IP forwarding, SYN cookies, etc.)
#   6. Logrotate config for application logs
#   7. Automatic security updates (unattended-upgrades)
#   8. Disable unnecessary services
#   9. CIS Benchmark Level 1 selected controls
#
# USAGE (run as root or with sudo):
#   chmod +x setup_server.sh
#   sudo ./setup_server.sh [--ssh-port 22] [--admin-ip <ip_or_cidr>]
#
# WARNING: This script modifies SSH configuration. Ensure you have a working
# SSH key pair BEFORE running, or you may lock yourself out.
# =============================================================================

set -euo pipefail

SSH_PORT="${SSH_PORT:-22}"
ADMIN_IP="${ADMIN_IP:-}"   # optional: restrict SSH to this IP/CIDR
LOG_FILE="/var/log/setup_server_$(date +%Y%m%d_%H%M%S).log"

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"; }
err()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "${LOG_FILE}" >&2; }
check_root() { [[ "$(id -u)" -eq 0 ]] || { err "Must run as root"; exit 1; }; }

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-port)  SSH_PORT="$2"; shift 2 ;;
    --admin-ip)  ADMIN_IP="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# ── 1. System update ──────────────────────────────────────────────────────────
update_system() {
  log "=== Step 1: System update ==="
  apt-get update -qq
  apt-get upgrade -y -qq
  apt-get install -y -qq \
    ufw fail2ban unattended-upgrades apt-listchanges \
    logrotate curl wget gnupg2 ca-certificates \
    auditd audispd-plugins
  log "  System packages updated."
}

# ── 2. UFW Firewall ──────────────────────────────────────────────────────────
configure_ufw() {
  log "=== Step 2: Configuring UFW firewall ==="

  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing
  ufw default deny forward

  # SSH — restrict to admin IP if provided
  if [[ -n "${ADMIN_IP}" ]]; then
    ufw allow from "${ADMIN_IP}" to any port "${SSH_PORT}" proto tcp comment "SSH (admin subnet)"
  else
    ufw allow "${SSH_PORT}/tcp" comment "SSH"
  fi

  # HTTP and HTTPS (Nginx)
  ufw allow 80/tcp   comment "HTTP (redirect to HTTPS)"
  ufw allow 443/tcp  comment "HTTPS (Nginx TLS)"

  # Block common attack vectors explicitly
  ufw deny 23       comment "Block Telnet"
  ufw deny 3389     comment "Block RDP"
  ufw deny 5900     comment "Block VNC"

  # Enable UFW logging
  ufw logging on

  echo "y" | ufw enable
  ufw status verbose | tee -a "${LOG_FILE}"
  log "  UFW configured and enabled."
}

# ── 3. fail2ban ───────────────────────────────────────────────────────────────
configure_fail2ban() {
  log "=== Step 3: Configuring fail2ban ==="

  cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
backend  = systemd
action   = %(action_mwl)s

[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s
maxretry = 3
bantime  = 86400

# Nginx: generic HTTP auth failures
[nginx-http-auth]
enabled  = true
filter   = nginx-http-auth
logpath  = /var/log/nginx/error.log
maxretry = 5
bantime  = 3600

# Nginx: scan/bot 404s
[nginx-botsearch]
enabled  = true
filter   = nginx-botsearch
logpath  = /var/log/nginx/access.log
maxretry = 2
bantime  = 86400

# API brute-force — FastAPI /auth endpoints
[amblyopia-api-auth]
enabled   = true
filter    = amblyopia-api-auth
logpath   = /var/log/amblyopia/api.log
maxretry  = 10
findtime  = 300
bantime   = 3600
EOF

  # Custom filter for API auth endpoint failures
  cat > /etc/fail2ban/filter.d/amblyopia-api-auth.conf << 'EOF'
[Definition]
failregex = ^.*"POST /api/v1/auth/login.*" (401|422|429) .*$
            ^.*"POST /api/v1/auth/token.*" (401|422|429) .*$
ignoreregex =
EOF

  systemctl enable fail2ban
  systemctl restart fail2ban
  log "  fail2ban configured and started."
}

# ── 4. SSH hardening ──────────────────────────────────────────────────────────
harden_ssh() {
  log "=== Step 4: SSH hardening ==="

  # Backup original config
  cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak."$(date +%Y%m%d)"

  cat > /etc/ssh/sshd_config.d/99-amblyopia-hardening.conf << EOF
# Amblyopia Care System — SSH hardening
# Applied by setup_server.sh on $(date)

Port                    ${SSH_PORT}
Protocol                2
PermitRootLogin         no
PasswordAuthentication  no
ChallengeResponseAuthentication no
PubkeyAuthentication    yes
AuthorizedKeysFile      .ssh/authorized_keys

# Disable unused auth methods
PermitEmptyPasswords    no
KerberosAuthentication  no
GSSAPIAuthentication    no
UsePAM                  yes

# Restrict to sftp + no X11
X11Forwarding           no
AllowTcpForwarding      no
AllowAgentForwarding    no
PrintMotd               no

# Session hardening
MaxAuthTries            3
MaxSessions             5
LoginGraceTime          30
ClientAliveInterval     300
ClientAliveCountMax     2

# Restrict to strong algorithms
Ciphers                 aes256-gcm@openssh.com,aes128-gcm@openssh.com,chacha20-poly1305@openssh.com
MACs                    hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms           curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512

# Banner
Banner                  /etc/ssh/banner.txt
EOF

  cat > /etc/ssh/banner.txt << 'EOF'
*******************************************************************************
  NOTICE: This system is for authorized personnel of Amblyopia Care System only.
  All activities are monitored and logged. Unauthorized access is prohibited
  under applicable law. Disconnect immediately if not authorized.
*******************************************************************************
EOF

  sshd -t && systemctl restart sshd
  log "  SSH hardened. Port: ${SSH_PORT}, root login: disabled, password: disabled."
}

# ── 5. Kernel hardening (sysctl) ──────────────────────────────────────────────
harden_kernel() {
  log "=== Step 5: Kernel hardening (sysctl) ==="

  cat > /etc/sysctl.d/99-amblyopia-hardening.conf << 'EOF'
# Amblyopia Care System — Kernel hardening

# Network: disable IP forwarding (not a router)
net.ipv4.ip_forward                 = 0
net.ipv6.conf.all.forwarding        = 0

# SYN flood protection
net.ipv4.tcp_syncookies             = 1
net.ipv4.tcp_max_syn_backlog        = 2048
net.ipv4.tcp_synack_retries         = 2
net.ipv4.tcp_syn_retries            = 5

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects  = 0
net.ipv4.conf.all.send_redirects    = 0
net.ipv6.conf.all.accept_redirects  = 0

# Disable source routing
net.ipv4.conf.all.accept_source_route  = 0
net.ipv6.conf.all.accept_source_route  = 0

# Enable reverse path filtering
net.ipv4.conf.all.rp_filter         = 1
net.ipv4.conf.default.rp_filter     = 1

# Log suspicious packets
net.ipv4.conf.all.log_martians      = 1

# Disable IPv6 if not needed (comment out if IPv6 required)
# net.ipv6.conf.all.disable_ipv6    = 1

# Memory: protect kernel pointers
kernel.kptr_restrict                = 2
kernel.dmesg_restrict               = 1
kernel.perf_event_paranoid          = 3

# Disable ptrace (prevent process tracing by unprivileged users)
kernel.yama.ptrace_scope            = 2

# File system: restrict coredumps
fs.suid_dumpable                    = 0
kernel.core_uses_pid                = 1

# Address space layout randomization
kernel.randomize_va_space           = 2
EOF

  sysctl --system > /dev/null
  log "  Kernel parameters applied."
}

# ── 6. Logrotate for application logs ─────────────────────────────────────────
configure_logrotate() {
  log "=== Step 6: Configuring logrotate ==="

  cat > /etc/logrotate.d/amblyopia << 'EOF'
/var/log/amblyopia/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 amblyopia adm
    postrotate
        # Signal FastAPI to reopen log files
        systemctl reload amblyopia-api 2>/dev/null || true
    endscript
}

/var/log/nginx/amblyopia*.log {
    daily
    rotate 90
    compress
    delaycompress
    missingok
    sharedscripts
    postrotate
        [ -s /run/nginx.pid ] && kill -USR1 "$(cat /run/nginx.pid)"
    endscript
}
EOF

  logrotate -d /etc/logrotate.d/amblyopia 2>&1 | tee -a "${LOG_FILE}"
  log "  Logrotate configured."
}

# ── 7. Unattended security updates ───────────────────────────────────────────
configure_auto_updates() {
  log "=== Step 7: Automatic security updates ==="

  cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::Package-Blacklist {};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Mail "root";
EOF

  cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

  systemctl enable unattended-upgrades
  log "  Automatic security updates configured."
}

# ── 8. Disable unnecessary services ─────────────────────────────────────────
disable_services() {
  log "=== Step 8: Disabling unnecessary services ==="
  local services_to_disable=(
    avahi-daemon
    cups
    bluetooth
    isc-dhcp-server
    rpcbind
    nfs-server
  )

  for svc in "${services_to_disable[@]}"; do
    if systemctl is-enabled "${svc}" 2>/dev/null | grep -q "enabled"; then
      systemctl disable --now "${svc}" 2>/dev/null && \
        log "  Disabled: ${svc}" || true
    fi
  done
  log "  Unnecessary services disabled."
}

# ── 9. auditd — audit logging ─────────────────────────────────────────────────
configure_auditd() {
  log "=== Step 9: Configuring auditd ==="

  cat > /etc/audit/rules.d/amblyopia.rules << 'EOF'
# Amblyopia Care System — Audit rules

# Monitor all authentication events
-w /var/log/auth.log -p wa -k auth_log

# Monitor SSH configuration changes
-w /etc/ssh/sshd_config -p wa -k sshd_config

# Monitor sudoers
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers

# Monitor /etc/passwd and user management
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group  -p wa -k identity

# Log all commands run as root
-a always,exit -F arch=b64 -F euid=0 -S execve -k root_commands

# Monitor Docker socket (if present)
-w /var/run/docker.sock -p wa -k docker_socket

# Monitor application config directory
-w /home/amblyopia/amblyopia_backend/app/config.py -p wa -k app_config
EOF

  systemctl enable auditd
  systemctl restart auditd
  log "  auditd configured."
}

# ── Final summary ──────────────────────────────────────────────────────────────
print_summary() {
  log ""
  log "================================================================"
  log " Server Hardening Complete — $(date)"
  log " SSH Port      : ${SSH_PORT}"
  log " Root Login    : DISABLED"
  log " Password Auth : DISABLED"
  log " UFW Status    : $(ufw status | head -1)"
  log " fail2ban      : $(systemctl is-active fail2ban)"
  log " auditd        : $(systemctl is-active auditd)"
  log " Log           : ${LOG_FILE}"
  log "================================================================"
  log ""
  log " IMPORTANT: Test SSH access in a NEW session before closing this one!"
  log " Verify: ssh -p ${SSH_PORT} <your-user>@<host>"
  log ""
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  check_root
  log "=== Amblyopia Server Security Hardening START ==="
  log "  SSH Port: ${SSH_PORT} | Admin IP: ${ADMIN_IP:-any}"

  update_system
  configure_ufw
  configure_fail2ban
  harden_ssh
  harden_kernel
  configure_logrotate
  configure_auto_updates
  disable_services
  configure_auditd
  print_summary
}

main "$@"
