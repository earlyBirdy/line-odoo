# Credentials & Access Inventory

Last updated: 2026-01-03

This document lists **all credential types** used by this system, where they should live per environment, rotation guidance, and owners.

> This repo should **never** contain real secrets. Store real secrets in **AWS Secrets Manager / SSM** (staging/prod) and local `.env` files (dev only).

---

## 1) Inventory Table

| Credential / Secret | Used by | Environment(s) | Storage (Dev) | Storage (Staging/Prod) | Rotation | Owner | Notes |
|---|---|---|---|---|---|---|---|
| `LINE_CHANNEL_SECRET` | backend | dev/stg/prod | `backend/.env` | Secrets Manager | 90d or on staff change | App owner | Used to verify `X-Line-Signature` |
| `LINE_CHANNEL_ACCESS_TOKEN` | backend | dev/stg/prod | `backend/.env` | Secrets Manager | 90d | App owner | Used for LINE push/reply API |
| `ODOO_URL` | backend | dev/stg/prod | `backend/.env` | SSM/Secrets | n/a | App owner | e.g. `http://odoo:8069` (dev) |
| `ODOO_DB` | backend | dev/stg/prod | `backend/.env` | SSM/Secrets | n/a | App owner | Odoo database name |
| `ODOO_USERNAME` | backend | dev/stg/prod | `backend/.env` | Secrets Manager | 180d | Odoo admin | Dedicated service account |
| `ODOO_PASSWORD` | backend | dev/stg/prod | `backend/.env` | Secrets Manager | 180d | Odoo admin | Least privilege user |
| `ODOO_CALLBACK_SECRET` | backend + any caller | dev/stg/prod | `.env` or `backend/.env` | Secrets Manager | 90d | App owner | Protects `/odoo/status_update` |
| `POSTGRES_DB` | odoo + db | dev | `.env` | RDS config | n/a | Infra | For prod, DB is provisioned in RDS |
| `POSTGRES_USER` | odoo + db | dev | `.env` | Secrets Manager | 180d | Infra | Prefer separate app user |
| `POSTGRES_PASSWORD` | odoo + db | dev | `.env` | Secrets Manager | 180d | Infra | Strong random password |
| Redis auth (if enabled) | backend | stg/prod | n/a | Secrets Manager | 180d | Infra | ElastiCache auth token optional |
| TLS cert/private key | nginx/ALB | stg/prod | local self-signed ok | ACM (preferred) | yearly | Infra/Sec | Prefer ALB+ACM to avoid key files |
| AWS deploy credentials | CI/CD | stg/prod | n/a | IAM role/OIDC | rotate keys if used | Infra | Prefer no static keys |
| Admin accounts (Odoo UI) | humans | all | password mgr | password mgr + SSO | 90d | Odoo admin | Enable MFA where possible |

---

## 2) Access control rules (baseline)

- **Dev**: local `.env` files only (never committed)
- **Staging/Prod**:
  - Use IAM roles for compute
  - Store secrets in Secrets Manager
  - Grant least-privilege access per service
- Dedicated Odoo service user for backend integration (do not use admin)

---

## 3) How to rotate (quick guide)

1) Rotate secret in Secrets Manager
2) Redeploy service (ECS task definition revision or EC2 redeploy)
3) Verify:
   - `/health`
   - `/odoo/health`
   - Send test message to LINE bot
4) Update this inventory table (date + owner)

