# End-to-end example: a walwarden BYO-S3 destination with SSE-KMS using a
# customer-managed KMS key.
#
# This example also creates the KMS key so `terraform apply` stands alone.
# If you already have a key, drop the aws_kms_key resource and pass its ARN
# as -var 'kms_key_arn=arn:aws:kms:...'.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region for the backup bucket and KMS key."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Globally-unique bucket name."
  type        = string
}

variable "external_id" {
  description = "walwarden-issued external ID from the dashboard destination shell."
  type        = string
}

# Customer-managed key for SSE-KMS. Omit this and pass an existing key ARN if
# you already manage one.
resource "aws_kms_key" "backups" {
  description             = "walwarden backup bucket SSE-KMS key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_alias" "backups" {
  name          = "alias/${var.bucket_name}-walwarden"
  target_key_id = aws_kms_key.backups.key_id
}

module "walwarden_destination" {
  # In real use, pin to the registry module:
  #   source  = "noncelogic/walwarden/aws"
  #   version = "~> 1.0"
  source = "../../"

  bucket_name = var.bucket_name
  external_id = var.external_id
  kms_key_arn = aws_kms_key.backups.arn
}

output "bucket_name" {
  value = module.walwarden_destination.bucket_name
}

output "role_arn" {
  value = module.walwarden_destination.role_arn
}

output "region" {
  value = module.walwarden_destination.region
}

output "kms_key_arn" {
  value = module.walwarden_destination.kms_key_arn
}
