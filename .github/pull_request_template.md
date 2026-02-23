## Summary
<!-- One sentence: what does this PR do and why? -->


## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Refactor / code cleanup
- [ ] CI/CD / DevSecOps
- [ ] Documentation
- [ ] Dependency update

## Affected Component
- [ ] Flutter app (`amblyopia_app/`)
- [ ] Backend API (`amblyopia_backend/app/`)
- [ ] ML pipeline (`amblyopia_backend/integrations/`)
- [ ] Database / migrations
- [ ] Docker / infra
- [ ] GitHub Actions

---

## DevSecOps Checklist
- [ ] No hardcoded secrets, passwords, or API keys
- [ ] No PHI / patient data in code or tests
- [ ] New dependencies reviewed for known CVEs (`pip-audit` / `trivy`)
- [ ] `flutter analyze` passes with zero warnings (for app changes)
- [ ] `bandit` shows no new HIGH/CRITICAL issues (for backend changes)
- [ ] All new env vars documented in `.env.example`
- [ ] Android permissions minimal (only what's needed)
- [ ] cleartext HTTP restricted to emulator local backend only

## Testing
- [ ] Unit tests added / updated
- [ ] Tested on device / emulator
- [ ] Offline mode tested (SQLite fallback)
- [ ] Multi-language tested (EN / Tamil / Malayalam)

## Screenshots / Recordings
<!-- For UI changes, attach before/after screenshots -->


## Related Issues
Closes #
