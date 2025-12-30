# GoodCan – LINE OA × Odoo「安排取貨」MVP Starter

- LINE Rich Menu「安排取貨」→ 多步驟對話收集資料
- Backend 驗簽/去重/狀態機（Redis）→ JSON-RPC 建立 Odoo 取貨需求單
- Odoo 後台：Discuss Inbox 通知 + Activity 待辦
- 內勤人工聯絡客戶、人工排到行事曆/取貨計劃（你們既有模組）

## Docs
- `docs/sequence_diagram.md`
- `docs/rich_menu_postbacks.md`
- `docs/data_dictionary.md`

## Local demo stack
```bash
cp .env.example .env
cp backend/.env.example backend/.env
docker compose up -d --build
```
- Odoo: http://localhost/
- Backend: http://localhost/line/health


## LINE Webhook URL
- Set in LINE Developers Console:
  - `https://<YOUR_DOMAIN>/line/webhook`
- Backend supports both `/webhook` and `/line/webhook` (alias), so Nginx may rewrite or not.


## Rich Menu actions
- `action=pickup_start` (MVP)
- `action=contact` (stub)
- `action=my_pickups` (lists latest 5)


## Nginx rate limit
- `/line/webhook` 已加上 rate limit（10 req/sec per IP, burst 20）。
