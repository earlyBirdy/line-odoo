> **Note:** This document is kept for reference. For the canonical sequential runbook, use `docs/RUNBOOK.md`.

# E2E Staging → Production Runbook

# E2E STAGING RUNBOOK
LINE ↔ Backend (FastAPI) ↔ Odoo (Community 18, AWS)

This runbook is the **single source of truth** for validating the LINE × Odoo integration in **STAGING** before any production cutover.

---

## 1) Prerequisites
### Local tools
- Docker + Docker Compose
- Python 3.11 + virtualenv (for backend)
- `curl`
- A browser (for Odoo UI)


### Credentials & Access (staging → production)

**Rule:** never commit real secrets to git. Use `.env` (excluded), your password manager, or AWS Secrets Manager / SSM Parameter Store.

These are the **accounts/credentials you need** for E2E testing (LINE → Backend → Odoo) and for cutover to AWS production.  
(You asked “how many accounts + passwords are in the repo”: the correct answer should be **zero real passwords in the repo**. This section documents *what* credentials exist and *where* to provide them.)

#### Required credentials (by component)

| Component | Credential / account | Used for | Where to set locally | Where to set in AWS prod |
|---|---|---|---|---|
| LINE Official Account | **LINE Channel Secret** | Validate webhook signature (`X-Line-Signature`) | env `LINE_CHANNEL_SECRET` | Secrets Manager / SSM (injected to backend) |
| LINE Official Account | **LINE Channel Access Token** | Reply/push messages via Messaging API | env `LINE_CHANNEL_ACCESS_TOKEN` | Secrets Manager / SSM |
| Backend (FastAPI) | **Webhook bypass (DEV only)** (optional) | Allow local postback simulation without LINE signature | env `LINE_WEBHOOK_BYPASS=1` (only in local) | **Do not enable** |
| Odoo | **Odoo URL** | JSON-RPC endpoint | env `ODOO_URL=http://localhost:8069` | ALB/CloudFront URL (https) |
| Odoo | **DB name** | Which database to authenticate against | env `ODOO_DB=odoo_staging` | `ODOO_DB=odoo_prod` (recommended) |
| Odoo | **Odoo admin login** | Authenticate via `/jsonrpc` | env `ODOO_USERNAME`, `ODOO_PASSWORD` | Secrets Manager / SSM |
| Odoo | **Odoo master password** | DB manager actions (create/duplicate/backup via UI/CLI) | usually configured in `/etc/odoo/odoo.conf` as `admin_passwd` | Secrets Manager / SSM, injected to Odoo container/task |
| Postgres | **DB host/user/pass** | Odoo database connections | in compose: `db`, user/pass `odoo` | RDS endpoint + IAM/secret rotation |
| AWS | **IAM principal/role** | Deploy, read secrets, operate infra | `aws configure` or SSO | least-privilege roles, MFA/SSO |
| AWS | **KMS / S3 access** | Encrypted backups + artifacts | n/a | required for backups and restore drills |

#### Verification commands (safe)

**1) Confirm no secrets committed**
```bash
# quick scan for obvious secret keys (should NOT show real values committed)
git grep -nE "(LINE_CHANNEL_SECRET|ACCESS_TOKEN|ODOO_PASSWORD|admin_passwd|AWS_SECRET_ACCESS_KEY)" || true
```

**2) Confirm env is set (prints only variable names, not values)**
```bash
env | egrep "LINE_|ODOO_|AWS_" | sed -E 's/(=).*/\1***REDACTED***/'
```

**3) Confirm Odoo DB exists**
```bash
docker compose -f docker-compose.odoo-demo.yml exec db psql -U odoo -l
```

### Ports
- Odoo: `http://localhost:8069`
- Backend (FastAPI): `http://127.0.0.1:8000`

---

## 2) Bring up Odoo + Postgres (local staging)
### Verify (CLI)
```bash
docker compose -f docker-compose.odoo-demo.yml up -d
docker compose -f docker-compose.odoo-demo.yml ps
curl -I http://localhost:8069/web/login
```


From repo root:

