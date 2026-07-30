variable "workspace_name" {
  description = "Name of the AWS Transform workspace this migration project maps to, e.g. \"example-development-erp-modernization\""
  type        = string
}

variable "hub_account_id" {
  description = "Account ID of the hub account hosting AWS Transform (core-shared-services)"
  type        = string
}

variable "external_id_secret_name" {
  description = "Secrets Manager secret name for the generated AWS Transform external ID. If null, defaults to transform/<workspace_name>/external-id."
  type        = string
  default     = null
}

variable "external_id_length" {
  description = "Length of the generated alphanumeric AWS Transform external ID."
  type        = number
  default     = 32

  validation {
    condition     = var.external_id_length >= 8 && var.external_id_length <= 1224
    error_message = "external_id_length must be between 8 and 1224 characters."
  }
}

variable "registry_table_name" {
  description = "Name of the hub's transform-migration-registry DynamoDB table, so this workspace can self-register"
  type        = string
  default     = null
}

variable "migration_scope_actions" {
  description = "Mutating IAM actions the execution role is permitted to perform in this account. These actions are constrained to resources matching transform access tag values."
  type        = list(string)
  default = [
    "ec2:RunInstances",
    "ec2:TerminateInstances",
    "ec2:StartInstances",
    "ec2:StopInstances",
    "ec2:RebootInstances",
    "ec2:ModifyInstanceAttribute",
    "ec2:AssociateIamInstanceProfile",
    "ec2:DisassociateIamInstanceProfile",
    "ec2:ReplaceIamInstanceProfileAssociation",
    "ec2:CreateVolume",
    "ec2:DeleteVolume",
    "ec2:AttachVolume",
    "ec2:DetachVolume",
    "ec2:ModifyVolume",
    "ec2:CreateSnapshot",
    "ec2:DeleteSnapshot",
    "ec2:CreateImage",
    "ec2:DeregisterImage",
    "ec2:CreateNetworkInterface",
    "ec2:DeleteNetworkInterface",
    "ec2:AttachNetworkInterface",
    "ec2:DetachNetworkInterface",
    "ec2:CreateTags",
    "ec2:DeleteTags",
    "rds:Create*",
    "rds:Modify*",
    "rds:Delete*",
    "rds:Start*",
    "rds:Stop*",
    "rds:Reboot*",
    "rds:Restore*",
    "rds:Promote*",
    "rds:AddTagsToResource",
    "rds:RemoveTagsFromResource",
    "ecs:Create*",
    "ecs:Update*",
    "ecs:Delete*",
    "ecs:RunTask",
    "ecs:StartTask",
    "ecs:StopTask",
    "ecs:RegisterTaskDefinition",
    "ecs:DeregisterTaskDefinition",
    "ecs:Put*",
    "ecs:TagResource",
    "ecs:UntagResource",
    "mgn:Create*",
    "mgn:Update*",
    "mgn:Delete*",
    "mgn:Start*",
    "mgn:Stop*",
    "mgn:RetryDataReplication",
    "mgn:FinalizeCutover",
    "mgn:ArchiveApplication",
    "mgn:ChangeServerLifeCycleState",
    "mgn:TagResource",
    "mgn:UntagResource"
  ]
}

variable "migration_scope_actions_without_tag_condition" {
  description = "Read-only IAM actions allowed without the resource tag condition, for AWS API actions that do not support aws:ResourceTag condition keys."
  type        = list(string)
  default = [
    "ec2:Describe*",
    "rds:Describe*",
    "rds:ListTagsForResource",
    "ecs:Describe*",
    "ecs:List*",
    "mgn:Describe*",
    "mgn:List*"
  ]
}

variable "transform_access_tag_key" {
  description = "Tag key used to identify resources transform is allowed to access."
  type        = string
  default     = "transform_access"
}

variable "transform_access_tag_values" {
  description = "Allowed tag values for the transform access tag key."
  type        = list(string)
  default     = ["true"]
}

variable "tags" {
  type        = map(string)
  description = "Common tags to be used by all resources"
}
variable "application_name" {
  type        = string
  description = "Name of application"
}
