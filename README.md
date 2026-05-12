<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~> 2.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azapi"></a> [azapi](#provider\_azapi) | n/a |
| <a name="provider_azuread"></a> [azuread](#provider\_azuread) | ~> 2.0 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 4.0 |
| <a name="provider_databricks.azure_account"></a> [databricks.azure\_account](#provider\_databricks.azure\_account) | n/a |
| <a name="provider_databricks.dbw"></a> [databricks.dbw](#provider\_databricks.dbw) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_databricks-pe"></a> [databricks-pe](#module\_databricks-pe) | github.com/canada-ca-terraform-modules/terraform-azurerm-caf-private_endpoint | v1.0.2 |
| <a name="module_databricks-rg"></a> [databricks-rg](#module\_databricks-rg) | github.com/canada-ca-terraform-modules/terraform-azurerm-caf-resource_groups.git | v2.0.1 |
| <a name="module_databricks-storage-account"></a> [databricks-storage-account](#module\_databricks-storage-account) | github.com/canada-ca-terraform-modules/terraform-azurerm-caf-storage_accountV2.git | v1.1.0 |

## Resources

| Name | Type |
|------|------|
| [azapi_resource.databricks](https://registry.terraform.io/providers/azure/azapi/latest/docs/resources/resource) | resource |
| [azurerm_databricks_access_connector.connector](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/databricks_access_connector) | resource |
| [azurerm_role_assignment.data_share_access](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.databricks-connector-to-storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_storage_container.base-containers](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |
| [databricks_catalog.default_catalog](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/catalog) | resource |
| [databricks_external_location.base-locations](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/external_location) | resource |
| [databricks_grant.account_admins_can_manage_credential](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/grant) | resource |
| [databricks_grant.account_admins_can_manage_default_catalog](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/grant) | resource |
| [databricks_grant.account_admins_can_manage_external_locations](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/grant) | resource |
| [databricks_group_member.workspace-admins](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/group_member) | resource |
| [databricks_metastore_assignment.this](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/metastore_assignment) | resource |
| [databricks_mws_permission_assignment.account-admins-are-workspace-admins](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/mws_permission_assignment) | resource |
| [databricks_storage_credential.connector](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/storage_credential) | resource |
| [databricks_user.workspace_users](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/user) | resource |
| [azapi_client_config.current](https://registry.terraform.io/providers/azure/azapi/latest/docs/data-sources/client_config) | data source |
| [azuread_user.storage_account_contributors](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/user) | data source |
| [databricks_current_user.me](https://registry.terraform.io/providers/databricks/databricks/latest/docs/data-sources/current_user) | data source |
| [databricks_group.account_admins](https://registry.terraform.io/providers/databricks/databricks/latest/docs/data-sources/group) | data source |
| [databricks_group.builtin-admins](https://registry.terraform.io/providers/databricks/databricks/latest/docs/data-sources/group) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_databricks_config"></a> [databricks\_config](#input\_databricks\_config) | n/a | <pre>object({<br>    account_id = string<br>    metastore_id = string<br>    account_admins_group_name = string<br>  })</pre> | n/a | yes |
| <a name="input_databricks_workspace"></a> [databricks\_workspace](#input\_databricks\_workspace) | n/a | `any` | `{}` | no |
| <a name="input_env"></a> [env](#input\_env) | n/a | `any` | n/a | yes |
| <a name="input_group"></a> [group](#input\_group) | n/a | `any` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | n/a | `any` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | n/a | `any` | n/a | yes |
| <a name="input_resource_groups"></a> [resource\_groups](#input\_resource\_groups) | n/a | `any` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | n/a | `any` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | n/a | `any` | n/a | yes |
| <a name="input_vnet"></a> [vnet](#input\_vnet) | n/a | `any` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_storage"></a> [storage](#output\_storage) | n/a |
| <a name="output_workspace"></a> [workspace](#output\_workspace) | n/a |
<!-- END_TF_DOCS -->