```bash
docker compose -f docker-compose.odoo-demo.yml up -d
docker compose -f docker-compose.odoo-demo.yml ps
```

Expected:
- `line-odoo-db-1` is **Up**
- `line-odoo-odoo-1` is **Up**
- `http://localhost:8069` redirects to `/web/database/selector`

---

## 3) Create / ensure the STAGING database exists
Check DBs:

```bash
docker compose -f docker-compose.odoo-demo.yml exec db psql -U odoo -l
```

If `odoo_staging` does **not** exist, create it:

```bash
docker compose -f docker-compose.odoo-demo.yml exec db createdb -U odoo odoo_staging
```

---

## 4) Initialize Odoo base modules on `odoo_staging`
Run Odoo one-shot init (inside container) **with DB connection args**:

```bash
docker compose -f docker-compose.odoo-demo.yml exec odoo odoo \
  --db_host=db \
  --db_port=5432 \
  --db_user=odoo \
  --db_password=odoo \
  -d odoo_staging \
  -i base \
  --stop-after-init
```

Then restart Odoo:

```bash
docker compose -f docker-compose.odoo-demo.yml restart odoo
```

---

## 5) Install the custom module(s)
### Verify (CLI)
```bash
# from Odoo UI: Apps → Update Apps List → search module → Install
# CLI alternative (inside container) – if you later add a scripted install:
docker compose -f docker-compose.odoo-demo.yml exec odoo bash -lc 'odoo --help | head -n 5'
```


### 5.1 Confirm addons path
Your container should mount extra addons at `/mnt/extra-addons`.

### 5.2 Install from UI
1. Open `http://localhost:8069`
2. Select database: `odoo_staging`
3. Create admin user (first-time only)
4. Go to **Apps**
5. Remove “Apps” filter, search for your module (e.g., `waste_pickup_request`)
6. Click **Install**

If install fails:
- Inspect logs:
  ```bash
  docker compose -f docker-compose.odoo-demo.yml logs -f odoo
  ```
- Most common issues in Odoo 17+ / 18:
  - use `<list>` instead of `<tree>`
  - avoid deprecated `attrs=` / `states=` in XML views (use Odoo 17+ compatible constructs)

---

## 6) Start the backend (FastAPI)
### Verify (CLI)
```bash
cd backend
uvicorn app.main:app --reload --port 8000
curl -s http://127.0.0.1:8000/health
curl -s http://127.0.0.1:8000/line/health
curl -s http://127.0.0.1:8000/odoo/health
```


From `backend/`:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

---

## 7) Backend health checks (local)
### 7.1 Backend core
```bash
curl http://127.0.0.1:8000/health
```

Expected:
```json
{"ok":true,"version":"..."}
```

### 7.2 LINE adapter
```bash
curl http://127.0.0.1:8000/line/health
```

Expected:
```json
{"ok":true,"version":"..."}
```

### 7.3 Odoo integration health
```bash
curl http://127.0.0.1:8000/odoo/health
```

Expected (typical, before credentials are set):
- `ok: true`
- `uid: false` means backend is reachable but not authenticated yet (or auth disabled for health)
- `db: "odoo_staging"`

If you see “database does not exist”, fix by completing sections **3–4**.

---

## 8) E2E flow tests (recommended order)
### Verify (CLI)
```bash
# 1) Health checks
curl -s http://127.0.0.1:8000/health
curl -s http://127.0.0.1:8000/odoo/health

# 2) Webhook signature test (generate X-Line-Signature for a minified JSON)
LINE_CHANNEL_SECRET="REDACTED" python3 - <<'PY'
import hmac, hashlib, base64, json, os
body={"events":[{"type":"postback","replyToken":"DUMMY","source":{"type":"user","userId":"U_test_001"},"postback":{"data":"action=schedule_pickup"}}]}
raw=json.dumps(body,separators=(",",":")).encode("utf-8")
sig=base64.b64encode(hmac.new(os.environ["LINE_CHANNEL_SECRET"].encode(), raw, hashlib.sha256).digest()).decode()
print("SIG:", sig)
print("BODY:", raw.decode())
PY
```


