# Azure AI-SOC MVP — Terraform

## Overview

Deploys the cost-optimized Azure SOC backbone:

- Resource Group
- Log Analytics Workspace (30-day retention, `PerGB2018`)
- Sentinel onboarding
- Storage Account (Standard LRS)
- Function App (Linux, **Consumption Y1 plan** — free tier)
- Key Vault (Standard, 7-day soft-delete)

## Commands

```bash
terraform init
terraform plan
terraform apply
```

To tear down when not testing (keeps costs at $0 between sessions):

```bash
terraform destroy
```

## Files

```
terraform-azure-soc/
  providers.tf
  main.tf
```

## Cost Notes (Target: < $20/month)

- **Service plan `Y1`** = Consumption = free up to 1M executions/month. **Never** switch to Premium/App Service SKU.
- **Log Analytics `PerGB2018`, retention 30 days** — pay only for ingested GBs; keep ingestion < 1 GB/day.
- **Sentinel** free for the first 10 GB/day ingestion per workspace in many regions.
- **Key Vault Standard** — free up to 10,000 operations/month.
- **Storage LRS** — sub-$1/month at this scale.
- `AI_MOCK_MODE=true` is set by default so the AI agent does not call paid Azure OpenAI during development.

## Outputs

- `function_app_name` — for `func azure functionapp publish`
- `resource_group_name`
- `workspace_id` — Sentinel / Log Analytics workspace
- `key_vault_id`

## Notes

Extend with Logic App deployment and Key Vault secrets (via `azurerm_logic_app_workflow` and `azurerm_key_vault_secret`) when ready.