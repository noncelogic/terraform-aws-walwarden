# End-to-end example: a walwarden BYO-S3 destination with SSE-S3 (AES256).
#
# Flow:
#   1. Create the destination shell in the walwarden dashboard, copy its
#      external_id.
#   2. terraform apply -var 'bucket_name=...' -var 'external_id=wal-...'
#   3. Paste the outputs into the dashboard and run preflight.

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
  description = "AWS region for the backup bucket."
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

module "walwarden_destination" {
  # In real use, pin to the registry module:
  #   source  = "noncelogic/walwarden/aws"
  #   version = "~> 1.0"
  source = "../../"

  bucket_name = var.bucket_name
  external_id = var.external_id
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
