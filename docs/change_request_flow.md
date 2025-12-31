# Change Request Flow (Cancel / Reschedule / Note)

## What we add
- New Odoo model: `waste.pickup.change.request`
- LINE guided conversation (state machine) that creates a change request record
- Odoo staff processes CR from menu and clicks **Apply to Pickup**

## LINE (user)
Triggered from Pickup Detail:
- Cancel → `action=pickup_cancel&id=<pickup_id>`
- Reschedule → `action=pickup_reschedule&id=<pickup_id>`

Conversation steps:
- Reschedule: new time → reason → note → OK confirm
- Cancel: reason → note → OK confirm
User can type `cancel` any time to abort.

## Backend
Creates Odoo record via JSON-RPC:
- `pickup_id`, `change_type`, `requested_time` (reschedule), `reason`, `note`, `line_user_id`, `source=line`

## Odoo (staff)
Menu: Waste Management → Pickup Change Requests
- New CR appears in list (state=new)
- Open CR → click **Apply to Pickup**
  - Cancel: pickup.state=cancel and append note
  - Reschedule: update pickup.preferred_time and append note
  - Note: append note
