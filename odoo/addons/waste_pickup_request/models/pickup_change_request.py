# -*- coding: utf-8 -*-
from odoo import fields, models


class WastePickupChangeRequest(models.Model):
    _name = "waste.pickup.change.request"
    _description = "Pickup Change Request"
    _order = "create_date desc"

    pickup_id = fields.Many2one("waste.pickup.request", required=True, ondelete="cascade", index=True)
    change_type = fields.Selection([
        ("cancel", "Cancel"),
        ("reschedule", "Reschedule"),
        ("note", "Note/Update"),
    ], required=True, default="note", index=True)

    requested_time = fields.Datetime(string="Requested New Time")
    reason = fields.Char(string="Reason / Summary")
    note = fields.Text(string="Details / Note")

    line_user_id = fields.Char(string="LINE User ID", index=True)
    source = fields.Selection([("line", "LINE"), ("internal", "Internal")], default="line", index=True)

    state = fields.Selection([
        ("new", "New"),
        ("applied", "Applied"),
        ("rejected", "Rejected"),
    ], default="new", index=True)

    applied_by = fields.Many2one("res.users", readonly=True)
    applied_at = fields.Datetime(readonly=True)

    def action_apply(self):
        for rec in self:
            if rec.state != "new":
                continue
            pickup = rec.pickup_id

            # Apply to pickup record (MVP behavior)
            if rec.change_type == "cancel":
                pickup.write({
                    "state": "cancel",
                    "note": (pickup.note or "") + ("\n[Cancel] " + (rec.reason or "") + ("\n" + rec.note if rec.note else "")),
                })
            elif rec.change_type == "reschedule":
                vals = {}
                if rec.requested_time:
                    vals["preferred_time"] = rec.requested_time
                vals["note"] = (pickup.note or "") + ("\n[Reschedule] " + (rec.reason or "") + ("\n" + rec.note if rec.note else ""))
                pickup.write(vals)
            else:
                pickup.write({
                    "note": (pickup.note or "") + ("\n[Update] " + (rec.reason or "") + ("\n" + rec.note if rec.note else "")),
                })

            rec.write({
                "state": "applied",
                "applied_by": self.env.user.id,
                "applied_at": fields.Datetime.now(),
            })

    def action_reject(self):
        for rec in self:
            if rec.state != "new":
                continue
            rec.write({"state": "rejected"})
