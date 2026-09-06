# Azure SOC CI/CD Pipeline

## Overview

GitHub Actions pipeline for the Azure AI-SOC MVP:

1. **test-ai-triage** — runs the AI triage agent's unit tests in **mock mode** (zero cloud spend, zero OpenAI cost).
2. **build-and-push-images** — builds and pushes both container images to **GitHub Container Registry (GHCR)** using `GITHUB_TOKEN` (no PAT needed).
3. **terraform-validate** — runs `terraform init` + `terraform validate` against the IaC.

## Workflow Location

GitHub Actions only discovers workflows in the **repo root** `.github/workflows/`:

```
.github/
  workflows/azure-soc-cicd.yml
```

> The repo also contains `azure-soc-cicd/` as the *project documentation* folder; the live workflow lives at the repo root.

## Triggers

- `push` to `main` that touches `ai-soc-triage-agent/**`, `azure-enrichment-engine/**`, `terraform-azure-soc/**`, or `.github/workflows/**`
- Manual `workflow_dispatch`

## Images

| Image | GHCR path |
|---|---|
| AI triage agent | `ghcr.io/koatedevopskpai/azure-ai-soc-triage/ai-soc-triage-agent` |
| Enrichment engine | `ghcr.io/koatedevopskpai/azure-ai-soc-triage/azure-enrichment-engine` |

Tags: `latest` + commit SHA. The `build-and-push-images` job declares `permissions: { packages: write }` so `GITHUB_TOKEN` can publish.

> **Note:** A local `gh auth token`/PAT for `docker push` requires a PAT with **`write:packages`** scope (the default `gh` token scope doesn't include it). The GitHub Actions path uses `GITHUB_TOKEN` and works without one.

## Setup (GitHub Secrets)

| Secret | Value |
|---|---|
| `AZURE_CREDENTIALS` | Service Principal JSON from `az ad sp create-for-rbac` scoped to the resource group (needed only if you add Azure deploy steps) |

## Cost Notes

- **Public repo** → GitHub Actions free tier (2,000 min/month).
- **GHCR is free for public images** — no Azure Container Registry cost.
- Path filters mean the pipeline only runs when relevant code changes.
- Tests run in mock mode so they never invoke paid Azure OpenAI.

## Notes

- Add environment matrix (dev/test/prod) when you scale.
- Terraform `apply` is intentionally **not** auto-run in CI to avoid unplanned cost; run `terraform apply` manually and review the plan.