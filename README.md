# modernisation-platform-terraform-transform-cross-account-access

[![Standards Icon]][Standards Link] [![Format Code Icon]][Format Code Link] [![Scorecards Icon]][Scorecards Link] [![SCA Icon]][SCA Link] [![Terraform SCA Icon]][Terraform SCA Link]

This module creates the target-account IAM role used by AWS Transform in a central hub account.

The role trust policy is locked to:

- A specific hub account ID
- A generated external ID stored in Secrets Manager
- A specific workspace name session tag

The role permissions are split into:

- Tag-scoped actions: actions allowed only when a resource has the configured tag key/value (default: `transform_access=true`)
- Untagged actions: actions that usually do not support resource-tag conditions (for example `Describe*` and `List*` APIs)

## Usage

```hcl
module "transform_cross_account_access" {
  source = "github.com/ministryofjustice/modernisation-platform-terraform-transform-cross-account-access"

  # Must match the central Transform workspace configuration
  workspace_name = "example-development-erp-modernization"
  hub_account_id = local.environment_management.account_ids["core-shared-services-production"]

  # Optional: customize generated external ID storage and length
  external_id_secret_name = "transform/example-development-erp-modernization/external-id"
  external_id_length      = 32

  # Optional: override if you prefer a different tag key/value convention
  transform_access_tag_key    = "transform_access"
  transform_access_tag_values = ["true"]

  # Mutating actions: restricted to resources with transform_access=true
  migration_scope_actions = [
    "ec2:RunInstances",
    "ec2:TerminateInstances",
    "rds:Create*",
    "rds:Modify*",
    "ecs:Create*",
    "ecs:Update*",
    "mgn:Create*",
    "mgn:Update*"
  ]

  # Read/list actions: allowed without resource-tag condition
  migration_scope_actions_without_tag_condition = [
    "ec2:Describe*",
    "rds:Describe*",
    "ecs:Describe*",
    "ecs:List*",
    "mgn:Describe*",
    "mgn:List*"
  ]

  application_name = local.application_name
  tags             = local.tags
}

# Example resource that Transform can access with default settings
resource "aws_instance" "transform_managed" {
  ami           = "ami-0123456789abcdef0"
  instance_type = "t3.micro"

  tags = {
    Name             = "transform-managed-instance"
    transform_access = "true"
  }
}
```

After apply:

- Use output `execution_role_arn` when creating the target-account connection in AWS Transform.
- Retrieve the generated external ID from Secrets Manager using output `external_id_secret_name` (or `external_id_secret_arn`) and enter that value in the Transform connection setup.

<!--- BEGIN_TF_DOCS --->

<!--- END_TF_DOCS --->

## Looking for issues?

