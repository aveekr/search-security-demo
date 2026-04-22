output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "search_service_name" {
  description = "Name of the Azure AI Search service"
  value       = module.search.search_service_name
}

output "search_endpoint" {
  description = "Endpoint of the Azure AI Search service"
  value       = module.search.search_endpoint
}

output "function_app_name" {
  description = "Name of the Function App"
  value       = module.functions.function_app_name
}

output "function_app_url" {
  description = "URL of the Function App"
  value       = "https://${module.functions.function_app_default_hostname}"
}

output "apim_gateway_url" {
  description = "API Management gateway URL"
  value       = module.apim.apim_gateway_url
}

output "sql_server_name" {
  description = "Name of the SQL Server"
  value       = module.sql.sql_server_name
}

output "sql_database_name" {
  description = "Name of the SQL Database"
  value       = module.sql.sql_database_name
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = azurerm_storage_account.main.name
}

output "openai_endpoint" {
  description = "Azure OpenAI endpoint"
  value       = module.openai.openai_endpoint
}

output "openai_deployment_name" {
  description = "Azure OpenAI embedding deployment name"
  value       = module.openai.embedding_deployment_name
}

output "application_insights_name" {
  description = "Name of Application Insights"
  value       = azurerm_application_insights.main.name
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "deployment_instructions" {
  description = "Next steps after infrastructure deployment"
  value       = <<-EOT
  
  ✅ Infrastructure deployed successfully!
  
  Next steps:
  1. Initialize SQL Database:
     cd data/sql
     sqlcmd -S ${module.sql.sql_server_fqdn} -d ${module.sql.sql_database_name} -G -i schema.sql
     sqlcmd -S ${module.sql.sql_server_fqdn} -d ${module.sql.sql_database_name} -G -i seed_data.sql
  
  2. Create Search Index:
     cd ../search
     # Upload index_definition.json via Azure Portal or Azure CLI
  
  3. Deploy Function App:
     cd ../../src
     func azure functionapp publish ${module.functions.function_app_name}
  
  4. Test endpoints:
     API Gateway: ${module.apim.apim_gateway_url}
     Function App: https://${module.functions.function_app_default_hostname}
  
  5. Upload sample documents to Storage:
     az storage blob upload-batch -d documents -s ../data/sample_documents --account-name ${azurerm_storage_account.main.name}
  
  EOT
}