> These steps assume you can log into Odoo (`http://localhost:8069`) on `odoo_staging`.

### 8.1 Create a pickup request via Backend → Odoo
1. Call the backend endpoint that creates a pickup request (replace with your actual route).
   - If your repo uses a specific endpoint, put it here and keep it stable.
2. Verify:
   - New record exists in Odoo under the module menu
   - Default state is correct (`new`/`submitted` per your workflow)

**Validation checklist**
- [ ] Record created in Odoo with correct customer identifiers
- [ ] Address / time window stored
- [ ] Initial state is correct
- [ ] No traceback in Odoo logs

### 8.2 Change request flow (reschedule/cancel)
1. Create a change request (backend endpoint or Odoo UI)
2. Verify:
   - Change request linked to the original pickup
   - State transitions work
   - Business rules enforced (e.g., cannot change after confirmed)

**Validation checklist**
- [ ] `change_type` works (reschedule/cancel)
- [ ] `requested_time` is required only for reschedule (as per rule)
- [ ] Approval/Apply action updates the pickup correctly

### 8.3 Status query (Backend reads Odoo → returns summary)
1. Call backend “get status” endpoint
2. Verify response matches Odoo record state/time

**Validation checklist**
- [ ] Response is stable and readable
- [ ] No missing fields / schema errors
- [ ] State mapping is correct

---

## 9) UAT sign-off matrix (who signs what)
Use this table to capture approval before production cutover.

| Area | What is being validated | Test owner | Evidence (link/screenshot/log) | Pass/Fail | Sign-off |
|---|---|---|---|---|---|
| Odoo module install | Module installs cleanly on `odoo_staging` | Tech Lead | Odoo logs + Apps screen |  |  |
| Core pickup creation | Create pickup E2E (backend→odoo) | UAT Lead | Record screenshot + API response |  |  |
| Change requests | Reschedule / cancel rules | Operations | Before/after screenshots |  |  |
| Status & tracking | Status returned to user correctly | Customer Support | API response examples |  |  |
| Access & permissions | Roles, who can approve/apply | Admin | Role settings screenshots |  |  |
| Logging & monitoring | Logs exist for audit | DevOps | log samples |  |  |
| Kill-switch | Disable safely without data loss | DevOps | command outputs |  |  |
| Data correctness | Fields/labels are correct | Business Owner | export screenshot |  |  |

**Exit criteria**
- All rows are **Pass**
- Named sign-offs recorded for: Tech Lead + Business Owner + Ops + DevOps

---

## 10) Production cutover checklist
### 10.1 Configuration readiness
- [ ] Production environment variables prepared (secrets in vault / secure store)
- [ ] Odoo production URL confirmed
- [ ] DB name confirmed (production DB) and **not** reused by staging
- [ ] LINE channel keys confirmed (prod channel, not staging)
- [ ] Backend base URL confirmed (prod domain)

### 10.2 Data & migration
- [ ] Decide data strategy:
  - [ ] fresh start (recommended for MVP)
  - [ ] migrate selected master data only
- [ ] If migrating:
  - [ ] export template agreed
  - [ ] import tested in staging
  - [ ] rollback strategy validated

### 10.3 Security & access
- [ ] Odoo admin credentials stored securely
- [ ] Least privilege roles defined
- [ ] Webhook endpoints protected (signature validation / IP allowlist if applicable)
- [ ] Audit logging enabled (backend + Odoo access logs)

### 10.4 Observability
- [ ] Error monitoring enabled (Sentry/CloudWatch/etc.)
- [ ] Log retention policy set
- [ ] Dashboards prepared (requests/day, failures, latency)

### 10.5 Go-live decision gates
- [ ] UAT matrix complete
- [ ] Kill-switch tested in staging
- [ ] Rollback plan rehearsed
- [ ] Stakeholders scheduled for go-live window

---

## 11) Rollback / kill-switch plan (do not skip)
### Verify (CLI)
```bash
# Backend kill switch example (depends on your deployment method)
# - toggle feature flag in env / parameter store
# - redeploy last known good image
# Placeholders:
echo "Define rollback commands per AWS deployment (ECS/EC2) before prod cutover."
```


