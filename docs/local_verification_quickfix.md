# Quick Fix: /web/database/manager 500 (KeyError ir.http)

If you see logs like:
- Database odoo not initialized
- KeyError: 'ir.http'
- relation ir_module_module does not exist

It usually means Postgres created a blank database named `odoo` (common when POSTGRES_USER=odoo and POSTGRES_DB not set).
Odoo will try to load it and crash.

Fix (recommended, clean start):
```bash
docker compose down --volumes --remove-orphans
docker compose -f docker-compose.odoo-demo.yml up
```
Then open:
- http://localhost:8069/web/database/manager
Create DB: `odoo_staging`
