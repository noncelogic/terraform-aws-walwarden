# terraform-aws-walwarden

Terraform module that provisions a complete **walwarden BYO-S3 backup destination** on AWS in one `terraform apply` — S3 bucket, Object Lock, encryption, public-access block, TLS-only policy, and the IAM role with the exact trust policy walwarden's preflight expects. No hand-editing of the IAM role trust policy in the console.

Registry: `noncelogic/walwarden/aws`

## Usage

```hcl
module "walwarden_destination" {
  source  = "noncelogic/walwarden/aws"
  version = "~> 1.0"

  bucket_name = "my-company-walwarden-backups"
  external_id = "wal-...your-destination-external-id..."
}
```

1. In the walwarden dashboard, go to **Destinations → Add destination** and create the destination shell. Copy the generated **external ID** (`wal-...`).
2. Call this module with that `external_id` and a globally-unique `bucket_name`.
3. `terraform apply`.
4. Paste the outputs (`bucket_name`, `region`, `role_arn`, and `kms_key_arn` if you used KMS) into the walwarden dashboard destination form and save.
5. Run preflight from the destination detail page — it passes on the first try.

See [`examples/byo-s3-basic`](examples/byo-s3-basic) and [`examples/byo-s3-kms`](examples/byo-s3-kms).

## What it creates

- **S3 bucket** with: versioning; Object Lock in **GOVERNANCE** mode (never COMPLIANCE — governance-mode keeps GDPR right-to-erasure deletion possible); configurable default retention; all four public-access-block settings on; a TLS-only bucket policy; default encryption SSE-S3 (AES256), or SSE-KMS when `kms_key_arn` is supplied.
- **IAM role** with the exact backup/preflight/restore policy walwarden uses, and a trust policy that allows **only** the walwarden account (`arn:aws:iam::194343789105:root`) to assume it, and **only** when it presents your destination's `external_id`.

`terraform plan` produces exactly this set with no surprise diffs.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `bucket_name` | string | — | Globally-unique S3 bucket name. |
| `external_id` | string | — | walwarden-issued `sts:ExternalId` for this destination. Not a placeholder — preflight rejects placeholder values. |
| `role_name` | string | `walwarden-backup-role` | Name for the IAM role walwarden assumes. |
| `object_lock_retention_days` | number | `30` | Default Object Lock (GOVERNANCE) retention in days; must be ≥ the destination's retention floor. |
| `kms_key_arn` | string | `null` | Optional customer-managed KMS key ARN. When set, the bucket uses SSE-KMS and the role is granted `kms:Encrypt`/`Decrypt`/`GenerateDataKey` on it. Leave null for SSE-S3. |
| `tags` | map(string) | `{}` | Extra tags applied to all created resources. |

## Outputs

| Name | Description |
|------|-------------|
| `bucket_name` | Name of the backup bucket — the value the dashboard asks for. |
| `bucket_arn` | ARN of the backup bucket. |
| `role_arn` | ARN of the IAM role walwarden assumes — paste into the dashboard. |
| `region` | AWS region the bucket lives in. |
| `kms_key_arn` | KMS key ARN used for SSE-KMS, or null when using SSE-S3. |

## Versioning

This module is pinned to walwarden's preflight contract. If preflight's required resource set changes, the module bumps a **major** version — pin `version = "~> 1.0"` and review release notes before crossing a major.

## License

[MIT](LICENSE)
