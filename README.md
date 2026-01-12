# GoodCan – LINE OA × Odoo「安排取貨」Starter

- LINE Rich Menu「安排取貨」→ 多步驟對話收集資料
- Backend 驗簽/去重/狀態機（Redis）→ JSON-RPC 建立 Odoo 取貨需求單
- Odoo 後台：Discuss Inbox 通知 + Activity 待辦
- 內勤人工聯絡客戶、人工排到行事曆/取貨計劃（既有模組）

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

---

### LINE × Odoo Pickup Integration (STAGING) ###

## Purpose
This repository is a **staging / rehearsal environment** before official production rollout.

It validates the **end-to-end flow**: LINE user → Backend API → Odoo (Community 18)

No live customer data should ever be used here.

---

## Architecture

```
LINE OA
  → Nginx
   → Webhook (FastAPI)
    → Validation / State Machine (Redis)
     → Odoo JSON-RPC
      → Odoo Staging DB (Postgres)
```

Nginx fronts the stack for **local demo and production parity**.

---

## Environments

| Layer | Value |
|-------|-------|
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

### One-time setup
```bash
./scripts/setup_dev_env.sh
```

### Start full stack
```bash
docker compose -f docker-compose.odoo-demo.yml up -d --build
```

### Odoo DB initialization (once per machine)
```bash
docker compose stop odoo

docker compose run --rm odoo odoo   --db_host=db --db_port=5432   --db_user=odoo --db_password=odoo   -d odoo_staging -i base --stop-after-init

docker compose up -d odoo
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


```bash
curl http://127.0.0.1/health              # nginx entrypoint
curl http://127.0.0.1/api/health          # expected 404 (no /api prefix)
curl http://127.0.0.1/odoo/health         # expected redirect (Odoo UI)
curl http://127.0.0.1:8000/health         # backend health (authoritative)
curl http://127.0.0.1:8000/odoo/health    # backend → Odoo health (authoritative)
```

> **Note:** `404` or `Redirect` responses from Nginx-level endpoints are expected; only the backend endpoints on port `8000` are authoritative for system health.

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

---

## Real LINE Webhook (Staging)

LINE requires **HTTPS**. Localhost is not allowed.

### Expose nginx using ngrok
```bash
ngrok http 80
```

You will get:
```
https://xxxx.ngrok-free.app
```

### LINE Developers Console
- Webhook URL:
  ```
  https://xxxx.ngrok-free.app/line/webhook
  ```
- Use webhook: ✅ ON
- Auto-reply: ❌ OFF
- Greeting message: ❌ OFF

### Validation
```bash
curl -i https://xxxx.ngrok-free.app/line/webhook
```
Expected:
```
405 Method Not Allowed
Allow: POST
```

This confirms routing is correct.

---

## End-to-End Test Plan (Staging)

### Phase 0 — Preconditions
- All containers running
- All health checks green

### Phase 1 — Odoo readiness
- Login to http://localhost/odoo
- DB: `odoo_staging`
- LINE Integration module installed

### Phase 2 — Backend sanity
```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/odoo/health
docker compose exec redis redis-cli ping
```

### Phase 3 — LINE webhook simulation
```bash
curl -X POST http://127.0.0.1/line/webhook   -H "Content-Type: application/json"   -H "X-Line-Signature: test"   -d '{"events":[{"type":"message","replyToken":"dummy","source":{"userId":"Utest"},"message":{"type":"text","text":"安排取貨"}}]}'
```

### Phase 4 — Pickup creation
- Complete flow via LINE
- Verify pickup in Odoo

### Phase 5 — Staff change request
- Apply cancel/reschedule
- Verify pickup updated

### Phase 6 — Failure paths
- Odoo down → backend degrades gracefully
- Duplicate LINE event → no duplicate pickup

---

### UAT execution (MANDATORY before prod)

The Excel file defines **UAT Test Cases**.
You must now **execute them**.

For each UAT case:
- Send real LINE message
- Observe backend logs
- Verify Odoo record
- Fill:
  - Actual Result
  - Pass / Fail
  - Tester
  - Evidence

### Required additions to UAT

Add **failure & edge cases**:
- Duplicate LINE event
- LINE retry
- Odoo unavailable
- Redis unavailable
- Invalid user input
- Partial staff action

---

## Project Tracking Improvements (Required)

Update the estimator with:

### 1. Status column
```
Not Started | In Progress | Blocked | Done
```

### 2. Acceptance Criteria column
Example:
> Pickup record created in Odoo within 5 seconds, no duplicate under retry.

---

## Operational Readiness (New Sheet Required)

Add an **Operational Readiness** sheet with:

- Backup tested
- Restore tested
- Secret rotation procedure
- Incident escalation path
- Rollback procedure
- Owner per item

---

## Go / No-Go Rule

Production is allowed **only if**:
- All UAT cases = PASS
- Failure cases tested
- Ops readiness sheet complete
- Business owner sign-off

---

## Common local errors (and how to fix them)

This section documents **known, expected local development errors** and their exact fixes.
If you hit one of these, it is **not a repo bug**.

---

### ❌ `ModuleNotFoundError: No module named 'app'`

**Symptom**
```text
ModuleNotFoundError: No module named 'app'
```

**Cause**
You ran `uvicorn app.main:app` from the **repo root**.
The backend code lives under `backend/app/`.

**Fix (recommended)**
```bash
cd backend
uvicorn app.main:app --reload --port 8000
```

**Alternative**
```bash
PYTHONPATH=backend uvicorn app.main:app --reload --port 8000
```

---

### ❌ `Address already in use` when running `odoo --stop-after-init`

**Symptom**
```text
OSError: [Errno 98] Address already in use
```

**Cause**
The Odoo container is already running and bound to port `8069`.

**Fix (safe)**
```bash
docker compose stop odoo

docker compose run --rm odoo odoo   --db_host=db --db_port=5432   --db_user=odoo --db_password=odoo   -d odoo_staging -i base --stop-after-init

docker compose up -d odoo
```

---

### ❌ Backend `/odoo/health` fails with `Failed to resolve 'odoo'`

**Symptom**
```json
{"detail":"Failed to resolve 'odoo'"}
```

**Cause**
Backend started before Odoo was healthy, or wrong base URL was used.

**Fix**
- Use service DNS name: `http://odoo:8069`
- Use the provided `docker-compose.odoo-demo.yml`
- Let backend wait for Odoo health

```yaml
environment:
  ODOO_BASE_URL: http://odoo:8069
depends_on:
  odoo:
    condition: service_healthy
```

---

### ❌ `npm run dev` / missing `package.json`

**Symptom**
```text
Could not read package.json
```

**Cause**
This repository has **no frontend**.
It is a backend + Odoo + Nginx stack.

**Fix**
Do not use npm here.
Use one of:

```bash
# Full stack
docker compose up -d --build

# Backend only
cd backend
uvicorn app.main:app --reload --port 8000
```

---

### ❌ `/health` works but `/odoo/health` fails

**Cause**
Odoo DB not initialized yet.

**Fix**
Initialize DB once:

```bash
docker compose stop odoo
docker compose run --rm odoo odoo   --db_host=db --db_user=odoo --db_password=odoo   -d odoo_staging -i base --stop-after-init
docker compose up -d odoo
```

---

### ❌ LINE webhook not triggered

**Checklist**
- Webhook URL set to:
  ```
  https://<YOUR_DOMAIN>/line/webhook
  ```
- Channel secret/token match `.env`
- Nginx is reachable from public internet
- Signature verification enabled

---

If you encounter an error **not listed here**, capture:
- command
- full stack trace
- container logs

and add it to this section.
