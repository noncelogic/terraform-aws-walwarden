output "bucket_arn" {
  description = "ARN of the backup bucket. Paste the bucket name (not the ARN) into the walwarden dashboard."
  value       = aws_s3_bucket.this.arn
}

output "bucket_name" {
  description = "Name of the backup bucket. This is the value the walwarden dashboard asks for."
  value       = aws_s3_bucket.this.bucket
}

output "role_arn" {
  description = "ARN of the IAM role walwarden assumes. Paste into the dashboard 'IAM role ARN' field."
  value       = aws_iam_role.this.arn
}

output "region" {
  description = "AWS region the bucket lives in. Paste into the dashboard 'Region' field."
  value       = aws_s3_bucket.this.region
}

output "kms_key_arn" {
  description = "KMS key ARN used for SSE-KMS, or null when the bucket uses SSE-S3 (AES256)."
  value       = var.kms_key_arn
}
