terraform {
  # Pinned to a major version range that walwarden's preflight observer can
  # support. If preflight's required resource set changes (see
  # apps/web/src/server/services/awsLivePreflightObserver.ts and
  # packages/core/src/preflight.ts REQUIRED_PREFLIGHT_CHECKS), this module
  # bumps its own MAJOR version so consumers pinned to `~> 1.0` are not
  # silently broken by a preflight contract change.
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
  }
}
