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

variable "storage_account_name" {
  description = "Name of the storage account"
  type        = string
}

# Removed storage_account_access_key - using managed identity instead

variable "app_insights_conn_string" {
  description = "Application Insights connection string"
  type        = string
  sensitive   = true
}

variable "app_insights_key" {
  description = "Application Insights instrumentation key"
  type        = string
  sensitive   = true
}

variable "search_endpoint" {
  description = "Azure AI Search endpoint"
  type        = string
}

variable "sql_server_fqdn" {
  description = "SQL Server FQDN"
  type        = string
}

variable "sql_database_name" {
  description = "SQL Database name"
  type        = string
}

variable "openai_endpoint" {
  description = "Azure OpenAI endpoint"
  type        = string
}

variable "storage_account_name_docs" {
  description = "Storage account name for documents"
  type        = string
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
}
