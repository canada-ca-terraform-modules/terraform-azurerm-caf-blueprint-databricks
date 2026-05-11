variable "tags" {
  type = any
}

variable "env" {}
variable "group" {}
variable "project" {}

variable "location" {}

variable "resource_groups" { }
variable "subnets" {}

variable "vnet" {
  
}

variable "databricks_workspace" {
  type = any
  default = {}
}

variable "databricks_config" {
  type = object({
    account_id = string
    metastore_id = string
    account_admins_group_name = string
  })
}
