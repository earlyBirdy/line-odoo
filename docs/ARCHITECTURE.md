# System Architecture

Last updated: 2026-01-03

This document is the single source of truth for architecture, request flow, trust boundaries, and failure modes.

---

## 1) Components

- **LINE Platform**: sends webhook events and receives push/reply API calls
- **Nginx**: reverse proxy (local/dev) or replaced by **AWS ALB** (prod)
- **Backend (FastAPI)**: `backend/app/main.py`
- **Odoo**: `odoo` container + custom addons in `odoo/addons`
- **Postgres**: local container (dev) or **RDS Postgres** (prod)
- **Redis**: local container (dev) or **ElastiCache Redis** (prod)

---

## 2) Request flow (happy path)

### 2.1 LINE inbound webhook

1) User sends a message to LINE bot
2) LINE calls: `POST /line/webhook` (through Nginx/ALB)
3) Backend verifies signature:
   - Header: `X-Line-Signature`
   - Secret: `LINE_CHANNEL_SECRET`
4) Backend processes event:
   - May read/write state to Redis (conversation/session)
   - May call Odoo JSON-RPC for business data
5) Backend responds to LINE (reply) or sends push messages:
   - Uses `LINE_CHANNEL_ACCESS_TOKEN`

### 2.2 Odoo → Backend callback

1) Odoo (or automation) calls: `POST /odoo/status_update`
2) Backend validates `ODOO_CALLBACK_SECRET`
3) Backend pushes notification to LINE user(s)

---

## 3) Trust boundaries

### External boundary
- Internet ↔ (ALB/Nginx) ↔ backend
- Only allow inbound routes that are needed:
  - `/line/webhook`
  - `/health` (restricted in prod)
  - `/odoo/status_update` (restrict by secret and optionally IP allow-list)

### Secrets boundary
- Secrets never in code
- Dev: `.env` files
- Prod: Secrets Manager + IAM role access only

---

## 4) Failure paths & expected behavior

### LINE platform outage
- Webhook delivery may stop or retry
- Backend should:
  - remain healthy
  - log failures calling LINE APIs
  - provide degraded UI messaging if needed

### Odoo unreachable / auth failure
- `/odoo/health` returns `ok:false` (or error details)
- Backend should:
  - fail gracefully for user requests requiring Odoo data
  - provide fallback message

### DB locked / Postgres slow
- Odoo errors increase, latency spikes
- Mitigation:
  - check long-running transactions
  - scale read replicas (if applicable)
  - restore from snapshot if corruption

### Redis down
- Conversation state lost (depending on TTL usage)
- Backend should:
  - continue basic webhook processing
  - fall back to stateless behavior where possible

---

## 5) Interfaces

- Backend health: `GET /health`
- LINE health alias: `GET /line/health`
- Backend → Odoo connectivity: `GET /odoo/health`
- Webhooks:
  - `POST /line/webhook`
  - `POST /webhook` (alias)
- Odoo callback:
  - `POST /odoo/status_update`

See also:
- `docs/data_dictionary.md`
- `docs/sequence_diagram.md`

