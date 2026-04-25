# Security posture

## Secrets inventory

Every secret required to run the stack. None committed to this repo.

| Secret | Source | Rotation | Stored where |
|---|---|---|---|
| `POSTGRES_PASSWORD` | `openssl rand -hex 32` | Annual, or on known compromise | `.env` on droplet (file mode 600, owner `deploy`) |
| `ENCRYPTION_KEY` | `openssl rand -hex 32` | Never (rotating invalidates all stored encrypted data — see rotation-procedure.md when written) | `.env` on droplet |
| `JWT_SECRET` | `openssl rand -hex 32` | Quarterly (invalidates active sessions) | `.env` on droplet |
| `AUTH_SECRET` | `openssl rand -hex 32` | Quarterly | `.env` on droplet |
| `SSH_PRIVATE_KEY` (deploy) | `ssh-keygen -t ed25519` | Annual, or on operator change | GitHub Actions secret + operator's `~/.ssh/` |
| `LOGGER_BETTERSTACK_SOURCE_TOKEN` | Better Stack dashboard | On Better Stack prompt | `.env` on droplet |
| `OPENAI_API_KEY` / `GEMINI_API_KEY` / `ANTHROPIC_API_KEY` | Each vendor's dashboard | Quarterly | `.env` on droplet |
| `GITHUB_TOKEN` (ghcr.io read) | Auto-provided in Actions | Per-run ephemeral | Actions env |

## Access policy

- DO droplet root access — `root` SSH disabled by `provision.sh`. Only the DO web console allows root.
- `deploy` user on droplet — SSH key-only, can run `docker`, `docker compose`, `systemctl restart fail2ban` via NOPASSWD sudo. No shell access to other services.
- GitHub org `next-trace` — owner must enable 2FA for all members.
- ghcr.io images — public (anonymous pull allowed).

## Network posture

- UFW: default deny; allow `22/tcp` (SSH), `80/tcp` (Caddy HTTP-01 + redirect), `443/tcp` (Caddy TLS). Everything else blocked.
- fail2ban: SSH jail enabled (3 failed attempts → 1h ban).
- Caddy is the ONLY container with host-port bindings. Postgres, user-api, web communicate only on the `nexdoz_net` bridge.
- TLS: Caddy auto-provisions Let's Encrypt (HTTP-01 challenge via `:80`). Certs persist in `caddy_data` volume.
- HTTP → HTTPS: enforced by Caddy automatically.

## Dependency supply chain

- Go: `govulncheck ./...` runs in each BE repo's CI (TODO — to be added if not present).
- Node/pnpm: `pnpm audit --prod` — manual for now, Dependabot to be enabled per-repo.
- Docker images: base images (`golang:1.26-alpine`, `node:22-alpine`, `postgres:16-alpine`, `caddy:2-alpine`, `alpine:latest`) rebuilt monthly via a scheduled workflow (TODO).

## Application-layer controls

- Password hashing: bcrypt cost factor 12 (verify in `nexdoz-api-infra/helpers/hasher/password_hasher.go`).
- JWT: signed with `JWT_SECRET`, short-lived access tokens (15 min), longer refresh (7 days).
- CSRF: FE web uses double-submit cookie on mutating routes (per project CLAUDE.md).
- CORS: allow-list origins only — `https://app.${DOMAIN}` from BE.
- Rate limit on `/auth/login` + `/auth/refresh`: 10 req/min per IP (in-process, to be added if not present).
- Input validation: `nexdoz-validation` library at command boundary.

## Incident response

See `docs/BREACH-PLAYBOOK.md` (draft) for the 72-hour GDPR Art. 33 procedure.

## What is NOT in scope today

- External penetration test — required before public launch.
- WAF (Cloudflare or similar) — recommended for beta, required for public.
- Bug bounty — launch-only.
- SOC2 / ISO 27001 — aspirational; not a launch blocker for pre-revenue MVP.

## Reporting a vulnerability

Until a `security@` address is provisioned, report via GitHub Security Advisory on the affected repo: <https://github.com/next-trace/nexdoz-user-api/security/advisories/new>.
