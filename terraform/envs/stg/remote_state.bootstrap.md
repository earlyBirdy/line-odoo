# Remote state bootstrap (one-time)

Terraform needs:
- S3 bucket for state
- DynamoDB table for state locking

Create them once per environment, for example:
- bucket: `stg-<org>-tfstate-bucket`
- table: `stg-<org>-tflock`

Minimum DynamoDB schema:
- Partition key: `LockID` (String)

Enable:
- S3 bucket versioning
- S3 default encryption
- Block public access

Then update `backend.tf` with the real bucket/table names.
