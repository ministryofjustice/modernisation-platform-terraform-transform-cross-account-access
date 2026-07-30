data "aws_caller_identity" "spoke" {}

locals {
  external_id_secret_name = coalesce(var.external_id_secret_name, "transform/${var.workspace_name}/external-id")
}

resource "random_string" "external_id" {
  length  = var.external_id_length
  upper   = true
  lower   = true
  numeric = true
  special = false
}

resource "aws_secretsmanager_secret" "transform_external_id" {
  name        = local.external_id_secret_name
  description = "External ID for AWS Transform workspace ${var.workspace_name}"
  tags = merge(var.tags, {
    TransformRole = "spoke-migration"
    Workspace     = var.workspace_name
  })
}

resource "aws_secretsmanager_secret_version" "transform_external_id" {
  secret_id     = aws_secretsmanager_secret.transform_external_id.id
  secret_string = random_string.external_id.result
}

# ---------------------------------------------------------------------------
# 1) Execution role — what the AWS Transform workspace's target account
#    connection assumes to act in this account. Trust is scoped to the hub
#    account + a unique external ID per workspace (avoids confused-deputy
#    issues if multiple workspaces share the same hub).
# ---------------------------------------------------------------------------

resource "aws_iam_role" "transform_exec" {
  name = "TransformExecutionRole-${var.workspace_name}"

  # Session tags (set via sts:TagSession below) carry Workspace=<name>, which
  # the hub's S3 bucket policy uses to restrict this role to its own prefix
  # under workspaces/<name>/* — see hub/core-shared-services/main.tf.
  tags = {
    TransformRole = "spoke-migration"
    Workspace     = var.workspace_name
  }

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.hub_account_id}:root" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Condition = {
        StringEquals = {
          "sts:ExternalId"           = random_string.external_id.result
          "aws:RequestTag/Workspace" = var.workspace_name
        }
      }
    }]
  })
}

data "aws_iam_policy_document" "migration_scope" {
  statement {
    effect    = "Allow"
    actions   = var.migration_scope_actions
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/${var.transform_access_tag_key}"
      values   = var.transform_access_tag_values
    }
  }

  dynamic "statement" {
    for_each = length(var.migration_scope_actions_without_tag_condition) > 0 ? [1] : []

    content {
      effect    = "Allow"
      actions   = var.migration_scope_actions_without_tag_condition
      resources = ["*"]
    }
  }

  statement {
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.spoke.account_id}:role/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com", "ecs-tasks.amazonaws.com", "mgn.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/${var.transform_access_tag_key}"
      values   = var.transform_access_tag_values
    }
  }
}

resource "aws_iam_role_policy" "scoped_migration_access" {
  role   = aws_iam_role.transform_exec.id
  policy = data.aws_iam_policy_document.migration_scope.json
}


