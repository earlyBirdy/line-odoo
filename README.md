# GoodCan – LINE OA × Odoo「安排取貨」MVP Starter

- LINE Rich Menu「安排取貨」→ 多步驟對話收集資料
- Backend 驗簽/去重/狀態機（Redis）→ JSON-RPC 建立 Odoo 取貨需求單
- Odoo 後台：Discuss Inbox 通知 + Activity 待辦
- 內勤人工聯絡客戶、人工排到行事曆/取貨計劃（你們既有模組）

## Docs
- `docs/sequence_diagram.md`
- `docs/rich_menu_postbacks.md`
- `docs/data_dictionary.md`

## Local demo stack
```bash
cp .env.example .env
cp backend/.env.example backend/.env
docker compose up -d --build
```
- Odoo: http://localhost/
- Backend: http://localhost/line/health


## LINE Webhook URL
- Set in LINE Developers Console:
  - `https://<YOUR_DOMAIN>/line/webhook`
- Backend supports both `/webhook` and `/line/webhook` (alias), so Nginx may rewrite or not.


## Rich Menu actions
- `action=pickup_start` (MVP)
- `action=contact` (stub)
- `action=my_pickups` (lists latest 5)


## Nginx rate limit
- `/line/webhook` 已加上 rate limit（10 req/sec per IP, burst 20）。

## Odoo integration user (minimal rights)
建議建立專用使用者（例如：`line_bot_api`），並加入群組：
- **LINE Integration**（本模組提供）

這個群組僅允許對 `waste.pickup.request`：read/create/write（不允許刪除）。


## Detail actions
- From my_pickups Flex card: `action=pickup_detail&id=<odoo_id>`
- Change-request (MVP text guide): `action=pickup_reschedule&id=<odoo_id>`, `action=pickup_cancel&id=<odoo_id>`


## Change requests
- Odoo: `waste.pickup.change.request` (cancel/reschedule/note)
- LINE guided flow creates CR; staff processes in Odoo and clicks **Apply to Pickup**.


## Local E2E Tests

See `docs/LOCAL_E2E_TESTS.md`.


### LINE × Odoo Pickup Integration (STAGING) ###

## Purpose
This repository is a **staging / rehearsal environment** before official production rollout.

It validates the **end-to-end flow**:
LINE user → Backend API → Odoo (Community 18)

No live customer data should ever be used here.

---

## Architecture
LINE OA
→ Webhook (FastAPI)
→ Business Logic / Validation
→ Odoo JSON-RPC
→ Odoo Staging Database (`odoo_staging`)

---

## Environments

| Layer | Value |
|------|------|
| Backend | FastAPI (localhost:8000) |
| Odoo | Community 18 (Docker) |
| DB | PostgreSQL (`odoo_staging`) |
| LINE | Sandbox / Test OA |

---

## Quick Start

### Start Odoo + DB
```bash
docker compose -f docker-compose.odoo-demo.yml up -d
```

### Initialize staging DB (once)
```bash
docker compose exec db createdb -U odoo odoo_staging
docker compose exec odoo odoo \
  --db_host=db --db_port=5432 \
  --db_user=odoo --db_password=odoo \
  -d odoo_staging -i base --stop-after-init
docker compose restart odoo
```

### Start Backend
```bash
cd backend
uvicorn app.main:app --reload --port 8000
```

---

## Health Checks
```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/line/health
curl http://127.0.0.1:8000/odoo/health
```

Expected:
```json
{"ok":true,"db":"odoo_staging"}
```

---

## Supported Flows
- Arrange Pickup
- View My Pickups
- Cancel / Reschedule / Add Note
- Odoo staff manual apply

## Operations docs

- Runbook (Dev → Staging → Prod): `docs/RUNBOOK.md`
- Architecture: `docs/ARCHITECTURE.md`
- Credentials & Access: `docs/CREDENTIALS_ACCESS.md`
- Observability: `docs/OBSERVABILITY.md`
- Backup & Restore: `docs/BACKUP_RESTORE.md`
- Incident Playbooks: `docs/INCIDENT_PLAYBOOKS.md`
- AWS Mapping (ECS/EC2/RDS): `docs/AWS_MAPPING_ECS_EC2_RDS.md`
- Readiness Checklist: `docs/READINESS_CHECKLIST.md`


## Quick start (dev)

```bash
./scripts/setup_dev_env.sh
docker compose up -d --build
curl -s http://127.0.0.1/health
```


## Infrastructure (Terraform-ready)
See `docs/TERRAFORM_RESOURCES.md` for a deployable resource inventory (names, tags, SG rules, IAM policies).