If you're looking to raise an issue with this module, please create a new issue in the [Modernisation Platform repository](https://github.com/ministryofjustice/modernisation-platform/issues).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.transform_exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.scoped_migration_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_secretsmanager_secret.transform_external_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.transform_external_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_caller_identity.spoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.migration_scope](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [random_string.external_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_application_name"></a> [application\_name](#input\_application\_name) | Name of application | `string` | n/a | yes |
| <a name="input_external_id_length"></a> [external\_id\_length](#input\_external\_id\_length) | Length of the generated alphanumeric AWS Transform external ID. | `number` | `32` | no |
| <a name="input_external_id_secret_name"></a> [external\_id\_secret\_name](#input\_external\_id\_secret\_name) | Secrets Manager secret name for the generated AWS Transform external ID. If null, defaults to transform/<workspace_name>/external-id. | `string` | `null` | no |
| <a name="input_hub_account_id"></a> [hub\_account\_id](#input\_hub\_account\_id) | Account ID of the hub account hosting AWS Transform (core-shared-services) | `string` | n/a | yes |
| <a name="input_migration_scope_actions"></a> [migration\_scope\_actions](#input\_migration\_scope\_actions) | Mutating IAM actions the execution role is permitted to perform in this account. These actions are constrained to resources matching transform access tag values. | `list(string)` | <pre>[<br/>  "ec2:RunInstances",<br/>  "ec2:TerminateInstances",<br/>  "ec2:StartInstances",<br/>  "ec2:StopInstances",<br/>  "ec2:RebootInstances",<br/>  "ec2:ModifyInstanceAttribute",<br/>  "ec2:AssociateIamInstanceProfile",<br/>  "ec2:DisassociateIamInstanceProfile",<br/>  "ec2:ReplaceIamInstanceProfileAssociation",<br/>  "ec2:CreateVolume",<br/>  "ec2:DeleteVolume",<br/>  "ec2:AttachVolume",<br/>  "ec2:DetachVolume",<br/>  "ec2:ModifyVolume",<br/>  "ec2:CreateSnapshot",<br/>  "ec2:DeleteSnapshot",<br/>  "ec2:CreateImage",<br/>  "ec2:DeregisterImage",<br/>  "ec2:CreateNetworkInterface",<br/>  "ec2:DeleteNetworkInterface",<br/>  "ec2:AttachNetworkInterface",<br/>  "ec2:DetachNetworkInterface",<br/>  "ec2:CreateTags",<br/>  "ec2:DeleteTags",<br/>  "rds:Create*",<br/>  "rds:Modify*",<br/>  "rds:Delete*",<br/>  "rds:Start*",<br/>  "rds:Stop*",<br/>  "rds:Reboot*",<br/>  "rds:Restore*",<br/>  "rds:Promote*",<br/>  "rds:AddTagsToResource",<br/>  "rds:RemoveTagsFromResource",<br/>  "ecs:Create*",<br/>  "ecs:Update*",<br/>  "ecs:Delete*",<br/>  "ecs:RunTask",<br/>  "ecs:StartTask",<br/>  "ecs:StopTask",<br/>  "ecs:RegisterTaskDefinition",<br/>  "ecs:DeregisterTaskDefinition",<br/>  "ecs:Put*",<br/>  "ecs:TagResource",<br/>  "ecs:UntagResource",<br/>  "mgn:Create*",<br/>  "mgn:Update*",<br/>  "mgn:Delete*",<br/>  "mgn:Start*",<br/>  "mgn:Stop*",<br/>  "mgn:RetryDataReplication",<br/>  "mgn:FinalizeCutover",<br/>  "mgn:ArchiveApplication",<br/>  "mgn:ChangeServerLifeCycleState",<br/>  "mgn:TagResource",<br/>  "mgn:UntagResource"<br/>]</pre> | no |
| <a name="input_migration_scope_actions_without_tag_condition"></a> [migration\_scope\_actions\_without\_tag\_condition](#input\_migration\_scope\_actions\_without\_tag\_condition) | Read-only IAM actions allowed without the resource tag condition, for AWS API actions that do not support aws:ResourceTag condition keys. | `list(string)` | <pre>[<br/>  "ec2:Describe*",<br/>  "rds:Describe*",<br/>  "rds:ListTagsForResource",<br/>  "ecs:Describe*",<br/>  "ecs:List*",<br/>  "mgn:Describe*",<br/>  "mgn:List*"<br/>]</pre> | no |
| <a name="input_registry_table_name"></a> [registry\_table\_name](#input\_registry\_table\_name) | Name of the hub's transform-migration-registry DynamoDB table, so this workspace can self-register | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags to be used by all resources | `map(string)` | n/a | yes |
| <a name="input_transform_access_tag_key"></a> [transform\_access\_tag\_key](#input\_transform\_access\_tag\_key) | Tag key used to identify resources transform is allowed to access. | `string` | `"transform_access"` | no |
| <a name="input_transform_access_tag_values"></a> [transform\_access\_tag\_values](#input\_transform\_access\_tag\_values) | Allowed tag values for the transform access tag key. | `list(string)` | <pre>[<br/>  "true"<br/>]</pre> | no |
| <a name="input_workspace_name"></a> [workspace\_name](#input\_workspace\_name) | Name of the AWS Transform workspace this migration project maps to, e.g. "example-development-erp-modernization" | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_external_id"></a> [external\_id](#output\_external\_id) | Generated AWS Transform external ID used in the role trust policy |
| <a name="output_external_id_secret_arn"></a> [external\_id\_secret\_arn](#output\_external\_id\_secret\_arn) | Secrets Manager secret ARN containing the generated AWS Transform external ID |
| <a name="output_external_id_secret_name"></a> [external\_id\_secret\_name](#output\_external\_id\_secret\_name) | Secrets Manager secret name containing the generated AWS Transform external ID |
| <a name="output_execution_role_arn"></a> [execution\_role\_arn](#output\_execution\_role\_arn) | Paste into the AWS Transform console when configuring this workspace's target account connection |
<!-- END_TF_DOCS -->

[Standards Link]: https://github-community.service.justice.gov.uk/repository-standards/modernisation-platform-terraform-module-template "Repo standards badge."
[Standards Icon]: https://github-community.service.justice.gov.uk/repository-standards/api/modernisation-platform-terraform-module-template/badge
[Format Code Icon]: https://img.shields.io/github/actions/workflow/status/ministryofjustice/modernisation-platform-terraform-module-template/format-code.yml?labelColor=231f20&style=for-the-badge&label=Formate%20Code
[Format Code Link]: https://github.com/ministryofjustice/modernisation-platform-terraform-module-template/actions/workflows/format-code.yml
[Scorecards Icon]: https://img.shields.io/github/actions/workflow/status/ministryofjustice/modernisation-platform-terraform-module-template/scorecards.yml?branch=main&labelColor=231f20&style=for-the-badge&label=Scorecards
[Scorecards Link]: https://github.com/ministryofjustice/modernisation-platform-terraform-module-template/actions/workflows/scorecards.yml
[SCA Icon]: https://img.shields.io/github/actions/workflow/status/ministryofjustice/modernisation-platform-terraform-module-template/code-scanning.yml?branch=main&labelColor=231f20&style=for-the-badge&label=Secure%20Code%20Analysis
[SCA Link]: https://github.com/ministryofjustice/modernisation-platform-terraform-module-template/actions/workflows/code-scanning.yml
[Terraform SCA Icon]: https://img.shields.io/github/actions/workflow/status/ministryofjustice/modernisation-platform-terraform-module-template/code-scanning.yml?branch=main&labelColor=231f20&style=for-the-badge&label=Terraform%20Static%20Code%20Analysis
[Terraform SCA Link]: https://github.com/ministryofjustice/modernisation-platform-terraform-module-template/actions/workflows/terraform-static-analysis.yml
