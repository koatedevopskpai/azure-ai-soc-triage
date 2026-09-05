# Azure SOC CI/CD Pipeline

## Overview

GitHub Actions pipeline for the Azure AI-SOC MVP:

1. **test-ai-triage** — runs the AI triage agent's unit tests in **mock mode** (zero cloud spend, zero OpenAI cost).
2. **build-and-deploy-function** — zips and deploys the Azure Function app (Enrichment Engine).
3. **terraform-validate** — runs `terraform init` + `terraform validate` against the IaC.

## Workflow

```
azure-soc-cicd/
  .github/workflows/azure-soc-cicd.yml
```

Triggers:

- `push` to `main` that touches `azure-enrichment-engine/**` or `terraform-azure-soc/**`
- Manual `workflow_dispatch`

## Setup (GitHub Secrets)

| Secret | Value |
|---|---|
| `AZURE_CREDENTIALS` | Service Principal JSON from `az ad sp create-for-rbac` scoped to the resource group |

## Cost Notes

- **Public repo** → GitHub Actions free tier (2,000 min/month).
- Path filters mean the pipeline only runs when relevant code changes.
- Tests run in mock mode so they never invoke paid Azure OpenAI.

## Notes

- Add environment matrix (dev/test/prod) when you scale.
- Terraform `apply` is intentionally **not** auto-run in CI to avoid unplanned cost; run `terraform apply` manually and review the plan.