variable "tags" {
  type = any
}

variable "env" {}
variable "group" {}
variable "project" {}

variable "location" {}

# Variables for L1 remote state access

variable "L1_terraform_remote_state_account_name" {
  type = string
}
variable "L1_terraform_remote_state_container_name" {
  type = string
}
variable "L1_terraform_remote_state_key" {
  type = string
}
variable "L1_terraform_remote_state_resource_group_name" {
  type = string
}
variable "L1_terraform_remote_state_subscription_id" {
  type    = string
  default = null
}