### 11.1 Immediate “stop the bleeding” actions
**Option A — Disable LINE webhook (fastest)**
- Disable webhook in LINE Developer Console (prod channel)
- Result: backend stops receiving events immediately

**Option B — Backend kill-switch**
- Set env flag and restart backend:
  - `LINE_ENABLED=false`
  - (optional) `ODOO_WRITE_ENABLED=false` (read-only mode)
- Verify:
  ```bash
  curl http://127.0.0.1:8000/line/health
  ```

### 11.2 Roll back the Odoo module (if needed)
- If a newly deployed module version is breaking:
  - revert to previous container image / previous addon commit
  - restart Odoo
- If DB schema changed, prefer restoring from snapshot (see 11.3)

### 11.3 Database restore
**If using managed Postgres (recommended for production):**
- Restore latest snapshot to a new instance / point-in-time restore
- Swap connection string after validation

**If local / docker Postgres:**
- Restore from `pg_dump` you took before upgrade:
  ```bash
  # example restore flow (adjust paths)
  psql -U odoo -d <db> -f backup.sql
  ```

### 11.4 Communication template (minimum)
- [ ] Announce incident start time
- [ ] Describe user impact
- [ ] Confirm kill-switch activation
- [ ] ETA for next update (do not promise final restore time unless certain)

---

## 12) Troubleshooting quick hits
### Odoo says: “Database not initialized”
- Run base init (section 4) and restart Odoo.

### Backend `/odoo/health` fails: “database does not exist”
- Confirm DB exists (section 3)
- Confirm backend config points to the same DB name

### Docker compose shows “service is not running”
- Ensure you’re using the same compose file in every command:
  ```bash
  docker compose -f docker-compose.odoo-demo.yml ps
  ```

---

## 13) Appendix: recommended naming & env patterns
### Database naming
- Local staging: `odoo_staging`
- Production: `odoo_prod` (or company standard, but **not** `odoo_staging`)

### Minimal env vars (backend)
- `ODOO_URL=http://localhost:8069`
- `ODOO_DB=odoo_staging`
- `ODOO_USER=...`
- `ODOO_PASSWORD=...`
- `LINE_ENABLED=true|false`
- `ODOO_WRITE_ENABLED=true|false`

---

**This document replaces prior local E2E docs.**

---

## ⏱️ Ownership & Time Estimates (Execution Planning)

> Use this table during cut-over call. One owner per line. No shared responsibility.

| Section | Owner Role | Estimated Time | Blocking? |
|---|---|---:|:--:|
| Scope & Architecture Review | PM / Tech Lead | 15 min | ⛔ |
| Environments & Naming | Tech Lead | 10 min | ⛔ |
| Credentials & Access Check | DevOps | 20 min | ⛔ |
| Prerequisites Validation | DevOps | 15 min | ⛔ |
| Bring up Odoo (staging) | DevOps | 10 min | ⛔ |
| Database Preparation | DevOps | 15 min | ⛔ |
| Base Init / DB Create | DevOps | 10 min | ⛔ |
| Custom Module Install | Odoo Dev | 15 min | ⛔ |
| Backend Start (staging) | Backend Dev | 10 min | ⛔ |
| LINE Webhook / Rich Menu | Backend Dev | 15 min | ⛔ |
| E2E Test Execution | QA / Product | 30–45 min | ⛔ |
| UAT Sign-off | Business Owner | 15 min | ⛔ |
| Production Cut-over | DevOps | 20–30 min | ⛔ |
| Rollback Readiness Check | DevOps | 10 min | ⛔ |
| Post-Go-Live Monitoring | Ops | 60 min | ⛔ |

**Typical total cut-over window:** ~3–4 hours (excluding soak monitoring)

---

## ☁️ AWS Production Alignment (ECS / EC2 / RDS)

This repo’s intent is **staging → production cutover** with minimal downtime and clear rollback. Below are **copy/paste AWS CLI commands** (with placeholders) for the two most common production shapes:
- **Option A (recommended): ECS + ALB + RDS (Postgres)**
- **Option B: EC2 + Docker Compose + RDS (Postgres)**

