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
