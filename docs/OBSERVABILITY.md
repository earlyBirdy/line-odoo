# Observability (Health, Logs, Alerts)

Last updated: 2026-01-03

---

## 1) Health endpoints

Backend:
- `GET /health` → basic service status/version
- `GET /line/health` → alias
- `GET /odoo/health` → validates backend → Odoo JSON-RPC auth + lightweight query

Recommended (prod):
- expose `/health` only internally (ALB health check)
- protect `/odoo/health` (internal only), because it touches Odoo auth

---

## 2) Logging

### 2.1 Backend logging (recommended format)

Use structured logs where possible (JSON lines), including:
- `ts` (ISO8601)
- `level` (INFO/WARN/ERROR)
- `request_id` (from header or generated)
- `path`, `method`
- `line_event_type`
- `odoo_latency_ms`
- `status_code`

### 2.2 What to log (minimum)

- Signature verification pass/fail (do **not** log secrets)
- Outbound LINE API call success/failure + latency
- Odoo auth failures and JSON-RPC errors
- Redis connection errors

---

## 3) Alert triggers (baseline)

### Backend (FastAPI)
- 5xx rate > 1% for 5 minutes
- p95 latency > 1s for 5 minutes
- `/health` failing for 2 consecutive checks

### Odoo
- error spikes (HTTP 5xx)
- p95 latency > 2s
- DB connection errors

### Database (RDS)
- CPU > 80% for 10 minutes
- Free storage < 20%
- Deadlocks / lock waits increasing

### Redis (ElastiCache)
- memory > 80%
- evictions increasing
- connection errors

---

## 4) Dashboards

Recommended CloudWatch dashboards:
- ALB: request count, target 5xx, target response time
- ECS/EC2: CPU/memory, restarts
- RDS: connections, CPU, read/write latency
- ElastiCache: evictions, memory usage, CPU

