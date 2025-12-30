import base64, hashlib, hmac, json, os
from datetime import datetime
from typing import Any, Dict, Optional

import requests
from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException, Request
from redis import Redis

load_dotenv()

LINE_CHANNEL_SECRET = os.getenv("LINE_CHANNEL_SECRET", "")
LINE_CHANNEL_ACCESS_TOKEN = os.getenv("LINE_CHANNEL_ACCESS_TOKEN", "")

ODOO_URL = os.getenv("ODOO_URL", "http://odoo:8069")
ODOO_DB = os.getenv("ODOO_DB", "odoo")
ODOO_USERNAME = os.getenv("ODOO_USERNAME", "")
ODOO_PASSWORD = os.getenv("ODOO_PASSWORD", "")

REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")
CONV_TTL = int(os.getenv("CONV_TTL_SECONDS", "86400"))
ODOO_CALLBACK_SECRET = os.getenv("ODOO_CALLBACK_SECRET", "CHANGE_ME")

rds = Redis.from_url(REDIS_URL, decode_responses=True)
app = FastAPI(title="LINE Pickup → Odoo", version="0.1.3-mvp")

def verify_sig(body: bytes, sig: str) -> bool:
    if not LINE_CHANNEL_SECRET:
        return False
    digest = hmac.new(LINE_CHANNEL_SECRET.encode(), body, hashlib.sha256).digest()
    expect = base64.b64encode(digest).decode()
    return hmac.compare_digest(expect, sig)

def line_reply(token: str, messages: list[Dict[str, Any]]) -> None:
    if not LINE_CHANNEL_ACCESS_TOKEN or not token:
        return
    headers = {"Authorization": f"Bearer {LINE_CHANNEL_ACCESS_TOKEN}", "Content-Type": "application/json"}
    requests.post("https://api.line.me/v2/bot/message/reply", headers=headers,
                  json={"replyToken": token, "messages": messages}, timeout=10)

def line_push(to_user: str, messages: list[Dict[str, Any]]) -> None:
    if not LINE_CHANNEL_ACCESS_TOKEN or not to_user:
        return
    headers = {"Authorization": f"Bearer {LINE_CHANNEL_ACCESS_TOKEN}", "Content-Type": "application/json"}
    requests.post("https://api.line.me/v2/bot/message/push", headers=headers,
                  json={"to": to_user, "messages": messages}, timeout=10)

def conv_key(uid: str) -> str: return f"conv:{uid}"
def idem_key(eid: str) -> str: return f"idem:{eid}"

def idem_seen(eid: str) -> bool:
    if not eid: return False
    ok = rds.set(idem_key(eid), "1", nx=True, ex=3600)
    return ok is None

def conv_get(uid: str) -> Dict[str, Any]:
    raw = rds.get(conv_key(uid))
    if not raw:
        return {"step": "idle", "data": {}}
    try:
        return json.loads(raw)
    except Exception:
        return {"step": "idle", "data": {}}

def conv_set(uid: str, st: Dict[str, Any]) -> None:
    rds.set(conv_key(uid), json.dumps(st, ensure_ascii=False), ex=CONV_TTL)

def conv_reset(uid: str) -> None:
    rds.delete(conv_key(uid))

def odoo_jsonrpc(params: Dict[str, Any]) -> Dict[str, Any]:
    payload = {"jsonrpc": "2.0", "method": "call", "params": params, "id": 1}
    resp = requests.post(f"{ODOO_URL}/jsonrpc", json=payload, timeout=20)
    resp.raise_for_status()
    return resp.json()

def odoo_auth() -> int:
    res = odoo_jsonrpc({"service": "common", "method": "authenticate", "args": [ODOO_DB, ODOO_USERNAME, ODOO_PASSWORD, {}]})
    uid = res.get("result")
    if not isinstance(uid, int):
        raise RuntimeError(f"Odoo auth failed: {res}")
    return uid