> **Convention:** export variables once, then reuse commands. Replace placeholders with your real identifiers.

### Common AWS CLI prerequisites (all options)

**Owner:** DevOps / Platform  
**ETA:** 10–20 min

```bash
# 0) Confirm AWS CLI is using the correct account + region
export AWS_PROFILE="prod"
export AWS_REGION="ap-southeast-1"
aws sts get-caller-identity
aws configure list
```

```bash
# 1) Optional: set default region for the session
export AWS_DEFAULT_REGION="$AWS_REGION"
```

---

### Option A — AWS ECS + ALB + RDS (Recommended)

**Owner:** DevOps / Platform + Odoo Admin  
**ETA:** 60–120 min (incl. backup + validation)

#### A0) Identify production resources (one-time)

```bash
# Fill these in (names, not ARNs where possible)
export ECS_CLUSTER="line-odoo-prod"
export ECS_BACKEND_SVC="line-odoo-backend"
export ECS_ODOO_SVC="line-odoo-odoo"

export RDS_ID="line-odoo-prod-db"               # DB instance identifier
export RDS_SNAPSHOT_ID="line-odoo-prod-$(date +%Y%m%d-%H%M)"

export ALB_ARN="arn:aws:elasticloadbalancing:REGION:ACCT:loadbalancer/app/..."
export ALB_LISTENER_ARN="arn:aws:elasticloadbalancing:REGION:ACCT:listener/app/..."
# If you use weighted target-groups for cutover:
export RULE_ARN="arn:aws:elasticloadbalancing:REGION:ACCT:listener-rule/app/..."

# Optional Route53 cutover:
export HOSTED_ZONE_ID="ZXXXXXXXXXXXX"
export PROD_DOMAIN="api.example.com"
export PROD_ALB_DNS="my-alb-123456.ap-southeast-1.elb.amazonaws.com"
```

Verify discovery:

```bash
aws ecs describe-clusters --clusters "$ECS_CLUSTER" --query "clusters[0].status"
aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_BACKEND_SVC" "$ECS_ODOO_SVC"   --query "services[].{name:serviceName,desired:desiredCount,running:runningCount,taskDef:taskDefinition,status:status}"
aws rds describe-db-instances --db-instance-identifier "$RDS_ID"   --query "DBInstances[0].{id:DBInstanceIdentifier,status:DBInstanceStatus,engine:Engine,endpoint:Endpoint.Address,port:Endpoint.Port,multiAZ:MultiAZ,storage:AllocatedStorage}"
aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN"   --query "LoadBalancers[0].{dns:DNSName,state:State.Code}"
```

#### A1) Production DB backup (RDS snapshot)

```bash
aws rds create-db-snapshot   --db-instance-identifier "$RDS_ID"   --db-snapshot-identifier "$RDS_SNAPSHOT_ID"

aws rds wait db-snapshot-completed --db-snapshot-identifier "$RDS_SNAPSHOT_ID"
aws rds describe-db-snapshots --db-snapshot-identifier "$RDS_SNAPSHOT_ID"   --query "DBSnapshots[0].{id:DBSnapshotIdentifier,status:Status,created:SnapshotCreateTime}"
```

> **If you use Multi-AZ:** confirm `multiAZ:true` (above) and ensure automated backups retention is set appropriately.

#### A2) Put production into “change window” mode (freeze writes)

How you freeze depends on your design. Pick one:
- **Backend freeze:** set env var that makes webhook handlers return 200 but do **no writes** (a “kill-switch”).  
- **Odoo freeze:** disable scheduled actions / crons relevant to the flow, and restrict UI writes.

ECS update-service to set an env var requires a **new task definition revision**. If you already manage task definitions in JSON, use this workflow:

