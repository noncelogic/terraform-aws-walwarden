variable "bucket_name" {
  description = "Globally-unique name for the S3 bucket walwarden writes backups to. Example: my-company-walwarden-backups."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be 3-63 chars, lowercase letters, numbers, dots, and hyphens, and start/end alphanumeric."
  }
}

variable "external_id" {
  description = "The walwarden-issued sts:ExternalId for this destination. Generate the destination shell in the walwarden dashboard first, then paste the external_id here. Do NOT use a placeholder — preflight rejects placeholder values."
  type        = string

  validation {
    condition     = length(var.external_id) > 0 && var.external_id != "your-external-id-here"
    error_message = "external_id must be the walwarden-issued value (typically starts with 'wal-'), not empty or a placeholder."
  }
}

variable "role_name" {
  description = "Name for the IAM role walwarden assumes. Defaults to walwarden-backup-role."
  type        = string
  default     = "walwarden-backup-role"
}

variable "object_lock_retention_days" {
  description = "Default Object Lock (GOVERNANCE) retention in days. Must be >= the retention floor configured for the destination in walwarden. AWS minimum recommendation is 30."
  type        = number
  default     = 30

  validation {
    condition     = var.object_lock_retention_days >= 1
    error_message = "object_lock_retention_days must be at least 1."
  }
}

variable "kms_key_arn" {
  description = "Optional customer-managed KMS key ARN. When set, the bucket uses SSE-KMS with this key and the role is granted kms:Encrypt/Decrypt/GenerateDataKey on it. Leave null for SSE-S3 (AES256)."
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:aws[a-z-]*:kms:", var.kms_key_arn))
    error_message = "kms_key_arn must be a KMS key ARN (arn:aws:kms:...) or null."
  }
}

variable "tags" {
  description = "Extra tags applied to all created resources."
  type        = map(string)
  default     = {}
}
