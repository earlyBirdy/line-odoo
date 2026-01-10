data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [
        "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.github_branch}",
        "repo:${var.github_org}/${var.github_repo}:pull_request"
      ]
    }
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [var.oidc_thumbprint]
  tags            = var.tags
}

resource "aws_iam_role" "github_terraform" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "terraform_permissions" {
  statement {
    sid     = "TerraformBroadInfra"
    effect  = "Allow"
    actions = [
      "ec2:*",
      "elasticloadbalancing:*",
      "ecs:*",
      "ecr:*",
      "iam:GetRole",
      "iam:List*",
      "iam:PassRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "rds:*",
      "elasticache:*",
      "efs:*",
      "logs:*",
      "cloudwatch:*",
      "wafv2:*",
      "acm:*",
      "route53:*",
      "secretsmanager:*",
      "kms:DescribeKey",
      "kms:CreateGrant"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "TerraformStateAccess"
    effect  = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::${var.tf_state_bucket}",
      "arn:aws:s3:::${var.tf_state_bucket}/*"
    ]
  }

  statement {
    sid     = "TerraformLockAccess"
    effect  = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateItem"
    ]
    resources = [var.tf_lock_table_arn]
  }
}

resource "aws_iam_role_policy" "inline" {
  name   = "${var.role_name}-inline"
  role   = aws_iam_role.github_terraform.id
  policy = data.aws_iam_policy_document.terraform_permissions.json
}

output "role_arn" {
  value = aws_iam_role.github_terraform.arn
}