```bash
# Export current task definition (backend)
export BACKEND_TD_ARN=$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_BACKEND_SVC" --query "services[0].taskDefinition" --output text)
aws ecs describe-task-definition --task-definition "$BACKEND_TD_ARN" --query "taskDefinition" > backend-taskdef.json

# Edit backend-taskdef.json:
# - change containerDefinitions[].environment to add:
#   {"name":"CUTOVER_FREEZE_WRITES","value":"1"}
# - remove fields not allowed on register (status, revision, taskDefinitionArn, requiresAttributes, compatibilities, registeredAt, registeredBy)

# Register new revision
export NEW_BACKEND_TD_ARN=$(aws ecs register-task-definition --cli-input-json file://backend-taskdef.json --query "taskDefinition.taskDefinitionArn" --output text)

# Deploy it
aws ecs update-service --cluster "$ECS_CLUSTER" --service "$ECS_BACKEND_SVC"   --task-definition "$NEW_BACKEND_TD_ARN" --force-new-deployment

aws ecs wait services-stable --cluster "$ECS_CLUSTER" --services "$ECS_BACKEND_SVC"
```

#### A3) Deploy production backend + odoo (ECS rolling)

If you use CI/CD that registers new task defs, the “exact” cutover command is usually just:

```bash
# (1) backend: update to the new task definition ARN produced by your pipeline
aws ecs update-service --cluster "$ECS_CLUSTER" --service "$ECS_BACKEND_SVC"   --task-definition "<NEW_BACKEND_TASKDEF_ARN>" --force-new-deployment

# (2) odoo: update to the new task definition ARN produced by your pipeline
aws ecs update-service --cluster "$ECS_CLUSTER" --service "$ECS_ODOO_SVC"   --task-definition "<NEW_ODOO_TASKDEF_ARN>" --force-new-deployment

aws ecs wait services-stable --cluster "$ECS_CLUSTER" --services "$ECS_BACKEND_SVC" "$ECS_ODOO_SVC"
```

Validate logs and task health:

```bash
aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_BACKEND_SVC" "$ECS_ODOO_SVC"   --query "services[].{name:serviceName,events:events[0].message}" --output table
```

If you’re using CloudWatch Logs, grab the last errors (replace log group):

```bash
aws logs tail "/ecs/line-odoo-backend" --since 10m --follow
aws logs tail "/ecs/line-odoo-odoo" --since 10m --follow
```

#### A4) Switch traffic (ALB or Route53)

**A4.1 Weighted ALB rule cutover (staging → prod)**  
If you route staging and prod via two target groups on a single rule:

```bash
# Example: set 100% to prod target-group and 0% to staging
aws elbv2 modify-rule --rule-arn "$RULE_ARN" --actions '[
  {
    "Type":"forward",
    "ForwardConfig":{
      "TargetGroups":[
        {"TargetGroupArn":"<PROD_TG_ARN>","Weight":100},
        {"TargetGroupArn":"<STAGING_TG_ARN>","Weight":0}
      ]
    }
  }
]'
```

Check target health:

```bash
aws elbv2 describe-target-health --target-group-arn "<PROD_TG_ARN>" --query "TargetHealthDescriptions[].TargetHealth.State"
```

**A4.2 Route53 cutover (DNS)**  
If you switch `api.example.com` to point to prod ALB:

```bash
cat > /tmp/route53-cutover.json <<JSON
{
  "Comment": "Cutover API to prod ALB",
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "${PROD_DOMAIN}",
      "Type": "CNAME",
      "TTL": 30,
      "ResourceRecords": [{ "Value": "${PROD_ALB_DNS}" }]
    }
  }]
}
JSON

aws route53 change-resource-record-sets   --hosted-zone-id "$HOSTED_ZONE_ID"   --change-batch file:///tmp/route53-cutover.json
```

> If you use an **ALIAS** (A record) to ALB instead of CNAME, use an “AliasTarget” structure (recommended). Keep TTL low during cutover.

#### A5) Post-cutover verification (prod)

```bash
# Backend health (prod URL)
curl -fsS "https://${PROD_DOMAIN}/health" && echo
curl -fsS "https://${PROD_DOMAIN}/line/health" && echo
curl -fsS "https://${PROD_DOMAIN}/odoo/health" && echo
```

If you store secrets in Secrets Manager, validate retrieval permissions:

```bash
aws secretsmanager get-secret-value --secret-id "<SECRET_ID_OR_ARN>" --query SecretString --output text | head
```

