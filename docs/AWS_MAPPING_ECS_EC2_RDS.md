# AWS 1:1 Mapping (ECS / EC2 / RDS)

Last updated: 2026-01-03

This document maps the local `docker-compose.yml` topology to AWS production architectures.

---

## 1) Local compose → AWS components

| Compose service | Role | AWS (recommended) | AWS (alternative) |
|---|---|---|---|
| `nginx` | reverse proxy / routing | **ALB** (preferred) + optional Nginx | Nginx on EC2 |
| `backend` | FastAPI webhook | ECS Fargate service | EC2 container |
| `odoo` | Odoo app server | ECS Fargate service | EC2 container |
| `db` (postgres) | database | **RDS Postgres** | Postgres on EC2 (not recommended) |
| `redis` | cache/session store | **ElastiCache Redis** | Redis on EC2 |

---

## 2) Option A — ECS Fargate (recommended)

### 2.1 Networking
- VPC with public + private subnets
- ALB in public subnets
- ECS tasks in private subnets
- NAT gateway for outbound access (if needed)

### 2.2 Load balancer routing
ALB listener rules:
- `/line/webhook` → backend target group
- `/webhook` → backend target group (alias)
- `/odoo/*` or `/` → odoo target group

Health checks:
- backend: `/health`
- odoo: `/web/login` (or a dedicated lightweight route if added)

### 2.3 Data services
- RDS Postgres (Multi-AZ)
- ElastiCache Redis (Multi-AZ where possible)

### 2.4 Secrets & config
- Secrets Manager for sensitive values
- SSM Parameter Store for non-secret config
- Inject env vars into ECS task definitions

### 2.5 Image pipeline
- ECR repos:
  - `line-odoo-backend`
  - `line-odoo-odoo`
  - (optional) `line-odoo-nginx`

Tagging recommendation:
- `:staging-YYYYMMDD-<gitsha>`
- `:prod-YYYYMMDD-<gitsha>`

---

## 3) Option B — EC2 (docker compose)

### 3.1 What you run on the instance
- Same docker images as local compose
- Use **RDS** and **ElastiCache** (do not host DB on EC2)

### 3.2 Pros/cons
- ✅ easy to understand
- ❌ manual scaling, patching, failover

---

## 4) Migration / Cutover

1) Provision RDS + ElastiCache
2) Deploy staging using the same resources class as prod
3) Import / initialize Odoo DB + filestore (see `docs/BACKUP_RESTORE.md`)
4) Verify E2E in staging
5) Switch DNS to ALB
6) Monitor error rate and latency

