resource "azurerm_resource_group" "soc" {
  name     = "rg-ai-soc-mvp"
  location = "uksouth"
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_log_analytics_workspace" "sentinel" {
  name                = "log-soc-mvp"
  location            = azurerm_resource_group.soc.location
  resource_group_name = azurerm_resource_group.soc.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_sentinel_log_analytics_workspace_onboarding" "sentinel" {
  workspace_id = azurerm_log_analytics_workspace.sentinel.id
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "soc" {
  name                       = "kv-soc-mvp-${random_string.suffix.result}"
  location                   = azurerm_resource_group.soc.location
  resource_group_name        = azurerm_resource_group.soc.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
}

resource "azurerm_storage_account" "soc" {
  name                     = "stgsocmvp${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.soc.name
  location                 = azurerm_resource_group.soc.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
}

resource "azurerm_service_plan" "soc" {
  name                = "plan-soc-mvp"
  location            = azurerm_resource_group.soc.location
  resource_group_name = azurerm_resource_group.soc.name
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "enrichment" {
  name                       = "func-soc-enrich-${random_string.suffix.result}"
  resource_group_name        = azurerm_resource_group.soc.name
  location                   = azurerm_resource_group.soc.location
  service_plan_id            = azurerm_service_plan.soc.id
  storage_account_name       = azurerm_storage_account.soc.name
  storage_account_access_key = azurerm_storage_account.soc.primary_access_key

  site_config {
    application_stack {
      python_version = "3.11"
    }
    ftps_state = "FtpsOnly"
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "python"
    "ABUSEIPDB_API_KEY"        = ""
    "AZURE_OPENAI_ENDPOINT"    = ""
    "AZURE_OPENAI_KEY"         = ""
    "AZURE_OPENAI_DEPLOYMENT"  = ""
    "AI_MOCK_MODE"             = "true"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_key_vault_access_policy" "function" {
  key_vault_id = azurerm_key_vault.soc.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_function_app.enrichment.identity[0].principal_id

  secret_permissions = ["Get", "List"]
}

output "function_app_name" {
  value = azurerm_linux_function_app.enrichment.name
}

output "resource_group_name" {
  value = azurerm_resource_group.soc.name
}

output "workspace_id" {
  value = azurerm_log_analytics_workspace.sentinel.workspace_id
}

output "key_vault_id" {
  value = azurerm_key_vault.soc.id
}