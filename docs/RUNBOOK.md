# Runbook (Dev → Staging → Prod)

This repository contains three main components:

- **LINE webhook + business logic**: `backend/` (FastAPI)
- **Odoo** (with custom addons): `odoo/`
- **Reverse proxy**: `nginx/`

The runbook is organized sequentially by environment:

1. **Dev (local Docker Compose)**
2. **Staging (same topology + external DB/Redis optional)**
3. **Prod (AWS ECS/EC2 + RDS + ElastiCache + ALB)**

Related docs:
- Credentials & Access: `docs/CREDENTIALS_ACCESS.md`
- Observability: `docs/OBSERVABILITY.md`
- Backup & Restore: `docs/BACKUP_RESTORE.md`
- Incident Playbooks: `docs/INCIDENT_PLAYBOOKS.md`
- AWS 1:1 Mapping (ECS/EC2/RDS): `docs/AWS_MAPPING_ECS_EC2_RDS.md`
- Readiness Checklist: `docs/READINESS_CHECKLIST.md`

---

## 0) Common prerequisites

- Docker Desktop (or docker engine + compose plugin)
- `curl`, `jq`
- LINE Developers console access (Messaging API channel)
- Odoo admin access (for initial setup and testing)

**Ports (local defaults)**
- Nginx: `http://localhost/`
- Backend direct: `http://localhost:8000/` (if exposed)
- Odoo direct: `http://localhost:8069/` (if exposed)

---

## 1) Dev (Local) — bring up the stack

### 1.1 Configure environment

1) Copy env templates:

```bash
cp .env.example .env
cp backend/.env.example backend/.env
```

2) Edit:
- `.env` (Postgres creds)
- `backend/.env` (LINE + Odoo creds)

> **Security note:** never commit `.env` or `backend/.env`. Use `.env.example` only.

### 1.2 Start services

```bash
docker compose up -d --build
docker compose ps
```

### 1.3 Verify health

Backend:
```bash
curl -s http://127.0.0.1/health | jq
curl -s http://127.0.0.1/line/health | jq
curl -s http://127.0.0.1/odoo/health | jq
```

If you expose backend directly (optional), also:
```bash
curl -s http://127.0.0.1:8000/health | jq
```

### 1.4 Smoke test LINE webhook (dev)

If using a tunnel (ngrok/cloudflared), set the LINE webhook URL to:
- `https://<your-domain>/line/webhook`

Then validate signature verification by sending a test message to your bot.

### 1.5 Dev troubleshooting quick hits

- View logs:
```bash
docker compose logs -f --tail=200 backend
docker compose logs -f --tail=200 odoo
docker compose logs -f --tail=200 nginx
```

- Reset DB (dev only):
```bash
docker compose down -v
docker compose up -d --build
```

---

## 2) Staging — deployment + validation

Staging should mirror production topology as closely as possible, but can start simple:

### 2.1 Recommended staging topology

- Nginx (or ALB) terminates traffic
- Backend (FastAPI) behind reverse proxy
- Odoo app
- Postgres (either containerized or RDS)
- Redis (either containerized or ElastiCache)

### 2.2 Configuration (staging)

**Do not use `.env` in staging/prod.** Store secrets in:
- AWS Secrets Manager or SSM Parameter Store

Use environment variables for:
- `LINE_CHANNEL_SECRET`
- `LINE_CHANNEL_ACCESS_TOKEN`
- `ODOO_URL`, `ODOO_DB`, `ODOO_USERNAME`, `ODOO_PASSWORD`
- `REDIS_URL`
- `ODOO_CALLBACK_SECRET`

### 2.3 Staging checklist

1) Deploy services
2) Verify health endpoints:
```bash
curl -s https://<staging-domain>/health | jq
curl -s https://<staging-domain>/odoo/health | jq
```

3) Run E2E test cases:
- Use: `docs/E2E_Test_Steps_vNext.md`
- Use staging runbook legacy steps: `docs/E2E_STAGING_RUNBOOK.md` (kept for reference)

4) Validate Odoo callback path:
- Trigger `POST /odoo/status_update` with the correct `secret`

### 2.4 Rollback (staging)

- If ECS: rollback to previous task definition revision
- If EC2: redeploy previous image tag
- If DB migration: restore from snapshot (see `docs/BACKUP_RESTORE.md`)

---

## 3) Prod (AWS) — ECS or EC2, with RDS

