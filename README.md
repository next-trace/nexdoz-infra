# nexdoz-infra

Deployment infrastructure for Nexdoz on DigitalOcean EU.

One public repo, four moving parts:
- `docker-compose.prod.yml` — the production stack (Caddy, user-api, web, Postgres)
- `Caddyfile` — auto-HTTPS reverse proxy for `api.${DOMAIN}` + `app.${DOMAIN}`
- `scripts/provision.sh` — one-shot droplet bootstrap (idempotent)
- `scripts/deploy.sh` — pull latest images + restart, called by the deploy workflow

## First-time setup (you, once)

1. **Create a DO droplet** — 2 GB, Frankfurt (or Amsterdam), Ubuntu 24.04 x64. Note the IP.
2. **Buy a domain** and add two DNS `A` records pointing at the droplet IP:
   - `api.yourdomain.example` → DROPLET_IP
   - `app.yourdomain.example` → DROPLET_IP
   - (Optional) apex `yourdomain.example` → DROPLET_IP for the redirect to app.
3. **Create an SSH keypair** for deployment (separate from your personal key):
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/nexdoz_deploy -N ""
   ```
4. **Run provision.sh on the fresh droplet** (adds your deploy key, hardens SSH, installs docker, clones this repo):
   ```bash
   scp scripts/provision.sh root@DROPLET_IP:/root/
   ssh root@DROPLET_IP \
     "DEPLOY_PUBKEY='$(cat ~/.ssh/nexdoz_deploy.pub)' bash /root/provision.sh"
   ```
5. **Fill the environment file** on the droplet:
   ```bash
   ssh deploy@DROPLET_IP
   cd /opt/nexdoz
   cp .env.dist .env
   # Use `openssl rand -hex 32` to generate POSTGRES_PASSWORD, ENCRYPTION_KEY,
   # JWT_SECRET, AUTH_SECRET. Set DOMAIN + CADDY_EMAIL to yours.
   nano .env
   ```
6. **Add GitHub Actions secrets** on `next-trace/nexdoz-infra`:
   - `SSH_PRIVATE_KEY` — contents of `~/.ssh/nexdoz_deploy`
   - `SSH_KNOWN_HOSTS` — output of `ssh-keyscan DROPLET_IP`
   - `DROPLET_HOST` — DROPLET_IP or api.yourdomain.example
   - `PROD_DOMAIN` — yourdomain.example
7. **Trigger the first deploy**:
   ```bash
   gh workflow run deploy-prod.yml --repo next-trace/nexdoz-infra
   ```
8. **Verify**:
   ```bash
   curl -sfI https://api.yourdomain.example/healthz    # → 200 OK
   curl -sfI https://app.yourdomain.example/           # → 200 OK
   ```

## Ongoing deploys

New versions of `nexdoz-user-api` or `nexdoz-web` automatically publish Docker images to `ghcr.io/next-trace/*` on tag push. To roll them out:
- Option A — bump `USER_API_VERSION` / `WEB_VERSION` in `.env` on the droplet, then re-run `deploy.sh`.
- Option B — tag `nexdoz-infra` itself (e.g. `v0.1.1`) and the deploy workflow fires automatically.

## What this repo does NOT contain

- Real secrets (everything in `.env.dist` is a placeholder).
- Legal text (see `docs/*-DRAFT.md` for structural drafts; always legally reviewed before production use).
- CI for the application code (each app has its own CI).

## Scope and status

- ✅ Ready for **internal test / dogfood** deployment.
- ⚠️  NOT ready for **private beta** (real EU patients) until DPIA, DPO, DO DPA, consent flow, and MDR scope decision are complete — see `docs/MDR-SCOPE-DECISION.md`.
- ⚠️  NOT ready for **public launch** without external pen test, legal review, and CE mark if MDR Class IIa.

## Files

| Path | Purpose |
|---|---|
| `docker-compose.prod.yml` | Prod stack definition |
| `Caddyfile` | TLS + reverse-proxy config |
| `.env.dist` | Env variable template (never commit a real `.env`) |
| `scripts/provision.sh` | Droplet bootstrap (run once) |
| `scripts/deploy.sh` | Pull + restart (called by workflow) |
| `scripts/backup.sh` | Nightly Postgres → DO Spaces |
| `.github/workflows/deploy-prod.yml` | Manual + tag-triggered deploy |
| `.github/workflows/ci.yml` | Validate compose + shellcheck on PRs |
| `docs/` | Compliance scaffolding (drafts) |
| `dashboards/` | Better Stack dashboard JSON |
| `loadtest/` | k6 load test scripts |
