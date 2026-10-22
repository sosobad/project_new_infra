# ============================================================
# Alertmanager -> SNS IRSA
# ============================================================

# ------------------------------------------------------------
# IAM Policy
# Alertmanager가 SNS Topic에 Publish할 수 있도록 허용
# ------------------------------------------------------------
resource "aws_iam_policy" "alertmanager_sns" {
  name = "MSAPlatformAlertmanagerSNSPolicy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })

  tags = {
    Name = "MSAPlatformAlertmanagerSNSPolicy"
  }
}


# ------------------------------------------------------------
# IAM Role
# monitoring namespace의 Alertmanager ServiceAccount만
# 이 Role을 Assume할 수 있도록 허용
# ------------------------------------------------------------
resource "aws_iam_role" "alertmanager_sns" {
  name = "MSAPlatformAlertmanagerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"

            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:monitoring:kube-prometheus-stack-alertmanager"
          }
        }
      }
    ]
  })

  tags = {
    Name = "MSAPlatformAlertmanagerRole"
  }
}


# ------------------------------------------------------------
# IAM Policy -> IAM Role 연결
# ------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "alertmanager_sns" {
  role       = aws_iam_role.alertmanager_sns.name
  policy_arn = aws_iam_policy.alertmanager_sns.arn
}