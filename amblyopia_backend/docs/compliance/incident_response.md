# Incident Response Plan — Amblyopia Care System

**Document ID:** DPDP-IRP-001  
**Version:** 1.0  
**Last Updated:** 2025  
**Owner:** Security Engineering  
**Regulatory Basis:** DPDP Act 2023 Section 8(6) — breach notification within 72 hours  

---

## 1. Incident Classification

| Severity | Definition | Examples | Response Target |
|----------|-----------|----------|-----------------|
| Critical | Confirmed patient PII breach, service down | DB dump exfiltrated, ransomware | Immediate (< 1h) |
| High | Suspected breach, sustained outage | Auth bypass, > 4h downtime | < 4 hours |
| Medium | Security anomaly, degraded service | Unusual access pattern, API errors | < 24 hours |
| Low | Near-miss, minor anomaly | Failed login spike, config warning | Next business day |

---

## 2. Incident Response Team

| Role | Responsibility | Contact |
|------|---------------|---------|
| Incident Commander | Coordinates response, external comms | Platform Lead |
| Security Lead | Technical investigation, containment | Security Engineer |
| Backend Lead | Code-level investigation, patching | Backend Developer |
| DPO (Data Protection Officer) | DPDP Act compliance, regulator notification | Appointed DPO |
| Communications | Internal & patient notification | Product/Comms |

---

## 3. Response Phases

### Phase 1 — Detection (0–30 min)

**Triggers:**
- Prometheus alert fired (error rate, auth spike, model integrity failure)
- fail2ban ban triggered at high volume
- Grafana dashboard anomaly
- User report via grievance portal
- Third-party security researcher disclosure

**Actions:**
1. Alert received and acknowledged in Slack #security channel
2. Incident Commander convened
3. Initial severity classification assigned
4. Incident record created (ticket + log)

---

### Phase 2 — Containment (30 min – 4h)

**For Critical / High severity:**

1. **Isolate affected service:**
   ```bash
   # Take backend offline (maintenance mode)
   docker-compose -f docker/docker-compose.prod.yml stop backend
   ```

2. **Revoke all active JWTs** (if credential compromise suspected):
   ```bash
   # Flush Redis JWT revocation list — forces all re-login
   redis-cli FLUSHDB
   ```

3. **Rotate secrets immediately:**
   ```bash
   # Generate new SECRET_KEY
   python -c "import secrets; print(secrets.token_hex(32))"
   # Update .env and restart
   ```

4. **Block attacker IP** (if identified):
   ```bash
   sudo ufw insert 1 deny from <ATTACKER_IP>
   ```

5. **Preserve evidence:**
   ```bash
   # Snapshot application logs before any rotation
   tar -czf /tmp/incident_$(date +%Y%m%d_%H%M%S)_logs.tar.gz /var/log/amblyopia/
   aws s3 cp /tmp/incident_*.tar.gz s3://<BUCKET>/incident-evidence/
   ```

---

### Phase 3 — Investigation (4h – 48h)

1. Determine scope of compromise:
   - Which records were accessed? → Query `audit_logs` table
   - Which patient IDs are affected? → Cross-reference with access logs
   - Was PII exfiltrated? → S3 access logs, Nginx access logs

2. Root cause analysis:
   - Code review of affected endpoints
   - Dependency vulnerability check: `pip-audit`
   - Container image scan: `trivy image <name>`

3. Document timeline of events

4. Determine whether DPDP notification threshold is met (PII of natural persons affected)

---

### Phase 4 — Eradication (48h – 72h)

1. Patch the vulnerability (PR → CI → deploy)
2. Re-verify model integrity: `./scripts/restore_drill.sh --dry-run`
3. Rotate all credentials (DB password, S3 keys, JWT secret)
4. Update `.env` via secrets manager (never commit to git)
5. Re-run full CI pipeline including Trivy + Bandit

---

### Phase 5 — Recovery

1. Restore service from last known-good backup if data corrupted
2. Perform DR drill to validate restored data
3. Re-enable production service with enhanced monitoring
4. Notify affected users (if required)

---

### Phase 6 — Post-Incident Review

Complete within 5 business days:

1. Write post-mortem document (blameless):
   - Timeline
   - Root cause
   - Actions taken
   - What worked / what didn't
   - Follow-up actions with owners and deadlines

2. Update risk register (if new risk identified)
3. Update threat model
4. File in `docs/post-mortems/` (internal only)

---

## 4. DPDP Act 2023 Breach Notification

| Threshold | Affected individuals | Action required |
|-----------|---------------------|-----------------|
| Any confirmed breach of personal data | > 0 individuals | Notify Data Protection Board within 72 hours |
| Breach affects sensitive personal data | Any | Enhanced notification; notify affected individuals |

**Notification content (Section 8(6)):**
- Nature of breach
- Personal data involved
- Estimated number of individuals affected
- Likely consequences
- Measures taken

**Contact:** Data Protection Board of India  
**DPO escalation email:** dpo@amblyopiacare.in

---

## 5. Contact Escalation Tree

```
Detection → Security Lead
  └─ Critical/High: → Incident Commander + DPO (< 1h)
       └─ Potential PII breach: → Legal + DPO (< 4h)
            └─ Confirmed breach: → Board + DPBI (< 72h)
```
