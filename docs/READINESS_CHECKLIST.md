# Readiness Checklist

Last updated: 2026-01-03

Use this checklist before moving from **Dev → Staging → Prod**.

---

## 1) Repo hygiene

- [ ] No secrets committed (scan passed)
- [ ] `.env` and `backend/.env` are gitignored
- [ ] No virtualenv/large artifacts committed (e.g. `backend/.venv`)

---

## 2) Dev readiness

- [ ] `docker compose up -d --build` works cleanly
- [ ] `/health` returns ok
- [ ] `/odoo/health` passes after Odoo is initialized
- [ ] Basic LINE webhook receives events (via tunnel)

---

## 3) Staging readiness

- [ ] Secrets in Secrets Manager/SSM (not in files)
- [ ] TLS enabled (staging cert ok)
- [ ] E2E test suite executed (docs)
- [ ] Rollback plan written and rehearsed
- [ ] Backups enabled for DB + filestore

---

## 4) Production readiness

- [ ] ALB health checks configured
- [ ] CloudWatch dashboards and alarms configured
- [ ] RDS backups + snapshot before migrations
- [ ] ElastiCache sized and monitored
- [ ] Rate limiting / WAF considered for webhook endpoints
- [ ] Incident playbooks accessible and owners assigned

---

## 5) Operational readiness

- [ ] Credential inventory completed with owners + rotation dates (`docs/CREDENTIALS_ACCESS.md`)
- [ ] Backup/restore drill performed (`docs/BACKUP_RESTORE.md`)
- [ ] On-call contact + escalation path defined
