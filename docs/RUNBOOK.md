# Runbook (Dev → Staging → Prod)

Last updated: 2026-01-03

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
