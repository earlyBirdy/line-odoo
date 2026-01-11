# Security Policy

This document defines the **security posture, responsibilities, and controls**
for the **GoodCan – LINE OA × Odoo Platform**.

It is aligned with:
- UAT Execution Worksheet
- Enterprise Readiness Matrix
- Terraform-managed infrastructure
- Staging → Production promotion gates

---

## 1. Security Scope

This policy covers:

- LINE Official Account webhook handling
- Backend API (FastAPI)
- Odoo Community (ERP)
- Supporting services (Redis, Postgres)
- AWS infrastructure (ALB, WAF, ECS, RDS, S3, KMS)

Out of scope:
- End-user mobile device security
- LINE platform internal security

---

## 2. Environment Separation

| Environment | Purpose | Rules |
|---|---|---|
| Local | Development | No real secrets, no real LINE OA |
| Staging | Validation / UAT | Real LINE OA, limited data |
| Production | Live service | Strict change control |

Rules:
- **No data sharing** between environments
- Separate LINE OA per environment
- Separate databases per environment

---

## 3. Identity & Authentication

### 3.1 LINE Webhook
- LINE signature verification is **mandatory**
- Invalid signatures are rejected immediately
- Replay protection handled via idempotency

### 3.2 Backend → Odoo
- JSON-RPC authentication using a **dedicated technical user**
- Least-privilege Odoo access
- No admin credentials in backend

### 3.3 Infrastructure Access
- GitHub Actions uses **OIDC**
- No long-lived AWS access keys
- IAM policies are least-privilege

---

## 4. Secrets Management

| Secret | Location | Rotation |
|---|---|---|
| LINE Channel Secret | `.env` / secret store | Before prod |
| LINE Access Token | `.env` / secret store | Before prod |
| Odoo credentials | `.env` / secret store | As needed |
| AWS credentials | OIDC only | N/A |

Rules:
- Secrets **must not** be committed to git
- `.env` files are ignored
- Rotation required before production

---

## 5. Network & Transport Security

- HTTPS enforced at ALB (TLS 1.2+)
- WAF enabled with managed rules
- HTTP → HTTPS redirect enforced
- Internal service traffic isolated by security groups

---

## 6. Data Protection

### 6.1 Data at Rest
- RDS encrypted
- S3 encrypted with KMS
- Separate KMS keys for:
  - ALB logs
  - WAF logs

### 6.2 Data in Transit
- TLS for external traffic
- Internal traffic restricted to VPC

---

## 7. Logging & Monitoring

Logged:
- LINE webhook requests (metadata only)
- Authentication failures
- Backend errors
- WAF blocks
- ALB access logs

Not logged:
- Message content beyond business need
- Sensitive personal data

Logs are:
- Centralized
- Immutable
- Retained per policy

---

## 8. Vulnerability Handling

### Reporting
Security issues should be reported privately to:
- Project owner
- Security contact

Do **not** open public issues for vulnerabilities.

### Response
- Severity assessed within 24 hours
- Fix applied in staging
- UAT regression executed
- Promoted to production

---

## 9. Incident Response

If a security incident occurs:

1. Contain (disable webhook / revoke token)
2. Assess scope (logs, timestamps)
3. Eradicate (fix root cause)
4. Recover (restore service)
5. Postmortem (document lessons)

Incident response procedures are tracked in the **Operational Readiness sheet**.

---

## 10. Security Validation & Go-Live Gate

Production deployment is allowed **only if**:

- All UAT cases = PASS
- Failure cases executed
- Security-related UAT cases pass
- Readiness Matrix shows:
  - Security = Done
  - Operations = Done
- Business + Ops sign-off obtained

---

## 11. Change Management

Security-impacting changes require:
- Peer review
- Updated UAT if behavior changes
- Updated readiness status

No direct production changes are allowed.

---

## 12. Acknowledgement

By contributing to or operating this system, you agree to follow
this security policy and escalation process.

---

**Status:** Active  
**Applies to:** Staging and Production
