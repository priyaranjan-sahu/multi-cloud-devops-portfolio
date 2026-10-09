# =============================================================================
# Terraform Remote State Bootstrap
# =============================================================================
# Creates the S3 bucket and DynamoDB table used for Terraform remote state and
# state locking. Run this ONCE per account/region before switching any module
# to the S3 backend (see ../../multi-cloud-infra/terraform-aws/backend.tf.remote.example).
#
#   cd multi-cloud-infra/terraform-bootstrap
#   terraform init
#   terraform apply -var="state_bucket_name=my-tf-state"
#
# This module intentionally uses the LOCAL backend - it is the bootstrap layer.
# =============================================================================

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "aws_region" {
  description = "AWS region for the state bucket and lock table"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "devops-portfolio"
}

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name for Terraform state (leave empty to auto-generate)"
  type        = string
  default     = ""
}

locals {
  bucket_name = var.state_bucket_name != "" ? var.state_bucket_name : "${var.project_name}-tfstate-${random_id.suffix.hex}"
  tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
    Purpose   = "terraform-remote-state"
  }
}

provider "aws" {
  region = var.aws_region
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "state" {
  bucket        = local.bucket_name
  force_destroy = false
  tags          = local.tags
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    id     = "expire-noncurrent-state"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_dynamodb_table" "lock" {
  name         = "${var.project_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = local.tags
}

output "state_bucket_name" {
  description = "S3 bucket to use as the Terraform backend bucket"
  value       = aws_s3_bucket.state.id
}

output "lock_table_name" {
  description = "DynamoDB table to use for state locking"
  value       = aws_dynamodb_table.lock.name
}

output "backend_config_hint" {
  description = "Values to place in backend.tf"
  value       = <<-EOT
    bucket         = "${aws_s3_bucket.state.id}"
    key            = "terraform-aws/terraform.tfstate"
    region         = "${var.aws_region}"
    encrypt        = true
    dynamodb_table = "${aws_dynamodb_table.lock.name}"
  EOT
}
