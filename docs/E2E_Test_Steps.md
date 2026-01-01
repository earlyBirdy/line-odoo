# E2E Test Steps (Local / Staging)

## 1. Infra Check
- Odoo UI accessible at http://localhost:8069
- Backend running at http://127.0.0.1:8000

## 2. Backend Health
```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/odoo/health
```

## 3. LINE → Pickup Creation
1. Tap Rich Menu: Arrange Pickup
2. Complete guided steps (no free text)
3. Confirm

Expected:
- waste.pickup.request created
- state = new
- source = LINE

## 4. LINE → Change Request
1. Tap My Pickups
2. Select pickup
3. Choose cancel / reschedule / note

Expected:
- waste.pickup.change.request created
- linked to pickup
- state = new

## 5. Odoo Staff
1. Open Pickup / Change Request list
2. Apply change

Expected:
- pickup updated
- change request marked applied

## 6. Go / No-Go
All above must pass before UAT / production.