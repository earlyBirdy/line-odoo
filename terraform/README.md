# Terraform scaffold

This folder provides a deployable scaffold (modules + env folders) that matches the `docs/AWS_MAPPING_ECS_EC2_RDS.md`
and `docs/TERRAFORM_RESOURCES.md` documents.

## Layout
- `modules/`: reusable building blocks
- `envs/dev|stg|prod`: environment compositions (backend remote state + module wiring)

## Quick start (example: dev)
1) Create an S3 bucket + DynamoDB table for Terraform state/locking (see `envs/dev/remote_state.bootstrap.md`)
2) Edit `envs/dev/backend.tf` to point to your bucket/table
3) Set variables in `envs/dev/dev.tfvars`
4) Run:
```bash
cd terraform/envs/dev
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

## Notes
- This scaffold is intentionally conservative: private subnets for ECS tasks and RDS, public subnets for ALB.
- Secrets should be stored in AWS Secrets Manager and injected to ECS tasks; see `modules/secrets`.
