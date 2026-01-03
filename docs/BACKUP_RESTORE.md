# Backup & Restore (Odoo + Postgres + Filestore)

Last updated: 2026-01-03

This system has **two critical stateful stores**:

1) **Postgres database** (Odoo data)
2) **Odoo filestore** (attachments/uploads) — in dev it is `odoo_data` volume

---

## 1) Dev (docker volumes)

### 1.1 Backup (dev)

Database (pg_dump):
```bash
docker compose exec -T db pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > backup_dev_$(date +%Y%m%d).sql
```

Filestore (volume archive):
```bash
docker run --rm -v line-odoo-main_odoo_data:/data -v "$PWD":/backup alpine   sh -c "cd /data && tar -czf /backup/filestore_dev_$(date +%Y%m%d).tgz ."
```

### 1.2 Restore (dev)

```bash
cat backup_dev_YYYYMMDD.sql | docker compose exec -T db psql -U "$POSTGRES_USER" "$POSTGRES_DB"
```

Filestore restore:
```bash
docker run --rm -v line-odoo-main_odoo_data:/data -v "$PWD":/backup alpine   sh -c "rm -rf /data/* && tar -xzf /backup/filestore_dev_YYYYMMDD.tgz -C /data"
```

---

## 2) Staging/Prod (AWS)

### 2.1 Database
Preferred: **RDS automated backups + snapshots**
- Enable automated backups (retain 7–35 days)
- Take manual snapshot before migrations

### 2.2 Filestore
Preferred options:
- Store filestore on **EFS** (mounted to Odoo tasks), OR
- Use Odoo settings/addons to move attachments to object storage (S3) if acceptable

### 2.3 Restore process (prod-safe)

1) Put system in maintenance (optional)
2) Restore RDS from snapshot to a new instance
3) Restore filestore (EFS snapshot or S3 restore)
4) Point Odoo to restored DB + filestore
5) Validate:
   - `/odoo/health` (backend)
   - Odoo login
   - One end-to-end LINE interaction