#### A6) Rollback (ECS + DNS)

Rollback is usually:
1) switch DNS/ALB weight back  
2) deploy previous task definition revision  
3) if DB migration happened, restore from snapshot (last resort)

```bash
# Roll back backend to previous task definition
aws ecs update-service --cluster "$ECS_CLUSTER" --service "$ECS_BACKEND_SVC"   --task-definition "<PREVIOUS_BACKEND_TASKDEF_ARN>" --force-new-deployment

aws ecs wait services-stable --cluster "$ECS_CLUSTER" --services "$ECS_BACKEND_SVC"
```

RDS restore (last resort — requires new instance identifier):

```bash
aws rds restore-db-instance-from-db-snapshot   --db-instance-identifier "${RDS_ID}-restore"   --db-snapshot-identifier "$RDS_SNAPSHOT_ID"
```

---

### Option B — AWS EC2 + Docker Compose + RDS

**Owner:** DevOps / Platform + Odoo Admin  
**ETA:** 60–150 min (depends on SSH + deploy method)

Assumptions:
- EC2 runs Docker Compose for backend + odoo, and connects to **RDS**.
- You have SSH access (SSM preferred) and a deployment directory.

#### B1) Verify instance + SSM connectivity

```bash
aws ec2 describe-instances --filters "Name=tag:Name,Values=line-odoo-prod"   --query "Reservations[].Instances[].{id:InstanceId,state:State.Name,ip:PublicIpAddress,az:Placement.AvailabilityZone}" --output table

# Preferred: SSM
aws ssm describe-instance-information --query "InstanceInformationList[].{id:InstanceId,ping:PingStatus,platform:PlatformName}" --output table
```

#### B2) DB snapshot (same as A1)

Use the same RDS snapshot commands from Option A (A1).

#### B3) Deploy on EC2 (example)

```bash
# If using SSM to run commands remotely (replace INSTANCE_ID):
aws ssm send-command   --instance-ids "<INSTANCE_ID>"   --document-name "AWS-RunShellScript"   --parameters commands='[
    "cd /opt/line-odoo",
    "docker compose pull",
    "docker compose up -d",
    "docker compose ps"
  ]'   --query "Command.CommandId" --output text
```

#### B4) Cutover traffic

Use Route53 commands (A4.2), or your existing LB / reverse proxy switch method.

---

## 🚨 Incident Playbooks (Fast Response)

> Keep this section open during cutover. Copy/paste commands are included.

### Incident 1 — LINE outage / webhook not delivering

**Symptoms**
- No events reaching backend; users report “menu does nothing”
- Backend logs show no webhook hits

**Immediate checks**
```bash
# Backend health
curl -fsS http://127.0.0.1:8000/health && echo
curl -fsS http://127.0.0.1:8000/line/health && echo

# If prod:
curl -fsS "https://${PROD_DOMAIN}/line/health" && echo
```

**Verify signature generation locally**
```bash
# Your existing helper (make sure JSON is minified EXACTLY as sent)
python3 scripts/line_make_signature.py  # (or the snippet in this runbook)
```

**Cloud-side checks (ECS)**
```bash
aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_BACKEND_SVC"   --query "services[0].events[0].message" --output text
aws logs tail "/ecs/line-odoo-backend" --since 15m --follow
```

**Mitigation / kill-switch**
- Enable “passive mode” (return 200 to LINE but do not write to DB) if available:
  - `CUTOVER_FREEZE_WRITES=1` (or your equivalent)
- Announce fallback channel (manual intake / hotline) to customers.

**Exit criteria**
- Webhook events visible in logs and test postback succeeds end-to-end.

---

### Incident 2 — Odoo down / 5xx / login loop

**Symptoms**
- `/web/login` fails, 5xx from ALB, Odoo UI inaccessible
- Backend `/odoo/health` fails or cannot authenticate

**Immediate checks**
```bash
# Odoo (local / staging)
curl -I http://localhost:8069/web/login

# Backend Odoo integration health
curl -fsS http://127.0.0.1:8000/odoo/health && echo
```

