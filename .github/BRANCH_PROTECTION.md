# Branch Protection Rules

Apply these rules at:  
**GitHub → Settings → Branches → Add rule → Branch name pattern: `main`**

## Required settings

| Setting | Value |
|---|---|
| Require a pull request before merging | ✅ Enabled |
| Required approving reviews | **1** (min) |
| Dismiss stale reviews on new push | ✅ Enabled |
| Require review from Code Owners | ✅ Enabled |
| Require status checks to pass | ✅ Enabled |
| Required status checks | `lint` · `test` · `bandit` · `trivy-deps` · `trivy-image` |
| Require branches to be up to date | ✅ Enabled |
| Require conversation resolution | ✅ Enabled |
| Restrict who can push to matching branches | ✅ Enabled (admins only for hotfix) |
| Allow force pushes | ❌ Disabled |
| Allow deletions | ❌ Disabled |
| Require signed commits | ✅ Enabled |
| Do not allow bypassing the above settings | ✅ Enabled for everyone inc. admins |

## CODEOWNERS

Create `.github/CODEOWNERS`:

```
# All backend changes require review from a backend engineer
/amblyopia_backend/   @Anandhusnair007-1

# CI/CD changes require DevOps review
/.github/             @Anandhusnair007-1

# Compliance docs require security review
/amblyopia_backend/docs/compliance/  @Anandhusnair007-1
```

## Secrets required (Settings → Secrets → Actions)

| Secret | Description |
|---|---|
| `CI_ENCRYPTION_KEY` | 32-byte base64 key for test environment |
| `GHCR_PAT` | GitHub PAT with `packages:write` (for push) |
| `SLACK_WEBHOOK` | Optional: failure notifications |

## GitHub Environments

Create two environments:

| Environment | Required reviewers | Deployment branch |
|---|---|---|
| `staging`    | 0 (auto-deploy on main) | `main` |
| `production` | 1 (manual approval)     | `v*` tags only |
