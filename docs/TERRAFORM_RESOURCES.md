# Terraform Resources – Ops-Grade (Final)

This document is the **authoritative Terraform inventory** for the `line-odoo` stack.
It reflects the **latest ops-hardening**:
- GitHub OIDC deploy (no static AWS keys)
- HTTPS-only ALB with WAF
- Route53 + ACM DNS validation
- Separate ALB / WAF log buckets
- TLS-only S3 policies
- WAF logs encrypted with **dedicated KMS CMK**
- **Firehose stream–scoped least-privilege KMS policies**

---

## Naming Convention

```
{project}-{env}-{component}
```

Tags (applied to all resources):
```
Project     = "line-odoo"
Environment = "dev|stg|prod"
ManagedBy   = "terraform"
Owner       = "platform"
```

---

## Network
- VPC with public (ALB) and private (ECS/RDS/Redis/EFS) subnets
- IGW + NAT (stg/prod)

## Load Balancer (ALB)
- HTTP → HTTPS redirect
- HTTPS listener with ACM cert
- Path routing to backend / odoo
- Access logs → `{project}-{env}-alb-logs/alb/{env}` (SSE-S3, TLS-only)

⚠️ ALB does not support SSE-KMS

## DNS & TLS
- Route53 alias records
- ACM cert with DNS validation (Terraform-managed)

## WAF
- AWS managed rules
- Rate limit on `/line/webhook`
- Logs → Firehose → `{project}-{env}-waf-logs/waf/{env}`
- Redaction: auth, cookies, x-line-signature

## WAF KMS (Least Privilege)
- Dedicated CMK per env
- Key policy restricted to:
  - Firehose delivery role
  - Via S3 service
  - Encryption context bucket/prefix
  - Optional SourceArn check

## Compute
- ECS Fargate cluster
- Backend + Odoo services
- OIDC-based GitHub Actions deploy role

## Data
- RDS Postgres (encrypted)
- Redis
- EFS (encrypted)

## Logging Summary

| Component | Bucket | Encryption |
|---------|--------|------------|
| ALB | `*-alb-logs` | SSE-S3 |
| WAF | `*-waf-logs` | SSE-KMS |
| Firehose | CloudWatch | AWS-managed |

---

Status: **Production-ready**
