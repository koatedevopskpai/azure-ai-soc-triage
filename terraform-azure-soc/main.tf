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

resource "azurerm_container_app_environment" "soc" {
  name                       = "cae-soc-mvp"
  location                   = azurerm_resource_group.soc.location
  resource_group_name        = azurerm_resource_group.soc.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

resource "azurerm_container_app" "ai_triage" {
  name                         = "ca-ai-triage-${random_string.suffix.result}"
  container_app_environment_id = azurerm_container_app_environment.soc.id
  resource_group_name          = azurerm_resource_group.soc.name
  revision_mode                = "Single"

  template {
    min_replicas = 0
    max_replicas = 1

    container {
      name   = "ai-triage"
      image  = "ghcr.io/koatedevopskpai/azure-ai-soc-triage/ai-soc-triage-agent:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "AI_MOCK_MODE"
        value = "true"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

resource "azurerm_container_app" "enrichment" {
  name                         = "ca-enrichment-${random_string.suffix.result}"
  container_app_environment_id = azurerm_container_app_environment.soc.id
  resource_group_name          = azurerm_resource_group.soc.name
  revision_mode                = "Single"

  template {
    min_replicas = 0
    max_replicas = 1

    container {
      name   = "enrichment"
      image  = "ghcr.io/koatedevopskpai/azure-ai-soc-triage/azure-enrichment-engine:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "ABUSEIPDB_API_KEY"
        value = ""
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8001
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

output "ai_triage_url" {
  value = "https://${azurerm_container_app.ai_triage.latest_revision_fqdn}"
}

output "enrichment_url" {
  value = "https://${azurerm_container_app.enrichment.latest_revision_fqdn}"
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