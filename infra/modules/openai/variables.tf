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

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
}

variable "embedding_model_name" {
  description = "Embedding model name"
  type        = string
  default     = "text-embedding-ada-002"
}

variable "embedding_model_version" {
  description = "Embedding model version"
  type        = string
  default     = "2"
}

variable "embedding_deployment_name" {
  description = "Embedding deployment name"
  type        = string
  default     = "text-embedding-ada-002"
}

variable "embedding_deployment_capacity" {
  description = "Embedding deployment capacity (TPM in thousands)"
  type        = number
  default     = 120
}