Production requirements:
- Managed DB: **RDS Postgres**
- Managed Redis: **ElastiCache Redis**
- TLS: **ACM + ALB** (preferred)
- Logs/metrics: **CloudWatch**
- Secrets: **Secrets Manager**

### 3.1 Deploy option A: ECS Fargate (recommended)

See `docs/AWS_MAPPING_ECS_EC2_RDS.md` for the 1:1 mapping and required AWS resources.

High-level steps:
1) Build/push images to ECR (backend, odoo, nginx optional)
2) Create ECS cluster + services
3) Configure ALB routes:
   - `/line/webhook` → backend
   - `/odoo/*` or `/` → odoo (or nginx if you keep nginx)
4) Configure Secrets Manager and inject env vars
5) Verify health and cutover DNS

### 3.2 Deploy option B: EC2 (docker compose on a VM)

Use when you want maximum simplicity (at the cost of ops burden).
- EC2 runs docker compose
- Use RDS + ElastiCache
- Use ALB or Nginx with certs

### 3.3 Production verification

- Health:
```bash
curl -s https://<prod-domain>/health | jq
curl -s https://<prod-domain>/odoo/health | jq
```

- Alerts: follow `docs/OBSERVABILITY.md`

---

## 4) Change management

- Any change affecting webhook behavior or Odoo models **must** have:
  - Staging validation (E2E)
  - Rollback plan
  - Backup confirmed within the last 24h (prod)

---

## 5) Incident response

Use `docs/INCIDENT_PLAYBOOKS.md`.

---

## Operating Principles

- Prefer **small, regular updates** over large infrequent changes
- Health checks + UAT are the **only gates**
- If the checklist passes, the change is approved
- If any item fails, stop and fix

---

## Monthly Update Checklist (Mandatory)

This checklist must be executed **once per month** or whenever dependency updates
are merged.

### Monthly Update Checklist

- [ ] **Dependabot PRs reviewed**
  - Dependency updates reviewed individually
  - CI checks passing
  - No unreviewed auto-merges

- [ ] **Containers rebuilt**
  ```bash
  docker compose build
  ```
  Images rebuilt with no errors.

- [ ] **Health checks green**
  ```bash
  curl http://localhost/health
  curl http://localhost:8000/health
  curl http://localhost:8000/odoo/health
  ```
  All endpoints must return OK.

- [ ] **UAT cases pass**
  - Execute relevant cases in `UAT_Execution_Worksheet.xlsx`
  - All impacted cases marked **PASS**
  - Evidence attached where applicable

- [ ] **Tag release**
  ```bash
  git tag vX.Y.Z
  git push --tags
  ```

- [ ] **Update Readiness Matrix**
  - `Enterprise_Readiness_Matrix.xlsx` updated
  - Status reflects current state
  - Acceptance criteria unchanged or re-validated

### Rule

> **If all checklist items are complete, the update is approved.**  
> **If any item fails, the update is blocked until resolved.**

No additional approval layers are required.

---

## Quarterly Odoo Upgrade Checklist (Controlled)

Odoo upgrades are **high-impact changes** and must be handled separately
from monthly updates.

Frequency: **Quarterly maximum**, or for critical security fixes.

### Quarterly Odoo Upgrade Checklist

- [ ] **Upgrade scoped**
  - Target Odoo version defined
  - Release notes reviewed
  - Breaking changes identified

- [ ] **Staging-only upgrade**
  - Upgrade performed in staging first
  - Production remains untouched

- [ ] **Database backup verified**
  - Pre-upgrade backup completed
  - Restore procedure verified

- [ ] **Module compatibility checked**
  - Custom modules reviewed
  - Third-party modules verified

- [ ] **Full UAT executed**
  - All UAT cases re-run
  - Failure & edge cases included
  - No regressions allowed

- [ ] **Performance sanity check**
  - Startup time acceptable
  - Core flows responsive

- [ ] **Rollback plan confirmed**
  - Previous image available
  - DB restore tested
  - Downgrade path understood

- [ ] **Business sign-off**
  - Business owner approval recorded
  - Ops approval recorded

### Rule

> **No Odoo upgrade is promoted to production without full UAT PASS and rollback validation.**

---

## Incident Handling (Reference)

If an update causes instability:

1. Roll back to previous tagged release
2. Restore database if required
3. Document root cause
4. Re-run UAT before re-attempt

---

## Document Control

- This runbook is authoritative
- Changes require peer review
- Exceptions are not allowed without written approval

---

**Status:** Active  
**Applies to:** Staging and Production
