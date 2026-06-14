# Example: BYO-S3 destination (SSE-KMS)

End-to-end Terraform for a walwarden AWS backup destination using SSE-KMS with
a customer-managed KMS key. This example creates the key for you; to reuse an
existing key, remove the `aws_kms_key`/`aws_kms_alias` resources and pass the
key ARN through to the module instead.

```sh
terraform init
terraform apply \
  -var 'bucket_name=my-company-walwarden-backups' \
  -var 'external_id=wal-...your-external-id...'
```

Copy `bucket_name`, `region`, `role_arn`, **and** `kms_key_arn` from the
outputs into the walwarden dashboard destination form, then run preflight.
Preflight runs a `kms:Encrypt` canary against the key under the assumed role,
which the module's IAM policy permits.