**ECS recovery**
```bash
# See if tasks are running
aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_ODOO_SVC"   --query "services[0].{desired:desiredCount,running:runningCount,events:events[0].message}" --output table

# Force a redeploy (restarts tasks)
aws ecs update-service --cluster "$ECS_CLUSTER" --service "$ECS_ODOO_SVC" --force-new-deployment
aws ecs wait services-stable --cluster "$ECS_CLUSTER" --services "$ECS_ODOO_SVC"

# Tail logs
aws logs tail "/ecs/line-odoo-odoo" --since 15m --follow
```

**ALB target health**
```bash
aws elbv2 describe-target-health --target-group-arn "<ODOO_TG_ARN>"   --query "TargetHealthDescriptions[].{id:Target.Id,state:TargetHealth.State,reason:TargetHealth.Reason}" --output table
```

**Mitigation**
- If Odoo is down but backend is up, set backend to **degrade gracefully**:
  - queue requests, or return “service temporarily unavailable” message to LINE
- If persistent, execute rollback to previous Odoo task definition.

**Exit criteria**
- Odoo UI loads, backend `/odoo/health` returns `ok:true` and `uid:true`.

---

### Incident 3 — DB locked / migrations stuck / long transactions

**Symptoms**
- Odoo install/upgrade hangs
- Backend requests time out
- Postgres shows lock waits

**Immediate checks (RDS)**
```bash
aws rds describe-db-instances --db-instance-identifier "$RDS_ID"   --query "DBInstances[0].{status:DBInstanceStatus,endpoint:Endpoint.Address}" --output table
aws cloudwatch get-metric-statistics   --namespace AWS/RDS --metric-name DatabaseConnections   --dimensions Name=DBInstanceIdentifier,Value="$RDS_ID"   --start-time "$(date -u -v-15M +%Y-%m-%dT%H:%M:%SZ)" --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)"   --period 60 --statistics Average
```

**Inspect locks (psql)**
```bash
# From a bastion or ECS task with psql installed (replace host/user/db)
psql "host=<RDS_ENDPOINT> port=5432 user=odoo dbname=<DBNAME> password=<PASSWORD>" -c "
SELECT now(), a.pid, a.usename, a.state, a.wait_event_type, a.wait_event, a.query
FROM pg_stat_activity a
WHERE a.datname = current_database()
ORDER BY a.query_start NULLS LAST
LIMIT 20;
"

psql "host=<RDS_ENDPOINT> port=5432 user=odoo dbname=<DBNAME> password=<PASSWORD>" -c "
SELECT blocked_locks.pid AS blocked_pid,
       blocking_locks.pid AS blocking_pid,
       blocked_activity.query AS blocked_query,
       blocking_activity.query AS blocking_query
FROM pg_locks blocked_locks
JOIN pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_locks blocking_locks
  ON blocking_locks.locktype = blocked_locks.locktype
 AND blocking_locks.DATABASE IS NOT DISTINCT FROM blocked_locks.DATABASE
 AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
 AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
 AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
 AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
 AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
 AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
 AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
 AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
 AND blocking_locks.pid != blocked_locks.pid
JOIN pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
"
```

**Mitigation**
- If a single blocking PID is identified, terminate it (careful!):
```sql
SELECT pg_terminate_backend(<blocking_pid>);
```
- If widespread and safe, temporarily scale down writers (backend) to stop new transactions:
```bash
aws ecs update-service --cluster "$ECS_CLUSTER" --service "$ECS_BACKEND_SVC" --desired-count 0
```
- If RDS is unhealthy: consider `reboot-db-instance` (last resort):
```bash
aws rds reboot-db-instance --db-instance-identifier "$RDS_ID"
```

**Exit criteria**
- No lock waits, normal latency returns, Odoo module operations complete.

---

## 🔐 Final Go / No-Go Gate


Cut-over **MUST NOT START** unless all below are ✅:

- [ ] UAT signed
- [ ] Prod DB snapshot completed
- [ ] Secrets rotated (not reused from staging)
- [ ] Rollback tested once in staging
- [ ] Business owner on-call during cut-over
- [ ] LINE webhook switch plan confirmed

---
