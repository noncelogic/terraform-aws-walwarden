# Example: BYO-S3 destination (SSE-S3)

Minimal end-to-end Terraform for a walwarden AWS backup destination using
SSE-S3 (AES256) default encryption.

```sh
terraform init
terraform apply \
  -var 'bucket_name=my-company-walwarden-backups' \
  -var 'external_id=wal-...your-external-id...'
```

Then copy `bucket_name`, `region`, and `role_arn` from the outputs into the
walwarden dashboard destination form and run preflight.

The `kms_key_arn` output is `null` here — this example uses SSE-S3. See
[`../byo-s3-kms`](../byo-s3-kms) for the customer-managed-key variant.
