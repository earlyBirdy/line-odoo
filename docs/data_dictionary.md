## Odoo model: waste.pickup.request
- source (line/manual)
- line_user_id
- pickup_address
- preferred_time
- waste_type_name (text)
- contact_text (name + phone)
- note
- state (new/contacted/scheduled/done/cancel)

## Redis keys
- conv:{line_user_id}
- idem:{webhook_event_id}
