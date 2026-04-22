variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "random_suffix" {
  description = "Random suffix for unique names"
  type        = string
}

variable "function_app_url" {
  description = "Function App default hostname"
  type        = string
}

variable "function_app_key" {
  description = "Function App host key"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
}