def odoo_create_pickup(uid: int, vals: Dict[str, Any]) -> int:
    res = odoo_jsonrpc({"service": "object", "method": "execute_kw",
                        "args": [ODOO_DB, uid, ODOO_PASSWORD, "waste.pickup.request", "create", [vals]]})
    rid = res.get("result")
    if not isinstance(rid, int):
        raise RuntimeError(f"Odoo create failed: {res}")
    return rid

def try_dt(s: str) -> Optional[str]:
    s = (s or "").strip()
    for fmt in ("%Y-%m-%d %H:%M", "%Y/%m/%d %H:%M"):
        try:
            return datetime.strptime(s, fmt).strftime("%Y-%m-%d %H:%M:%S")
        except Exception:
            pass
    return None

def contact_message() -> list[Dict[str, Any]]:
    # TODO: replace with real hotline / working hours / URL
    return [{"type": "text", "text": "客服聯絡方式：\n電話：02-xxxx-xxxx\n服務時間：週一至週五 09:00-18:00"}]
def fmt_dt(s: Optional[str]) -> str:
    if not s:
        return "-"
    # Odoo returns "YYYY-MM-DD HH:MM:SS"
    try:
        return datetime.strptime(s, "%Y-%m-%d %H:%M:%S").strftime("%Y-%m-%d %H:%M")
    except Exception:
        return s

def my_pickups_message(line_user_id: str) -> list[Dict[str, Any]]:
    """List recent pickup requests for this LINE user."""
    try:
        uid_odoo = odoo_auth()
        rows = odoo_search_read(
            uid_odoo,
            domain=[["line_user_id", "=", line_user_id]],
            fields=["name", "state", "preferred_time", "pickup_address", "create_date"],
            limit=5,
            order="create_date desc",
        )
    except Exception:
        return [{"type": "text", "text": "目前無法查詢您的取貨紀錄，請稍後再試或聯絡客服。"}]

    if not rows:
        return [{"type": "text", "text": "目前查無您的取貨需求紀錄。若要安排取貨，請點選【安排取貨】。"}]

    # Map state to user-friendly text
    state_map = {
        "new": "已送出",
        "contacted": "已聯絡",
        "scheduled": "已安排",
        "done": "已完成",
        "cancel": "已取消",
    }

    lines = ["📦 您最近的取貨需求（最新 5 筆）："]
    for r in rows:
        nm = r.get("name", "-")
        st = state_map.get(r.get("state"), r.get("state") or "-")
        t = fmt_dt(r.get("preferred_time"))
        addr = (r.get("pickup_address") or "-")
        if len(addr) > 18:
            addr = addr[:18] + "…"
        lines.append(f"• {nm}｜{st}｜{t}｜{addr}")

    lines.append("\n如需修改/取消，請聯絡客服協助。")
    return [{"type": "text", "text": "\n".join(lines)}]




def start(uid: str) -> list[Dict[str, Any]]:
    conv_set(uid, {"step": "address", "data": {}})
    return [{"type": "text", "text": "🧾 請輸入【取貨地址】（例：台北市xx路xx號）。\n（輸入 cancel 可取消）"}]

