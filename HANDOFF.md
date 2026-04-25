# Nexdoz — Launch Hand-off

Generated: **2026-04-24**
Target: **internal-test / dogfood** deployment on DigitalOcean EU.

Everything Claude can build without your credentials is built and shipping from `ghcr.io/next-trace/*`. What's left is the stuff that needs your GitHub/DO/legal identity. This file is the punch list.

---

## 1. What you need to do (in order)

### 1.1 Flip ghcr.io package visibility to public

The release workflows published images but the packages default to **private**. Anonymous `docker pull` fails until you flip the switch.

1. https://github.com/orgs/next-trace/packages/container/nexdoz-user-api/settings → **Change visibility** → Public (type `nexdoz-user-api` to confirm).
2. https://github.com/orgs/next-trace/packages/container/nexdoz-web/settings → same (type `nexdoz-web`).

Verify:
```bash
docker pull ghcr.io/next-trace/nexdoz-user-api:v0.2.0
docker pull ghcr.io/next-trace/nexdoz-web:v0.1.3
```

### 1.2 DigitalOcean setup

1. Create DO account + EU droplet (**2 GB RAM / 1 vCPU**, Frankfurt, Ubuntu 24.04 x64). Note the public IP.
2. Sign the **DO Data Processing Addendum** (https://www.digitalocean.com/legal/data-processing-agreement).
3. Optionally create a DO Spaces bucket for nightly Postgres backups (`scripts/backup.sh` targets it).

### 1.3 Domain + DNS

1. Buy a domain (registrar doesn't matter).
2. Add two `A` records, both pointing at the droplet IP:
   - `api.yourdomain.example` → DROPLET_IP
   - `app.yourdomain.example` → DROPLET_IP

### 1.4 SSH keypair for deployment

```bash
ssh-keygen -t ed25519 -f ~/.ssh/nexdoz_deploy -N ""
```
Add `~/.ssh/nexdoz_deploy.pub` to the droplet's root `authorized_keys` before running `provision.sh`.

### 1.5 Provision the droplet

```bash
scp scripts/provision.sh root@DROPLET_IP:/root/
ssh root@DROPLET_IP \
  "DEPLOY_PUBKEY='$(cat ~/.ssh/nexdoz_deploy.pub)' bash /root/provision.sh"
```
This installs Docker, hardens SSH (no root, no password), sets up UFW + fail2ban, creates a `deploy` user, clones this repo to `/opt/nexdoz`.

### 1.6 Fill .env on the droplet

```bash
ssh -i ~/.ssh/nexdoz_deploy deploy@DROPLET_IP
cd /opt/nexdoz
cp .env.dist .env
# Generate secrets:
for k in POSTGRES_PASSWORD ENCRYPTION_KEY JWT_SECRET AUTH_SECRET; do
  echo "$k=$(openssl rand -hex 32)"
done
# then:
nano .env    # paste above; set DOMAIN, CADDY_EMAIL, LOGGER_* if using BetterStack
```
Defaults already pin the latest published images: `USER_API_VERSION=v0.2.0`, `WEB_VERSION=v0.1.3`.

### 1.7 Add GitHub Actions secrets

On https://github.com/next-trace/nexdoz-infra/settings/secrets/actions:
- `SSH_PRIVATE_KEY` — contents of `~/.ssh/nexdoz_deploy` (whole file including `-----BEGIN ... END ... -----`)
- `SSH_KNOWN_HOSTS` — output of `ssh-keyscan DROPLET_IP`
- `DROPLET_HOST` — DROPLET_IP or `api.yourdomain.example`
- `PROD_DOMAIN` — your domain root (`yourdomain.example`)

### 1.8 First deploy

```bash
gh workflow run deploy-prod.yml --repo next-trace/nexdoz-infra
```
Watch it in the Actions tab. The workflow SSHes to the droplet, pulls images, restarts the stack, polls `/healthz` for 60s.

### 1.9 Smoke test

```bash
curl -sfI https://api.yourdomain.example/healthz       # → 200
curl -sfI https://api.yourdomain.example/readyz        # → 200 (DB-connected)
curl -sI  https://api.yourdomain.example/metrics       # → 200 (Prometheus)
curl -sfI https://app.yourdomain.example/              # → 200
```

### 1.10 Create the first user (optional smoke)

```bash
curl -X POST https://api.yourdomain.example/users \
  -H 'Content-Type: application/json' \
  -d '{"email":"you@yourdomain.example","password":"PickAGoodOneHere123!","phone_number":"+49xxxxxxxxx","first_name":"First","last_name":"Last","gender":"male","relationship_status":"single","birth_date":"1990-01-01T00:00:00Z"}'
```

---

## 2. What Claude already did (so you don't redo it)

### Shipped this window
- `ghcr.io/next-trace/nexdoz-user-api:v0.2.0` — real API (was a Hello-World stub on main before today).
- `ghcr.io/next-trace/nexdoz-web:v0.1.3` — split-repo layout, logo refresh, Dockerfile fix, publish workflow.
- `ghcr.io/next-trace/nexdoz-design-system:v0.1.2` — logo smile direction corrected (was a frown at every size).
- `ghcr.io/next-trace/nexdoz-mobile:v0.1.2` — matching logo refresh + Android mipmap regeneration for all 5 density buckets.
- `next-trace/nexdoz-infra:v0.1.0` — this repo (compose, Caddy, provision/deploy/backup scripts, compliance drafts).

### Landed security + observability on user-api
- `/healthz`, `/readyz`, `/metrics` (Prometheus) routes.
- `nexdozlogger.NewFromEnv()` at boot — **fails fast** if `LOGGER_SINK=betterstack` and no token.
- bcrypt cost **12** (was `bcrypt.DefaultCost` = 10).
- Auth rate limit on `/auth/login` + `/auth/refresh` — env-configurable:
  - `AUTH_RATE_LIMIT_PER_MINUTE` (default 10, 0 disables)
  - `AUTH_RATE_LIMIT_BURST` (default 3)
- Graceful shutdown on SIGTERM/SIGINT, 5s drain.

### Cross-repo ops
- Dependabot enabled on all 11 repos (weekly grouped gomod/npm + github-actions).
- User-facing FE scrubbed — `FrontEnd/` is now just a pointer; the three repos (design-system, web, mobile) are cloned inside for local dev.

---

## 3. Known deferred items (not launch-blocking for internal-test)

### 3.1 Security (dependabot will PR these)
| Repo | Finding | Fix | Severity |
|---|---|---|---|
| all BE | 5 stdlib CVEs in `crypto/{x509,tls}` + `html/template` | Bump `go 1.26.1` → `1.26.2` in go.mod | Medium. Runtime already uses latest 1.26.x via the Docker `golang:1.26-alpine` base; govulncheck reports based on the `go` directive. |
| api-infra, testkit | `go-chi/chi v5.2.1` | → `v5.2.2` | Medium |
| api-infra | `gofiber/fiber v2.52.8` | → `v2.52.12` | Medium |
| email | `golang.org/x/net v0.19.0` | → `v0.23.0` | Medium |
| email | `google.golang.org/protobuf v1.31.0` | → `v1.33.0` | Medium |
| web, mobile | PostCSS `<8.5.10` XSS (transitive via Next.js) | Next.js bump | Moderate |

### 3.2 Product scope
- **MDR scope decision** — `docs/MDR-SCOPE-DECISION.md`. Class IIa (active medical device) requires CE mark + notified body → months of work. Diary-only (lifestyle/wellness) with a clear disclaimer is deployable today. **This is the single biggest blocker for private beta**, not for internal test.
- **Legal review** of `docs/PRIVACY-DRAFT.md`, `docs/TERMS-DRAFT.md`. Drafts are GDPR-structured but NOT legally reviewed.
- **DPIA** — `docs/DPIA-TEMPLATE.md` is empty; fill with real processing purposes + risks before beta.

### 3.3 Engineering follow-ups
- `GET /users/{id}/export` — GDPR Art. 15 / 20 data-export endpoint. Not implemented.
- `notification-icon.png` on mobile ships as a coloured mark; Android wants a white silhouette. Pre-existing; tracked in the mobile PR notes.
- No `mipmap-anydpi-v26/ic_launcher.xml` adaptive-icon descriptor in nexdoz-mobile. MIUI and modern Android apply their own masking — not broken, but not as polished as dedicated foreground/background layers.
- `rate_limit_test.go` unit coverage for the new middleware.
- Web api-client regeneration against user-api's post-v0.2.0 OpenAPI spec (wip branch added 29 new YAML fragments).
- `.plan/production-readiness-and-digitalocean-launch-20260424.md` Phase 5 "Prometheus /metrics + request-histogram" landed via the wip merge, but the specific `http_request_duration_seconds` histogram + `http_requests_total` counter enumeration should be verified against any Grafana/Better Stack dashboard you wire up.

### 3.4 Operational follow-ups
- `scripts/backup.sh` is drafted but not yet scheduled by `provision.sh`'s cron. Add the cron entry before you care about restoring.
- Single droplet = single point of failure. Acceptable for internal test. For private beta, move to DOKS or at minimum a multi-droplet setup with a managed Postgres.
- `/metrics` is unprotected today. Before exposing it publicly, either gate it by IP or put it on a different port that Caddy doesn't expose.

---

## 4. Rollback recipe

If a deploy goes sideways:

```bash
ssh deploy@DROPLET_IP
cd /opt/nexdoz
# Flip image tag back
sed -i 's/^USER_API_VERSION=.*/USER_API_VERSION=v0.1.1/' .env   # or previous known-good
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
# Postgres data is in the pg_data named volume. If a migration went wrong, restore
# from the nightly pg_dump in DO Spaces (see scripts/backup.sh).
```

For the ghcr.io images themselves, there is no "unpublish" — roll forward by tagging a new version, never delete.

---

## 5. Who owns what

| Thing | Owner |
|---|---|
| ghcr.io package visibility flip | **You** (§1.1) |
| DO account, droplet, DNS, SSH keys | **You** (§1.2-1.4) |
| `.env` on droplet (secrets) | **You** (§1.6) |
| GitHub Actions secrets | **You** (§1.7) |
| MDR scope decision | **You** (founder call) |
| Legal text finalisation | **You + your lawyer** |
| Everything else | Code + CI |

---

## 6. Emergency contacts / references

- **GDPR breach clock**: 72 hours from discovery → notify supervisory authority (`docs/BREACH-PLAYBOOK.md`).
- **DPO**: not appointed yet — required under GDPR Art. 37 if you process health data systematically (you do). Appoint before private beta.
- **DO status**: https://status.digitalocean.com
- **Better Stack**: https://betterstack.com (optional — `LOGGER_SINK=betterstack` once a source token exists).
- **GitHub org**: https://github.com/next-trace

---

When §1.1-§1.9 are green, you're live on internal-test.
