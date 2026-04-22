variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "aisearch-demo"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "centralus"
}

variable "openai_location" {
  description = "Azure region for OpenAI (limited availability)"
  type        = string
  default     = "eastus"
}

variable "resource_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "aisearch-demo"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Demo"
    Project     = "AI-Search-Security"
    ManagedBy   = "Terraform"
  }
}

variable "sql_admin_group_name" {
  description = "Azure AD group name for SQL administrators"
  type        = string
  default     = ""
}

variable "embedding_model_name" {
  description = "Azure OpenAI embedding model name"
  type        = string
  default     = "text-embedding-ada-002"
}

variable "embedding_model_version" {
  description = "Azure OpenAI embedding model version"
  type        = string
  default     = "2"
}

variable "embedding_deployment_name" {
  description = "Azure OpenAI embedding deployment name"
  type        = string
  default     = "text-embedding-ada-002"
}

variable "embedding_deployment_capacity" {
  description = "Azure OpenAI embedding deployment capacity (TPM in thousands)"
  type        = number
  default     = 70
}