def handle_text(uid: str, text: str) -> list[Dict[str, Any]]:
    text = text or ""
    if text.strip().lower() in ("cancel", "取消", "reset"):
        conv_reset(uid)
        return [{"type": "text", "text": "已取消。需要安排取貨請再點選【安排取貨】。"}]

    st = conv_get(uid)
    step = st.get("step", "idle")
    data = st.get("data", {})

    if step == "idle":
        return start(uid)

    if step == "address":
        data["pickup_address"] = text.strip()
        st["step"] = "time"
        st["data"] = data
        conv_set(uid, st)
        return [{"type": "text", "text": "🕒 請輸入【期望取貨時間】（YYYY-MM-DD HH:MM，例如 2026-01-05 09:30）。"}]

    if step == "time":
        dt = try_dt(text)
        if not dt:
            return [{"type": "text", "text": "時間格式不正確，請用 YYYY-MM-DD HH:MM（例：2026-01-05 09:30）。"}]
        data["preferred_time"] = dt
        st["step"] = "waste_type"
        st["data"] = data
        conv_set(uid, st)
        return [{"type": "text", "text": "♻️ 請輸入【廢棄物種類】（例：一般廢棄物/廢油/廢液…）。"}]

    if step == "waste_type":
        data["waste_type_name"] = text.strip()
        st["step"] = "contact"
        st["data"] = data
        conv_set(uid, st)
        return [{"type": "text", "text": "☎️ 請輸入【聯絡人姓名】與【電話】（例：王小明 0912-345-678）。"}]

    if step == "contact":
        data["contact_text"] = text.strip()
        st["step"] = "note"
        st["data"] = data
        conv_set(uid, st)
        return [{"type": "text", "text": "📝 備註（沒有請輸入 - ）"}]

    if step == "note":
        data["note"] = "" if text.strip() == "-" else text.strip()
        st["step"] = "confirm"
        st["data"] = data
        conv_set(uid, st)
        return [{"type": "text", "text": f"請確認：\n地址：{data.get('pickup_address')}\n時間：{data.get('preferred_time')}\n種類：{data.get('waste_type_name')}\n聯絡：{data.get('contact_text')}\n備註：{data.get('note') or '-'}\n\n回覆 OK 送出，或輸入 cancel 取消。"}]

    if step == "confirm":
        if text.strip().lower() in ("ok", "okay", "確認", "送出"):
            uid_odoo = odoo_auth()
            rid = odoo_create_pickup(uid_odoo, {
                "source": "line",
                "line_user_id": uid,
                "pickup_address": data.get("pickup_address"),
                "preferred_time": data.get("preferred_time"),
                "waste_type_name": data.get("waste_type_name"),
                "contact_text": data.get("contact_text"),
                "note": data.get("note"),
                "state": "new",
            })
            conv_reset(uid)
            return [{"type": "text", "text": f"✅ 已送出安排取貨需求，單號 #{rid}。\n客服將與您聯繫確認。"}]
        return [{"type": "text", "text": "若要送出請回覆 OK；或輸入 cancel 取消。"}]

    conv_reset(uid)
    return [{"type": "text", "text": "流程已重置，請再點選【安排取貨】。"}]

@app.get("/health")
def health():
    return {"ok": True, "version": "0.1.3-mvp"}


@app.get("/line/health")
def health_alias():
    return health()

@app.post("/webhook")
async def webhook(request: Request, x_line_signature: Optional[str] = Header(default=None, alias="X-Line-Signature")):
    body = await request.body()
    if not x_line_signature or not verify_sig(body, x_line_signature):
        raise HTTPException(status_code=401, detail="Invalid signature")

    payload = json.loads(body.decode("utf-8"))
    for ev in payload.get("events", []):
        eid = ev.get("webhookEventId") or (ev.get("message") or {}).get("id") or ""
        if eid and idem_seen(eid):
            continue
        src = ev.get("source") or {}
        uid = src.get("userId") or ""
        token = ev.get("replyToken") or ""
        if not uid:
            continue

        if ev.get("type") == "postback":
            pb = ev.get("postback") or {}
            data = parse_postback(pb.get("data", ""))
            action = (data.get("action") or "").strip()
            if action == "pickup_start":
                line_reply(token, start(uid))
                continue
            if action == "contact":
                line_reply(token, contact_message())
                continue
            if action == "my_pickups":
                line_reply(token, my_pickups_placeholder())
                continue

        if ev.get("type") == "message":
            msg = ev.get("message") or {}
            if msg.get("type") == "text":
                line_reply(token, handle_text(uid, msg.get("text") or ""))
            else:
                line_reply(token, [{"type": "text", "text": "目前僅支援文字輸入（MVP）。"}])

    return {"ok": True}

@app.post("/line/webhook")
async def webhook_alias(request: Request, x_line_signature: Optional[str] = Header(default=None, alias="X-Line-Signature")):
    return await webhook(request, x_line_signature)


@app.post("/odoo/status_update")
async def status_update(req: Request):
    data = await req.json()
    if data.get("secret") != ODOO_CALLBACK_SECRET:
        raise HTTPException(status_code=401, detail="Invalid secret")
    line_push(data.get("line_user_id", ""), [{"type": "text", "text": data.get("message", "狀態更新")}])
    return {"ok": True}
