# AWS GuardDuty - Threat Detection Configuration
# This module enables and configures GuardDuty with best practices

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
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

variable "enable_guardduty" {
  description = "Enable GuardDuty"
  type        = bool
  default     = true
}

variable "finding_publishing_frequency" {
  description = "Frequency of finding updates"
  type        = string
  default     = "FIFTEEN_MINUTES"
}

variable "s3_bucket_name" {
  description = "S3 bucket for exporting findings"
  type        = string
  default     = ""
}

variable "auto_enable_organization_members" {
  description = "Auto-enable for organization members"
  type        = bool
  default     = false
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
# GuardDuty Detector
# ===========================================

resource "aws_guardduty_detector" "main" {
  count = var.enable_guardduty ? 1 : 0

  enable                       = true
  finding_publishing_frequency = var.finding_publishing_frequency
  tags                         = local.tags
}

# ===========================================
# GuardDuty S3 Protection (if bucket provided)
# ===========================================

resource "aws_guardduty_detector_feature" "s3_protection" {
  count = var.enable_guardduty && var.s3_bucket_name != "" ? 1 : 0

  detector_id = aws_guardduty_detector.main[0].id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "eks_protection" {
  count = var.enable_guardduty ? 1 : 0

  detector_id = aws_guardduty_detector.main[0].id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "lambda_protection" {
  count = var.enable_guardduty ? 1 : 0

  detector_id = aws_guardduty_detector.main[0].id
  name        = "LAMBDA_NETWORK_LOGS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "malware_protection" {
  count = var.enable_guardduty ? 1 : 0

  detector_id = aws_guardduty_detector.main[0].id
  name        = "EBS_MALWARE_PROTECTION"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "rds_protection" {
  count = var.enable_guardduty ? 1 : 0

  detector_id = aws_guardduty_detector.main[0].id
  name        = "RDS_LOGIN_EVENTS"
  status      = "ENABLED"
}

# ===========================================
# GuardDuty IP Sets (Threat Intelligence)
# ===========================================

resource "aws_guardduty_ipset" "threat_intel" {
  count = var.enable_guardduty ? 1 : 0

  detector_id = aws_guardduty_detector.main[0].id
  name        = "${local.name_prefix}-threat-intel"
  format      = "TXT"
  location    = "https://raw.githubusercontent.com/stamparm/ipsum/master/ipsum.txt"
  activate    = true
  tags        = local.tags
}

# ===========================================
# GuardDuty Threat Intel Sets
# ===========================================

resource "aws_guardduty_threatintelset" "main" {
  count = var.enable_guardduty ? 1 : 0

  detector_id = aws_guardduty_detector.main[0].id
  name        = "${local.name_prefix}-threat-intel-set"
  format      = "TXT"
  location    = "https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset"
  activate    = true
  tags        = local.tags
}

# ===========================================
# GuardDuty Publishing Destination (S3 Export)
# ===========================================

resource "aws_guardduty_publishing_destination" "s3" {
  count = var.enable_guardduty && var.s3_bucket_name != "" ? 1 : 0

  detector_id      = aws_guardduty_detector.main[0].id
  destination_arn  = "arn:aws:s3:::${var.s3_bucket_name}"
  kms_key_arn      = aws_kms_key.guardduty[0].arn
  destination_type = "S3"
}

# KMS Key for GuardDuty S3 Export
resource "aws_kms_key" "guardduty" {
  count = var.enable_guardduty && var.s3_bucket_name != "" ? 1 : 0

  description             = "${local.name_prefix} GuardDuty export key"
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
        Sid    = "Allow GuardDuty to use the key"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
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

# ===========================================
# GuardDuty Filter Rules (Suppress Common False Positives)
# ===========================================

resource "aws_guardduty_filter" "suppress_known_scanners" {
  count = var.enable_guardduty ? 1 : 0

  detector_id = aws_guardduty_detector.main[0].id
  name        = "suppress-known-scanners"
  description = "Suppress findings from known security scanners"
  action      = "ARCHIVE"
  finding_criteria {
    criterion {
      field  = "service.action.networkConnectionAction.remoteIpDetails.ipAddressV4"
      equals = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    }
  }
  rank = 1
  tags = local.tags
}

resource "aws_guardduty_filter" "suppress_internal_port_scans" {
  count = var.enable_guardduty ? 1 : 0

  detector_id = aws_guardduty_detector.main[0].id
  name        = "suppress-internal-port-scans"
  description = "Suppress internal port scanning findings"
  action      = "ARCHIVE"
  finding_criteria {
    criterion {
      field  = "type"
      equals = ["Recon:EC2/Portscan"]
    }
  }
  rank = 2
  tags = local.tags
}

# ===========================================
# CloudWatch Metric Filter for GuardDuty
# ===========================================

resource "aws_cloudwatch_log_group" "guardduty" {
  count = var.enable_guardduty ? 1 : 0

  name              = "/aws/guardduty/${local.name_prefix}"
  retention_in_days = 90
  tags              = local.tags
}

resource "aws_cloudwatch_metric_filter" "guardduty_high_severity" {
  count = var.enable_guardduty ? 1 : 0

  name           = "${local.name_prefix}-guardduty-high"
  log_group_name = aws_cloudwatch_log_group.guardduty[0].name
  pattern        = "{ $.severity >= 7 }"
  metric_transformation {
    name      = "GuardDutyHighSeverityFindings"
    namespace = "Security/GuardDuty"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_filter" "guardduty_medium_severity" {
  count = var.enable_guardduty ? 1 : 0

  name           = "${local.name_prefix}-guardduty-medium"
  log_group_name = aws_cloudwatch_log_group.guardduty[0].name
  pattern        = "{ $.severity >= 4 && $.severity < 7 }"
  metric_transformation {
    name      = "GuardDutyMediumSeverityFindings"
    namespace = "Security/GuardDuty"
    value     = "1"
  }
}

# ===========================================
# CloudWatch Alarms for GuardDuty
# ===========================================

resource "aws_cloudwatch_metric_alarm" "guardduty_high" {
  count = var.enable_guardduty ? 1 : 0

  alarm_name          = "${local.name_prefix}-guardduty-high-severity"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "GuardDutyHighSeverityFindings"
  namespace           = "Security/GuardDuty"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "High severity GuardDuty finding detected"
  alarm_actions       = [aws_sns_topic.guardduty[0].arn]
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "guardduty_medium" {
  count = var.enable_guardduty ? 1 : 0

  alarm_name          = "${local.name_prefix}-guardduty-medium-severity"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "GuardDutyMediumSeverityFindings"
  namespace           = "Security/GuardDuty"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Multiple medium severity GuardDuty findings detected"
  alarm_actions       = [aws_sns_topic.guardduty[0].arn]
  tags                = local.tags
}

# ===========================================
# SNS Topic for Alerts
# ===========================================

resource "aws_sns_topic" "guardduty" {
  count = var.enable_guardduty ? 1 : 0

  name = "${local.name_prefix}-guardduty-alerts"
  tags = local.tags
}

resource "aws_sns_topic_subscription" "email" {
  count = var.enable_guardduty ? 1 : 0

  topic_arn = aws_sns_topic.guardduty[0].arn
  protocol  = "email"
  endpoint  = "security@example.com"
}

# ===========================================
# GuardDuty Organization Configuration (for multi-account)
# ===========================================

resource "aws_guardduty_organization_configuration" "main" {
  count = var.enable_guardduty && var.auto_enable_organization_members ? 1 : 0

  detector_id                      = aws_guardduty_detector.main[0].id
  auto_enable_organization_members = "ALL"
}

# ===========================================
# Data Sources
# ===========================================

data "aws_caller_identity" "current" {}

# ===========================================
# Outputs
# ===========================================

output "detector_id" {
  value = var.enable_guardduty ? aws_guardduty_detector.main[0].id : null
}

output "detector_arn" {
  value = var.enable_guardduty ? aws_guardduty_detector.main[0].arn : null
}

output "publishing_destination_arn" {
  value = var.enable_guardduty && var.s3_bucket_name != "" ? aws_guardduty_publishing_destination.s3[0].id : null
}

output "sns_topic_arn" {
  value = var.enable_guardduty ? aws_sns_topic.guardduty[0].arn : null
}