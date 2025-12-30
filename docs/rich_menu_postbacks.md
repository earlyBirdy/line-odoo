# LINE Rich Menu Postbacks + Webhook Routing

這份文件讓「LINE OA 設定」與「Backend Router」一致，避免上線時路徑對不上。

## 1) Webhook URL（請填在 LINE Developers Console）
**Webhook URL（建議固定）：**
- `https://<YOUR_DOMAIN>/line/webhook`

驗證方式：
- 打開 LINE Developers → Messaging API → Webhook URL → **Verify**
- 需回傳 `200 OK`

> 為什麼是 `/line/webhook`？
> - Nginx 會把 `/line/*` 轉發到 backend
> - 無論你採用「path rewrite」或「不 rewrite」，backend 都會同時支援：
>   - `/webhook`
>   - `/line/webhook`

## 2) Rich Menu 按鈕設定

### 「安排取貨」
- Type: **Postback**
- Data: `action=pickup_start`

（可選）
- 「聯絡客服」: Postback `action=contact`
- 「我的取貨」(第二期): Postback `action=my_pickups`

## 3) Backend 路由（對照）
Backend (FastAPI) 會提供：
- `GET /health`
- `GET /line/health`   (alias)
- `POST /webhook`
- `POST /line/webhook` (alias)

**因此 Nginx / 直連都可用：**
- 直連 backend：`http://<backend-host>:8000/webhook`
- 經 Nginx：`https://<YOUR_DOMAIN>/line/webhook`

## 4) Postback Data 規格
- `action=pickup_start` → 啟動「安排取貨」對話流程
- `action=contact` → 顯示客服資訊（可選）
- `action=my_pickups` → 顯示我的取貨（已支援查詢最近 5 筆）


## Nginx 防爆量（已內建）
- `nginx/nginx.conf` 已對 `/line/webhook` 加上 `limit_req`（10 r/s, burst 20）。


## 我的取貨（Flex Message）
- `action=my_pickups` 會回傳 Flex carousel（最多 5 筆）。
- 範例 payload：`docs/flex_my_pickups_example.json`
