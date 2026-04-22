# API Management Service
resource "azurerm_api_management" "main" {
  name                = "${var.resource_prefix}-apim-${var.random_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = "AI Search Demo"
  publisher_email     = "admin@aisearchdemo.com"
  sku_name            = "Developer_1"
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = var.tags
}

# Backend for Function App
resource "azurerm_api_management_backend" "function_backend" {
  name                = "search-function-backend"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  protocol            = "http"
  url                 = "https://${var.function_app_url}"
  
  credentials {
    header = {
      "x-functions-key" = var.function_app_key
    }
  }
}

# API Definition
resource "azurerm_api_management_api" "search_api" {
  name                = "search-api"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  revision            = "1"
  display_name        = "Capital Markets Search API"
  path                = "api"
  protocols           = ["https"]
  service_url         = "https://${var.function_app_url}/api"
  
  subscription_required = true
  
  # OAuth 2.0 authorization commented out - configure manually after deployment
  # oauth2_authorization {
  #   authorization_server_name = "oauth2-server"
  # }
}

# OAuth 2.0 Authorization Server - Configure manually via Azure Portal after deployment
# Commented out to avoid validation errors with placeholder values
# To configure:
# 1. Go to API Management -> OAuth 2.0 + OpenID Connect
# 2. Add server with your Entra ID app details from Step 3
#
# resource "azurerm_api_management_authorization_server" "oauth2" {
#   name                         = "oauth2-server"
#   api_management_name          = azurerm_api_management.main.name
#   resource_group_name          = var.resource_group_name
#   display_name                 = "OAuth 2.0 Authorization"
#   client_registration_endpoint = "http://contoso.com/apps"
#   authorization_endpoint       = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
#   grant_types                  = ["authorizationCode", "clientCredentials"]
#   
#   authorization_methods = ["GET", "POST"]
#   
#   client_id     = "00000000-0000-0000-0000-000000000000"
#   client_secret = "placeholder-configure-after-deployment"
#   
#   token_endpoint = "https://login.microsoftonline.com/common/oauth2/v2.0/token"
# }

# API Operations

# Search operation
resource "azurerm_api_management_api_operation" "search" {
  operation_id        = "search"
  api_name            = azurerm_api_management_api.search_api.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name        = "Search Documents"
  method              = "POST"
  url_template        = "/search"
  description         = "Vector and hybrid search with security filtering"
  
  request {
    description = "Search request with query text"
    representation {
      content_type = "application/json"
      example {
        name  = "default"
        value = jsonencode({
          query           = "market analysis Q4 2025"
          searchType      = "hybrid"
          top             = 10
          advisorId       = "advisor-001"
        })
      }
    }
  }
  
  response {
    status_code = 200
    description = "Search results"
    representation {
      content_type = "application/json"
    }
  }
}

# Upload document operation
resource "azurerm_api_management_api_operation" "upload" {
  operation_id        = "upload-document"
  api_name            = azurerm_api_management_api.search_api.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name        = "Upload Document"
  method              = "POST"
  url_template        = "/documents"
  description         = "Upload and index a document"
  
  response {
    status_code = 201
    description = "Document uploaded successfully"
  }
}

# Health check operation
resource "azurerm_api_management_api_operation" "health" {
  operation_id        = "health-check"
  api_name            = azurerm_api_management_api.search_api.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  display_name        = "Health Check"
  method              = "GET"
  url_template        = "/health"
  description         = "Check API health status"
  
  response {
    status_code = 200
    description = "Service is healthy"
  }
}

# API Policy with rate limiting and OAuth validation
# APIM API Policy - Apply manually via Azure Portal (see DEPLOYMENT.md Step 11.4)
# Working policy XML (CORS must be in inbound section):
# <policies>
#   <inbound>
#     <base />
#     <rate-limit calls="100" renewal-period="60" />
#     <set-backend-service backend-id="search-function-backend" />
#     <set-header name="x-correlation-id" exists-action="override">
#       <value>@(context.RequestId.ToString())</value>
#     </set-header>
#     <cors allow-credentials="false">
#       <allowed-origins><origin>*</origin></allowed-origins>
#       <allowed-methods>
#         <method>GET</method><method>POST</method><method>OPTIONS</method>
#       </allowed-methods>
#       <allowed-headers><header>*</header></allowed-headers>
#     </cors>
#   </inbound>
#   <backend><base /></backend>
#   <outbound><base /></outbound>
#   <on-error><base /></on-error>
# </policies>
#
# resource "azurerm_api_management_api_policy" "search_api_policy" {
#   api_name            = azurerm_api_management_api.search_api.name
#   api_management_name = azurerm_api_management.main.name
#   resource_group_name = var.resource_group_name
#   
#   xml_content = <<-EOT
#     <policies>
#       <inbound>
#         <base />
#         <set-backend-service backend-id="search-function-backend" />
#         <rate-limit calls="100" renewal-period="60" />
#         <set-header name="x-correlation-id" exists-action="override">
#           <value>@(context.RequestId)</value>
#         </set-header>
#       </inbound>
#       <backend>
#         <base />
#       </backend>
#       <outbound>
#         <base />
#         <cors allow-credentials="false">
#           <allowed-origins>
#             <origin>*</origin>
#           </allowed-origins>
#           <allowed-methods>
#             <method>GET</method>
#             <method>POST</method>
#             <method>OPTIONS</method>
#           </allowed-methods>
#           <allowed-headers>
#             <header>*</header>
#           </allowed-headers>
#         </cors>
#       </outbound>
#       <on-error>
#         <base />
#       </on-error>
#     </policies>
#   EOT
# }

# Product for API grouping
resource "azurerm_api_management_product" "search_product" {
  product_id            = "search-product"
  api_management_name   = azurerm_api_management.main.name
  resource_group_name   = var.resource_group_name
  display_name          = "Capital Markets Search Product"
  description           = "Access to AI Search with document-level security"
  subscription_required = true
  approval_required     = false
  published             = true
}

# Associate API with Product
resource "azurerm_api_management_product_api" "search_product_api" {
  api_name            = azurerm_api_management_api.search_api.name
  product_id          = azurerm_api_management_product.search_product.product_id
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
}
