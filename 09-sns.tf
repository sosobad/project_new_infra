# ============================================================
# SNS Topic
# Alertmanager -> SNS -> Gmail
# ============================================================

resource "aws_sns_topic" "alerts" {
  name = "msa-platform-alerts"

  tags = {
    Name      = "msa-platform-alerts"
    Project   = "msa-platform"
    ManagedBy = "Terraform"
  }
}

# ============================================================
# SNS Email Subscription
# ============================================================

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ============================================================
# Output
# ============================================================

output "sns_topic_arn" {
  description = "SNS topic ARN for Alertmanager"
  value       = aws_sns_topic.alerts.arn
}