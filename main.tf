# walwarden BYO-S3 destination — single `terraform apply` that produces the
# exact resource set walwarden's preflight observer expects:
#
#   - S3 bucket with versioning + Object Lock (GOVERNANCE) + full
#     public-access-block + TLS-only bucket policy + default SSE
#     (SSE-S3 by default, SSE-KMS when kms_key_arn is supplied)
#   - IAM role + policy with the exact actions preflight/backup/restore use
#   - Role trust policy locked to the walwarden account + this destination's
#     external_id, so AssumeRole without the external_id is rejected
#     (the `external_id_enforced` preflight check).
#
# Keep this aligned with:
#   apps/web/src/server/services/awsLivePreflightObserver.ts
#   apps/docs/public/docs/destinations/byo-aws-s3.md
#   packages/core/src/preflight.ts (REQUIRED_PREFLIGHT_CHECKS)

locals {
  # walwarden's AWS account. The trust policy lists this account's root as the
  # only principal allowed to assume the destination role. Sourced from
  # apps/docs/public/docs/destinations/byo-aws-s3.md.
  walwarden_account_id = "194343789105"

  use_kms = var.kms_key_arn != null

  bucket_arn = "arn:aws:s3:::${var.bucket_name}"
}

# --- S3 bucket -------------------------------------------------------------

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name

  # Object Lock can only be turned on at bucket creation. AWS also enables
  # versioning implicitly, but we set it explicitly below so preflight's
  # versioning_enabled check is unambiguous.
  object_lock_enabled = true

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_object_lock_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    default_retention {
      # GOVERNANCE, never COMPLIANCE: walwarden requires governance-mode so
      # GDPR right-to-erasure deletion stays possible. See
      # docs/decisions/0005-object-lock-governance-mode-only.md.
      mode = "GOVERNANCE"
      days = var.object_lock_retention_days
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  # All four must be true — preflight rejects partial blocking.
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.use_kms ? "aws:kms" : "AES256"
      kms_master_key_id = local.use_kms ? var.kms_key_arn : null
    }
    bucket_key_enabled = local.use_kms
  }
}

# TLS-only bucket policy: deny any request made over plain HTTP. Matches the
# `tls_only_policy` preflight check (Deny + Bool aws:SecureTransport=false).
data "aws_iam_policy_document" "tls_only" {
  statement {
    sid    = "DenyNonTLS"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      local.bucket_arn,
      "${local.bucket_arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tls_only" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.tls_only.json

  # The public-access-block's block_public_policy can reject a bucket policy
  # mid-apply if ordering races; depend on it explicitly.
  depends_on = [aws_s3_bucket_public_access_block.this]
}

# --- IAM role + policy -----------------------------------------------------

# Trust policy: only the walwarden account, and only when it presents this
# destination's external_id. AssumeRole without the external_id is denied,
# which is exactly what the `external_id_enforced` preflight probe asserts.
data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "WalwardenAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.walwarden_account_id}:root"]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.external_id]
    }
  }
}

# Backup + preflight + restore-presign permissions. This is the same role used
# for restore URL signing, so s3:GetObject is required — least privilege comes
# from the dedicated bucket, the external_id trust condition, and the Object
# Lock / TLS / public-access controls, not from denying reads. Mirrors the
# policy in apps/docs/public/docs/destinations/byo-aws-s3.md step 3.
data "aws_iam_policy_document" "backup" {
  statement {
    sid    = "WalwardenBackupRW"
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:HeadObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:PutObjectRetention",
      "s3:PutObjectLegalHold",
      "s3:GetObjectRetention",
      "s3:GetObjectLegalHold",
      "s3:GetObjectVersion",
      "s3:ListBucketVersions",
      "s3:GetBucketObjectLockConfiguration",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketPolicy",
      "s3:AbortMultipartUpload",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts",
    ]

    resources = [
      local.bucket_arn,
      "${local.bucket_arn}/*",
    ]
  }

  # KMS permissions only when the bucket is SSE-KMS. Preflight runs a
  # kms:Encrypt canary against the supplied key under the assumed role.
  dynamic "statement" {
    for_each = local.use_kms ? [1] : []

    content {
      sid    = "WalwardenKmsUse"
      effect = "Allow"

      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey",
      ]

      resources = [var.kms_key_arn]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "backup" {
  name   = "walwarden-backup-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.backup.json
}
