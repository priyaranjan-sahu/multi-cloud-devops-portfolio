# Terraform Security Module
# This module provides secure-by-default configurations for AWS resources

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

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "devops-portfolio"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs"
  type        = list(string)
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Repository  = "multi-cloud-devops-portfolio"
  }
}

# ===========================================
# IAM - Secure Roles and Policies
# ===========================================

resource "aws_iam_role" "ec2_instance_role" {
  name = "${local.name_prefix}-ec2-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
  tags = local.tags
}

resource "aws_iam_policy" "ec2_instance_policy" {
  name = "${local.name_prefix}-ec2-instance-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/${local.name_prefix}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${local.name_prefix}-*",
          "arn:aws:s3:::${local.name_prefix}-*/*"
        ]
      }
    ]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ec2_instance" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.ec2_instance_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance" {
  name = "${local.name_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2_instance_role.name
}

# Lambda execution role with least privilege
resource "aws_iam_role" "lambda_execution" {
  name = "${local.name_prefix}-lambda-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
  tags = local.tags
}

resource "aws_iam_policy" "lambda_basic_execution" {
  name = "${local.name_prefix}-lambda-basic"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_basic_execution.arn
}

# ===========================================
# KMS - Encryption Keys
# ===========================================

resource "aws_kms_key" "s3_encryption" {
  description             = "${local.name_prefix} S3 encryption key"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  tags                    = local.tags
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Allow administration"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:EncryptionContext:aws:s3:arn" = "arn:aws:s3:::${local.name_prefix}-*"
          }
        }
      }
    ]
  })
}

resource "aws_kms_alias" "s3_encryption" {
  name          = "alias/${local.name_prefix}-s3"
  target_key_id = aws_kms_key.s3_encryption.key_id
}

resource "aws_kms_key" "ebs_encryption" {
  description             = "${local.name_prefix} EBS encryption key"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  tags                    = local.tags
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Allow administration"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EC2 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "ebs_encryption" {
  name          = "alias/${local.name_prefix}-ebs"
  target_key_id = aws_kms_key.ebs_encryption.key_id
}

# ===========================================
# Security Groups - Least Privilege
# ===========================================

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${local.name_prefix}-alb-sg" })
}

resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "Security group for application instances"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = ["10.0.0.0/8"]  # Restrict to VPC CIDR
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${local.name_prefix}-app-sg" })
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for RDS instances"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  tags = merge(local.tags, { Name = "${local.name_prefix}-rds-sg" })
}

resource "aws_security_group" "redis" {
  name        = "${local.name_prefix}-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  tags = merge(local.tags, { Name = "${local.name_prefix}-redis-sg" })
}

# ===========================================
# S3 - Secure Bucket Configuration
# ===========================================

resource "aws_s3_bucket" "app" {
  bucket = "${local.name_prefix}-${random_id.suffix.hex}-app"
  tags   = local.tags
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "app" {
  bucket = aws_s3_bucket.app.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "app" {
  bucket = aws_s3_bucket.app.id
  rule {
    id     = "expire-incomplete-multipart-uploads"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
  rule {
    id     = "transition-to-glacier"
    status = "Enabled"
    filter {
      prefix = "archive/"
    }
    transition {
      days          = 30
      storage_class = "GLACIER"
    }
  }
  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# ===========================================
# CloudTrail - Audit Logging
# ===========================================

resource "aws_cloudtrail" "main" {
  name                          = "${local.name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.app.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.s3_encryption.arn
  tags                          = local.tags
}

# ===========================================
# Config - Compliance
# ===========================================

resource "aws_config_configuration_recorder" "main" {
  name     = "${local.name_prefix}-recorder"
  role_arn = aws_iam_role.config.arn
  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_iam_role" "config" {
  name = "${local.name_prefix}-config-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "config.amazonaws.com"
      }
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "config" {
  name = "${local.name_prefix}-config-policy"
  role = aws_iam_role.config.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "config:Put*",
        "config:Get*",
        "config:Describe*",
        "config:Delete*",
        "config:Start*",
        "config:Stop*",
        "config:BatchGet*",
        "config:List*"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_config_delivery_channel" "main" {
  name           = "${local.name_prefix}-channel"
  s3_bucket_name = aws_s3_bucket.app.id
  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }
}

# ===========================================
# GuardDuty - Threat Detection
# ===========================================

resource "aws_guardduty_detector" "main" {
  enable = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  tags = local.tags
}

resource "aws_guardduty_member" "main" {
  detector_id = aws_guardduty_detector.main.id
  account_id  = data.aws_caller_identity.current.account_id
  email       = "security@example.com"
}

# ===========================================
# VPC Flow Logs
# ===========================================

resource "aws_flow_log" "vpc" {
  vpc_id            = var.vpc_id
  traffic_type      = "ALL"
  log_destination   = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn      = aws_iam_role.flow_logs.arn
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flowlogs/${local.name_prefix}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.s3_encryption.arn
  tags              = local.tags
}

resource "aws_iam_role" "flow_logs" {
  name = "${local.name_prefix}-flow-logs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${local.name_prefix}-flow-logs-policy"
  role = aws_iam_role.flow_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

# ===========================================
# Data Sources
# ===========================================

data "aws_caller_identity" "current" {}

# ===========================================
# Outputs
# ===========================================

output "ec2_instance_profile_name" {
  value = aws_iam_instance_profile.ec2_instance.name
}

output "lambda_execution_role_arn" {
  value = aws_iam_role.lambda_execution.arn
}

output "kms_s3_key_arn" {
  value = aws_kms_key.s3_encryption.arn
}

output "kms_ebs_key_arn" {
  value = aws_kms_key.ebs_encryption.arn
}

output "security_group_alb_id" {
  value = aws_security_group.alb.id
}

output "security_group_app_id" {
  value = aws_security_group.app.id
}

output "security_group_rds_id" {
  value = aws_security_group.rds.id
}

output "security_group_redis_id" {
  value = aws_security_group.redis.id
}

output "s3_bucket_name" {
  value = aws_s3_bucket.app.id
}

output "cloudtrail_name" {
  value = aws_cloudtrail.main.name
}

output "guardduty_detector_id" {
  value = aws_guardduty_detector.main.id
}