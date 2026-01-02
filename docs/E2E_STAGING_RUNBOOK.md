# E2E STAGING RUNBOOK
LINE ↔ Backend (FastAPI) ↔ Odoo (Community 18, AWS)

This document is the **single source of truth** for validating the LINE × Odoo integration
in **STAGING** before any production cutover.

---

## 0. Scope & Rules

- Environment: **STAGING ONLY**
- Odoo Edition: Community 18
- Database: `odoo_staging` (⚠️ NEVER production)
- LINE users interact only via **Rich Menu / guided flows**
- No free-text critical inputs
- Kill-switch must be available at all times

---

## 1. Architecture Overview

**Flow**
1. LINE Rich Menu → Webhook
2. Backend (FastAPI)
3. Odoo JSON-RPC
4. Odoo Staff Manual Action

**Key Models**
- `waste.pickup.request`
- `waste.pickup.change.request`

---

## 2. Local Infrastructure Setup

### 2.1 Start Services

```bash
docker compose -f docker-compose.odoo-demo.yml up -d
```

### 2.2 Start Backend

```bash
uvicorn app.main:app --reload --port 8000
```

---

## 3. Health Checks

### 3.1 Backend

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/line/health
```

Expected:
```json
{"ok": true}
```

### 3.2 Odoo Connectivity

```bash
curl http://127.0.0.1:8000/odoo/health
```

Expected:
```json
{
  "ok": true,
  "db": "odoo_staging"
}
```

---

## 4. E2E Functional Tests

### 4.1 Create Pickup (LINE → Odoo)

**Steps**
1. User clicks LINE Rich Menu → Arrange Pickup
2. Backend creates `waste.pickup.request`
3. Odoo record appears in Pickup list

---

### 4.2 Change Request (Cancel / Reschedule / Note)

**Steps**
1. User selects `My Pickups`
2. Chooses a pickup
3. Selects Cancel / Reschedule / Note

---

### 4.3 Staff Action in Odoo

**Steps**
1. Staff opens Change Request
2. Clicks `Apply`
3. Original pickup updated

---

## 5. Negative & Edge Cases

| Case | Expected |
|----|----|
| Duplicate request | Rejected |
| Invalid state | Blocked |
| Apply twice | No-op |
| Backend down | LINE safe reply |

---

## 6. UAT Sign-Off Matrix

| Area | Owner | Status | Date |
|----|----|----|----|
| LINE UX | Customer | ☐ | |
| Backend | SI | ☐ | |
| Odoo Data | Customer | ☐ | |
| Security | Customer IT | ☐ | |

---

## 7. Production Cutover Checklist

- ☐ All UAT signed
- ☐ Kill-switch tested
- ☐ Backup confirmed
- ☐ Webhook switched
- ☐ First pickup verified

---

## 8. Rollback / Kill-Switch Plan

- Disable LINE webhook
- Set `LINE_ENABLED=false`
- Restore DB snapshot if needed

---

## 9. Final Notes

This document **replaces all previous E2E / LOCAL test docs**.
