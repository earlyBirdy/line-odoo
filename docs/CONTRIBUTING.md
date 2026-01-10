# Contributing Guide

Thank you for contributing to **GoodCan – LINE OA × Odoo Platform**.
This document defines **how to work safely, consistently, and audit‑ready** in this repository.

This repo is a **backend + Odoo + infra** stack (no frontend).

---

## 1. Repository principles

- **No production data** in this repo (staging / rehearsal only)
- **Infrastructure is code** (Terraform-first mindset)
- **Security by default**
  - No long‑lived AWS keys
  - OIDC for CI/CD
- **Docker is the source of truth**
  - Local dev should mirror prod topology

---

## 2. Prerequisites

### Required
- Docker Desktop
- Docker Compose v2
- Python 3.11+
- `curl`

### Optional (infra work)
- Terraform ≥ 1.6
- AWS CLI (OIDC-based, no static keys)

---

## 3. Local development workflow (canonical)

### 3.1 One-time setup
```bash
./scripts/setup_dev_env.sh
```

This:
- Creates `.env` and `backend/.env`
- Prevents accidental secret commits

### 3.2 Start full stack
```bash
docker compose -f docker-compose.odoo-demo.yml up -d --build
```

### 3.3 Initialize Odoo DB (first run only)
```bash
docker compose stop odoo

docker compose run --rm odoo odoo   --db_host=db --db_port=5432   --db_user=odoo --db_password=odoo   -d odoo_staging -i base --stop-after-init

docker compose up -d odoo
```

### 3.4 Health verification
```bash
curl http://127.0.0.1/health
curl http://127.0.0.1/api/health
curl http://127.0.0.1/odoo/health
```

All must return `{ "ok": true }`.

---

## 4. Backend-only development

If you only need the API:

```bash
cd backend
uvicorn app.main:app --reload --port 8000
```

⚠️ Always run from `backend/`, not repo root.

---

## 5. Branching & commits

### Branches
- `main` → protected, deployable
- `feature/*` → new functionality
- `fix/*` → bug fixes
- `infra/*` → Terraform / ops changes
- `docs/*` → documentation only

### Commit style
- Clear, imperative messages:
  - `fix: wait for odoo health before backend`
  - `infra: add waf logging redaction`
  - `docs: add common local errors section`

---

## 6. Pull request checklist

Before opening a PR, ensure:

- [ ] `docker compose up -d --build` works locally
- [ ] Health checks pass
- [ ] No secrets committed
- [ ] README / docs updated if behavior changed
- [ ] Terraform changes include plan output (if applicable)

---

## 7. CI / CD expectations

### CI (GitHub Actions)
- Runs lint & smoke tests
- Builds Docker images
- Fails fast on errors

### Terraform
- `terraform plan` runs on PR
- `terraform apply` only runs on `main`
- Uses **GitHub OIDC** (no AWS keys)

Never commit:
- `.env`
- AWS credentials
- Terraform state files

---

## 8. Infrastructure changes (Terraform)

Location:
```
terraform/
├─ modules/
└─ envs/
   ├─ dev/
   ├─ stg/
   └─ prod/
```

Rules:
- One logical change per PR
- Do not mix infra + app logic unless required
- Prod changes require peer review

---

## 9. Odoo development rules

- Custom logic must live in `odoo/addons/`
- Do not modify core Odoo images directly
- Always document:
  - data models
  - access rights
  - upgrade impact

---

## 10. Security rules (non‑negotiable)

- No secrets in git history
- Use minimal Odoo permissions
- Never bypass signature verification
- Webhooks must remain idempotent

Violations will block PRs.

---

## 11. Common mistakes (read before asking)

See:
```
README.md → Common local errors
```

Most onboarding issues are documented there.

---

## 12. When in doubt

If you are unsure:
- open a draft PR
- describe the concern clearly
- include logs / error messages

This repo values **operational safety over speed**.

---

Happy shipping 🚀
