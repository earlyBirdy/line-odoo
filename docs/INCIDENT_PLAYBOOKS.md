# Incident Playbooks

Last updated: 2026-01-03

---

## A) LINE outage / webhook delivery issues

### Symptoms
- No incoming events
- LINE replies/pushes failing

### Triage
1) Check backend health:
```bash
curl -s https://<domain>/health | jq
```

2) Check backend logs for outbound LINE API errors

3) Verify LINE console:
- Webhook enabled
- Webhook URL correct
- Recent delivery logs (if available)

### Mitigation
- If outbound LINE API failing: retry with backoff, communicate status
- If inbound not arriving: verify DNS/ALB routing, verify `/line/webhook` path

### Resolution checklist
- Send test message to bot
- Confirm backend processes event successfully

---

## B) Odoo down / backend cannot reach Odoo

### Symptoms
- `/odoo/health` fails
- User flows that require Odoo data fail

### Triage
1) Health:
```bash
curl -s https://<domain>/odoo/health | jq
```

2) Odoo logs (ECS/EC2) or container logs

3) DB connectivity (RDS metrics, connections)

### Mitigation
- Restart Odoo service
- If DB issues: see playbook C
- Provide degraded response from backend (message: “system busy”)

---

## C) DB locked / Postgres contention

### Symptoms
- Odoo errors mentioning locks / deadlocks
- Latency spikes
- DB CPU high

### Triage (RDS)
- CloudWatch: CPU, connections, read/write latency
- Enable Performance Insights if available

### Triage (self-hosted postgres / dev)
```bash
docker compose exec db psql -U "$POSTGRES_USER" "$POSTGRES_DB" -c "select now();"
docker compose exec db psql -U "$POSTGRES_USER" "$POSTGRES_DB" -c "select * from pg_stat_activity order by state, query_start;"
```

### Mitigation
- Identify long-running transactions and terminate (carefully)
- Scale up RDS instance temporarily
- Restore from snapshot if corruption is suspected

### Post-incident
- Add indexes / tune queries causing lock contention
- Review Odoo scheduled jobs (cron) overlap
