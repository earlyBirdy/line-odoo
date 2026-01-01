## v0.2.6
- Add `/odoo/health` endpoint for backend→Odoo connectivity checks.
- Add `docs/LOCAL_E2E_TESTS.md` local end-to-end test guide.
- README links to local E2E guide.

# Changelog

## v0.1.4
- `action=my_pickups` now returns a Flex carousel (up to 5 items) with buttons.
- Added `docs/flex_my_pickups_example.json`.
- Added Odoo security group `LINE Integration` + record rule + access rights.

## v0.1.5
- my_pickups Flex cards now include "查看詳情" button (postback: action=pickup_detail&id=<odoo_id>).
- Added pickup_detail endpoint behavior in backend: Odoo search_read with ownership check (line_user_id match).
- Added MVP guidance flows for cancel/reschedule (text prompts).
- Added `docs/flex_pickup_detail_example.json`.

## v0.2.0
- Added Odoo model `waste.pickup.change.request` with Apply/Reject.
- LINE cancel/reschedule now uses guided state machine and creates change requests in Odoo.
- Added views/menu + security for change requests.
- Added docs: `docs/change_request_flow.md`.

## v0.2.1
- Fixed Odoo addon __manifest__.py (valid dict literal for ast.literal_eval).
- Added docker-compose.odoo-demo.yml (avoids pre-creating an empty 'odoo' DB).

## v0.2.2
- Fixed docker-compose.odoo-demo.yml: set POSTGRES_DB=postgres to avoid creating blank 'odoo' DB (prevents /web/database/manager 500).
- Added docs/local_verification_quickfix.md.

## v0.2.3
- Odoo 18 compatibility fix: replaced deprecated <tree> with <list> in views.
  - odoo/addons/waste_pickup_request/views/pickup_request_views.xml
  - odoo/addons/waste_pickup_request/views/pickup_change_request_views.xml
  - odoo/addons/waste_pickup_request/__manifest__.py

## v0.2.4
- Odoo 17+ view fix: replaced deprecated attrs/states with modifiers in pickup_change_request_views.xml
  - odoo/addons/waste_pickup_request/views/pickup_change_request_views.xml
  - odoo/addons/waste_pickup_request/__manifest__.py

## v0.2.5
- Fully removed remaining attrs in pickup_change_request_views.xml (Odoo 18 compliance)
