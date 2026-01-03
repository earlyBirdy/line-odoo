> **Note:** This document is kept for reference. For the canonical sequential runbook, use `docs/RUNBOOK.md`.

# Local E2E Test Steps (LINE → Backend → Odoo)

This guide validates the full workflow locally:

- Rich Menu / Postback → Backend webhook
- Multi-step conversation state machine
- Create `waste.pickup.request` and `waste.pickup.change.request`
- Staff applies change request in Odoo
- (Optional) Push status back to LINE

> Safe note: Run locally against a **demo database**. Do NOT point this at the customer production DB.

---

## 1) Start services

### Option A — Demo Odoo (recommended)

From repo root:

```bash
docker compose -f docker-compose.odoo-demo.yml down -v --remove-orphans
docker compose -f docker-compose.odoo-demo.yml up -d
docker compose -f docker-compose.odoo-demo.yml logs -f odoo
```

Open Odoo: `http://localhost:8069`

**First time only**: create a database in the UI (Database Manager) and remember:
- DB name (example: `odoo`)
- admin email + password

### Option B — Full stack (backend + redis + nginx + odoo)

```bash
docker compose down -v --remove-orphans
docker compose up -d
docker compose logs -f backend
```

---

## 2) Configure backend env

Copy and edit environment variables:

```bash
cp .env.example .env
```

Minimum required:

- `ODOO_URL=http://localhost:8069`
- `ODOO_DB=odoo`
- `ODOO_USERNAME=admin@example.com` (your demo DB admin)
- `ODOO_PASSWORD=...`
- `LINE_CHANNEL_SECRET=...` (optional for local simulation)
- `LINE_CHANNEL_ACCESS_TOKEN=...` (optional unless you want to push messages)

If backend is run with Docker Compose, edit the `backend` service env in `docker-compose.yml` instead (or use `.env` if compose loads it).

---

## 3) Start backend (if not using compose)

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Health checks:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/line/health
curl http://127.0.0.1:8000/odoo/health
```

Expected:
- `/health` → `{ "ok": true, ... }`
- `/odoo/health` → `{ "ok": true, "uid": ..., "installed_modules": ... }`

If `/odoo/health` returns 503, verify Odoo is reachable and your Odoo credentials / DB name are correct.

---

## 4) Install the Odoo addon (waste_pickup_request)

In Odoo UI:
1. Enable developer mode (append `?debug=1` in URL)
2. Apps → **Update Apps List**
3. Search: `waste_pickup_request`
4. Install

---

## 5) Simulate LINE events locally (no real LINE needed)

### 5.1 Trigger “Schedule Pickup” (postback)

```bash
curl -X POST http://127.0.0.1:8000/line/webhook   -H "Content-Type: application/json"   -d '{
    "events":[
      {
        "type":"postback",
        "replyToken":"DUMMY",
        "source":{"type":"user","userId":"U_test_001"},
        "postback":{"data":"action=schedule_pickup"}
      }
    ]
  }'
```

### 5.2 Continue the multi-step flow (message inputs)

Send a message event:

```bash
curl -X POST http://127.0.0.1:8000/line/webhook   -H "Content-Type: application/json"   -d '{
    "events":[
      {
        "type":"message",
        "replyToken":"DUMMY",
        "source":{"type":"user","userId":"U_test_001"},
        "message":{"type":"text","text":"2026-01-02 10:00"}
      }
    ]
  }'
```

> Use values that match your state machine prompts (date/time, address, phone, etc).

---

## 6) Verify records in Odoo

### 6.1 Pickup Request

In Odoo, open the menu for pickup requests and confirm:
- a record exists for the LINE user
- requested date/time and address fields are populated
- status is correct

### 6.2 Change Request

Trigger cancel/reschedule/note via LINE flow, then confirm:
- a `waste.pickup.change.request` record exists
- it links to the original pickup request
- its state is `new` before staff applies

---

## 7) Staff applies the Change Request (Odoo)

Open the change request form and click **Apply**.

Expected:
- Original pickup request is updated (cancelled / rescheduled / note added)
- Change request state becomes `applied` / `done` (depending on implementation)

---

## 8) Optional: push status back to LINE

If `LINE_CHANNEL_ACCESS_TOKEN` is set, backend may push messages.

You can also trigger status push manually if supported:

```bash
curl -X POST http://127.0.0.1:8000/odoo/status_update   -H "Content-Type: application/json"   -d '{"line_user_id":"U_test_001","status":"confirmed","note":"Driver scheduled"}'
```

---

## Troubleshooting

- **`{"detail":"Not Found"}`** on an endpoint: confirm the route exists in `backend/app/main.py` and you’re hitting the right port.
- **Odoo says “Database not initialized”**: create the DB in the UI (Database Manager) and restart.
- **Odoo addon install fails**: check `odoo` container logs; verify the addon path `/mnt/extra-addons` is mounted and module name matches folder.
- **LINE signature validation blocks local tests**: use the simulation flow; in local mode you can disable signature verification (see README / env flag if provided).

