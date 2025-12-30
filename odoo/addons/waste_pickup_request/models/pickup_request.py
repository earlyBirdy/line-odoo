import os
import requests
from odoo import api, fields, models

class WastePickupRequest(models.Model):
    _name = "waste.pickup.request"
    _description = "Waste Pickup Request"
    _inherit = ["mail.thread", "mail.activity.mixin"]

    name = fields.Char(default="New", readonly=True, copy=False)
    source = fields.Selection([("line", "LINE"), ("manual", "Manual")], default="line", tracking=True)
    line_user_id = fields.Char(index=True, tracking=True)

    pickup_address = fields.Char(tracking=True)
    preferred_time = fields.Datetime(tracking=True)
    waste_type_name = fields.Char(string="Waste Type (text)", tracking=True)
    contact_text = fields.Char(string="Contact (name + phone)", tracking=True)
    note = fields.Text()

    state = fields.Selection([
        ("new", "New"),
        ("contacted", "Contacted"),
        ("scheduled", "Scheduled"),
        ("done", "Done"),
        ("cancel", "Cancelled"),
    ], default="new", tracking=True)

    @api.model_create_multi
    def create(self, vals_list):
        for vals in vals_list:
            if vals.get("name") in (None, "", "New"):
                vals["name"] = self.env["ir.sequence"].next_by_code("waste.pickup.request") or "PR-New"
        recs = super().create(vals_list)

        # Notify staff: Discuss + Activity (assigned to current user by default; adjust later)
        for rec in recs:
            rec.message_post(body=f"🆕 新取貨需求：{rec.name}\n地址：{rec.pickup_address}\n時間：{rec.preferred_time or '-'}\n種類：{rec.waste_type_name or '-'}\n聯絡：{rec.contact_text or '-'}")
            rec.activity_schedule("mail.mail_activity_data_todo", summary="聯絡客戶確認取貨需求", note=f"請聯絡客戶：{rec.contact_text or '-'}", user_id=self.env.user.id)
        return recs

    def write(self, vals):
        prev = {r.id: r.state for r in self}
        res = super().write(vals)
        if "state" in vals:
            backend_url = os.getenv("BACKEND_NOTIFY_URL", "http://backend:8000/odoo/status_update")
            secret = os.getenv("ODOO_CALLBACK_SECRET", "CHANGE_ME")
            for rec in self:
                if not rec.line_user_id:
                    continue
                old = prev.get(rec.id)
                new = rec.state
                if old == new:
                    continue
                msg = f"📌 取貨需求狀態更新：{rec.name} {old} → {new}"
                try:
                    requests.post(backend_url, json={"secret": secret, "line_user_id": rec.line_user_id, "message": msg}, timeout=10)
                except Exception:
                    rec.message_post(body="⚠️ Failed to push status to LINE (backend unreachable).")
        return res
