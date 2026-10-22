# ============================================================
# External Secrets Operator -> AWS Secrets Manager IRSA
# ============================================================

# 현재 AWS Provider Region 조회
data "aws_region" "current" {}


# ------------------------------------------------------------
# IAM Policy
# External Secrets가 msa-platform/* Secret을 읽을 수 있도록 허용
# ------------------------------------------------------------
resource "aws_iam_policy" "external_secrets" {
  name        = "msa-platform-external-secrets"
  description = "Allow External Secrets Operator to read MSA secrets"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]

        Resource = "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:msa-platform/*"
      }
    ]
  })

  tags = {
    Name = "msa-platform-external-secrets"
  }
}


# ------------------------------------------------------------
# External Secrets Operator IAM Role
# ------------------------------------------------------------
resource "aws_iam_role" "external_secrets" {
  name = "msa-platform-external-secrets"

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

            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:external-secrets:external-secrets"
          }
        }
      }
    ]
  })

  tags = {
    Name = "msa-platform-external-secrets"
  }
}


# ------------------------------------------------------------
# IAM Policy -> IAM Role
# ------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}