data "aws_caller_identity" "spoke" {}

data "aws_region" "current" {}

locals {
  external_id_secret_name = coalesce(var.external_id_secret_name, "transform/${var.workspace_name}/external-id")
  transform_bucket_prefix = coalesce(var.transform_bucket_prefix, "aws-transform-${lower(var.workspace_name)}")
  transform_bucket_kms_alias = coalesce(
    var.transform_bucket_kms_alias,
    "alias/aws-transform-bucket-${lower(var.workspace_name)}"
  )
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

module "transform_s3_bucket" {
  source = "github.com/ministryofjustice/modernisation-platform-terraform-s3-bucket?ref=c8889e65f4d8a3d53d2cbd93b7be714e990020b7"

  providers = {
    aws                    = aws
    aws.bucket-replication = aws
  }

  bucket_prefix               = local.transform_bucket_prefix
  bucket_policy               = [data.aws_iam_policy_document.transform_s3_bucket_policy.json]
  sse_algorithm               = "aws:kms"
  custom_kms_key              = aws_kms_key.transform_bucket.arn
  enforce_kms_request_headers = true
  replication_enabled         = false
  versioning_enabled          = true
  force_destroy               = false
  ownership_controls          = "BucketOwnerEnforced"

  lifecycle_rule = [
    {
      id      = "main"
      enabled = "Enabled"
      prefix  = ""

      tags = {
        rule      = "log"
        autoclean = "true"
      }

      transition = [
        {
          days          = 90
          storage_class = "STANDARD_IA"
          }, {
          days          = 365
          storage_class = "GLACIER"
        }
      ]

      noncurrent_version_transition = [
        {
          days          = 90
          storage_class = "STANDARD_IA"
          }, {
          days          = 365
          storage_class = "GLACIER"
        }
      ]

      noncurrent_version_expiration = {
        days = 730
      }
    }
  ]

  tags = merge(var.tags, {
    TransformRole = "spoke-migration"
    Workspace     = var.workspace_name
  })
}

data "aws_iam_policy_document" "transform_s3_bucket_policy" {
  statement {
    sid    = "AllowTransformAccessToBucket"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:AbortMultipartUpload"
    ]

    resources = [
      module.transform_s3_bucket.bucket.arn,
      "${module.transform_s3_bucket.bucket.arn}/*"
    ]

    principals {
      type        = "Service"
      identifiers = ["transform.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.hub_account_id]
    }
  }
}

resource "aws_kms_key" "transform_bucket" {
  description             = "KMS key for AWS Transform S3 bucket ${var.workspace_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.transform_kms_key_policy.json

  tags = merge(var.tags, {
    TransformRole = "spoke-migration"
    Workspace     = var.workspace_name
  })
}

resource "aws_kms_alias" "transform_bucket" {
  name          = local.transform_bucket_kms_alias
  target_key_id = aws_kms_key.transform_bucket.key_id
}

resource "aws_s3_bucket_cors_configuration" "transform_s3_bucket" {
  count  = var.transform_workspace_url == null ? 0 : 1
  bucket = module.transform_s3_bucket.bucket.id

  cors_rule {
    allowed_headers = [
      "host",
      "content-type",
      "if-none-match",
      "x-amz-checksum-sha256",
      "x-amz-expected-bucket-owner",
      "x-amz-server-side-encryption",
      "x-amz-server-side-encryption-aws-kms-key-id",
      "x-amz-server-side-encryption-context",
      "x-amz-source-account",
      "x-amz-source-arn"
    ]
    allowed_methods = ["GET", "PUT", "HEAD"]
    allowed_origins = [var.transform_workspace_url]
    expose_headers = [
      "ETag",
      "x-amz-checksum-sha256",
      "x-amz-request-id",
      "x-amz-id-2"
    ]
    max_age_seconds = 3600
  }
}

data "aws_iam_policy_document" "transform_kms_key_policy" {
  statement {
    sid    = "EnableRootPermissions"
    effect = "Allow"
    actions = [
      "kms:*"
    ]

    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.spoke.account_id}:root"]
    }
  }

  statement {
    sid    = "AllowTransformToUseKey"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:ReEncrypt*"
    ]

    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["transform.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.hub_account_id]
    }
  }

  statement {
    sid    = "AllowAWSTransformServiceAccess"
    effect = "Allow"
    actions = [
      "kms:CreateGrant",
      "kms:DescribeKey"
    ]

    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["transform.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["transform.${data.aws_region.current.name}.amazonaws.com"]
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
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
          "sts:ExternalId"           = aws_secretsmanager_secret_version.transform_external_id.secret_string
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


