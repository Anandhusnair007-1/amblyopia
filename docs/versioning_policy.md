# Versioning Policy — Amblyopia Care System

**Document ID:** DPDP-VP-001  
**Version:** 1.0  
**Last Updated:** 2025  
**Owner:** Platform Engineering  

---

## 1. Version Scheme

This project follows **Semantic Versioning 2.0.0** ([semver.org](https://semver.org)):

```
MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]
```

| Segment     | Meaning | Example triggers |
|-------------|---------|-----------------|
| **MAJOR**   | Breaking API change, major architecture refactor, regulatory re-compliance | v2.0.0 — new auth system incompatible with v1 tokens |
| **MINOR**   | New feature, new endpoint, new ML model, backwards-compatible | v1.1.0 — add Red-Green test module |
| **PATCH**   | Bug fix, security patch, dependency update, documentation | v1.0.1 — fix gaze deviation calculation |
| **PRERELEASE** | Non-production builds for testing | v1.1.0-rc.1, v1.1.0-beta.2 |

---

## 2. Branch Strategy

```
main              ← production-ready code only. Protected.
  └── develop     ← integration branch; all feature PRs merge here
        ├── feature/<ticket>-<slug>     (feature work)
        ├── fix/<ticket>-<slug>         (bug fixes)
        ├── hotfix/<ticket>-<slug>      (critical production fixes)
        └── security/<ticket>-<slug>   (security fixes, may be fast-tracked)
```

### Merge Rules

| Source branch | Target | Requires | Release tag |
|--------------|--------|----------|-------------|
| `feature/*`  | `develop` | 1 PR approval + CI pass | No |
| `fix/*`      | `develop` | 1 PR approval + CI pass | No |
| `develop`    | `main`    | 2 PR approvals + CI pass + release notes | Yes (MINOR or MAJOR) |
| `hotfix/*`   | `main` + `develop` | 1 approval + CI pass (fast-track) | Yes (PATCH) |
| `security/*` | `main` + `develop` | Security lead approval + CI pass | Yes (PATCH) |

---

## 3. Tagging Protocol

All releases are created via **annotated Git tags** on `main`:

```bash
# Standard release
git tag -a v1.1.0 -m "Release v1.1.0: Add Red-Green test ML module"
git push origin v1.1.0

# Hotfix
git tag -a v1.0.1 -m "Hotfix v1.0.1: Fix gaze deviation NaN crash"
git push origin v1.0.1

# Release candidate
git tag -a v1.1.0-rc.1 -m "RC 1 for v1.1.0 — pending QA sign-off"
git push origin v1.1.0-rc.1
```

Pushing a `v*` tag automatically triggers `.github/workflows/release.yml` which:
1. Runs the full CI pipeline
2. Builds and signs the Docker image
3. Runs Trivy security gate
4. Creates a GitHub Release with changelog notes
5. Generates and attests SBOM
6. Notifies Slack

---

## 4. Version File

The canonical version is defined in `amblyopia_backend/app/config.py` and reflected in:

| File | Field | Updated by |
|------|-------|-----------|
| `app/config.py` | `APP_VERSION = "1.0.0"` | Developer, before tag |
| `app/main.py` health endpoint | `"version": "1.0.0"` | Developer, before tag |
| `CHANGELOG.md` | New version section | Developer, before tag |
| `docker/Dockerfile` | `LABEL org.opencontainers.image.version` | CI (from `--build-arg VERSION`) |
| Git tag | `v1.0.0` | Developer, after merge to main |

---

## 5. Pre-Release Naming Convention

| Suffix | Meaning | Deployment target |
|--------|---------|------------------|
| `-alpha.N` | Early development preview | Developer laptops only |
| `-beta.N`  | Feature complete, active QA | Staging environment |
| `-rc.N`    | Release candidate, final QA | Staging + pilot approval |
| *(none)*   | Stable release | Production |

---

## 6. Hotfix Process

For critical bugs or security vulnerabilities in production:

1. Branch from `main`: `git checkout -b hotfix/CVE-XXXX-XXXX main`
2. Apply minimal fix
3. Update `CHANGELOG.md` under new PATCH version
4. Increment PATCH version in config.py / main.py
5. PR → `main` (fast-track: 1 approval required)
6. After merge to `main`, also merge to `develop`
7. Tag: `git tag -a v1.0.X` → triggers automated release pipeline

---

## 7. Deprecation Policy

- APIs are deprecated with `X-Deprecation-Warning` header for a **minimum of one MINOR release** before removal
- Deprecated endpoints are documented in `CHANGELOG.md` under `### Deprecated`
- Breaking changes always bump the MAJOR version

---

## 8. Compliance Release Requirements

For any release affecting:
- Patient PII handling
- Authentication / authorisation logic  
- ML model inference
- Data retention or deletion

The release must include:
1. Updated risk register review
2. Security controls checklist sign-off
3. DR drill completed post-deploy
4. DPO notification if DPDP Act scope changes
