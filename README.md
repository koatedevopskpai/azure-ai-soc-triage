# Azure AI-SOC MVP

AI-Assisted Security Operations Pipeline (Azure Sentinel + SOAR + Enrichment + AI Triage)

This repository contains a complete AI-enabled Security Operations Center (SOC) MVP built entirely on Microsoft Azure. It demonstrates how modern SOC teams can automate triage, enrichment, and response using:

- **Azure Sentinel** (SIEM)
- **Azure Logic Apps** (SOAR)
- **Azure Container Apps** (Enrichment Engine + AI Triage Agent)
- **AI Triage Agent** (Azure OpenAI / mock mode)
- **Terraform IaC**
- **GitHub Actions CI/CD**
- **SOC Metrics Dashboard** (Power BI / Sentinel Workbook)

This MVP is designed to be **low-cost (target < $20/month)**, fully reproducible, and portfolio-ready for security engineering roles.

## Architecture

```
                    ┌──────────────────────────────┐
                    │        Azure Sentinel         │
                    │  (SIEM + Analytics + Alerts)  │
                    └───────────────┬──────────────┘
                                    │ Alerts
                                    ▼
                      ┌──────────────────────────┐
                      │   Azure Logic Apps SOAR  │
                      │ (Triage + Case Handling) │
                      └──────────────┬───────────┘
                                     │ Enrichment Trigger
                                     ▼
                      ┌──────────────────────────┐
                      │ Azure Container Apps      │
                      │ Enrichment Engine (API)   │
                      └──────────────┬───────────┘
                                     │
                                     ▼
                      ┌──────────────────────────┐
                      │   AI Triage Agent        │
                      │ (Container App / OpenAI) │
                      └──────────────┬───────────┘
                                     │ Summary + Severity + Action
                                     ▼
                      ┌──────────────────────────┐
                      │ Sentinel Incident Update │
                      │ (AI comment + enrichment)│
                      └──────────────────────────┘
```

## Repository Structure

```
azure-ai-soc-engr/
│
├── sentinel-detection-pack/     # KQL analytics rules (MITRE-mapped)
├── azure-enrichment-engine/     # Azure Function enrichment (GeoIP, Threat Intel)
├── logicapps-soc-playbook/      # Logic App SOAR workflow JSON
├── ai-soc-triage-agent/         # FastAPI AI triage service (Azure OpenAI)
├── terraform-azure-soc/         # Terraform IaC for Azure SOC backbone
├── azure-soc-cicd/              # GitHub Actions CI/CD
├── cribl-lite-soc-pipeline/     # Cribl pipeline configs (local sim)
├── soc-metrics-dashboard/       # KQL for TTT, Automation Success, AI Usage
└── docs/                        # Architecture + cost notes
```

## Features

- **Sentinel Detection Pack**: Custom KQL rules mapped to MITRE ATT&CK (T1110, T1486).
- **SOAR Automation (Logic Apps)**: Triggered by Sentinel incidents, orchestrates enrichment + AI triage.
- **Enrichment Engine (Azure Functions)**: Adds GeoIP, AbuseIPDB, and contextual metadata.
- **AI Triage Agent (Azure OpenAI)**: Summarises alerts, assigns severity, recommends action, maps runbook.
- **Sentinel Incident Update**: AI triage output written directly into the incident as a comment.
- **CI/CD (GitHub Actions)**: Automated deployment of Function App + Terraform validation.
- **Metrics Dashboard**: KQL queries for Time-to-Triage, Automation Success Rate, AI Usage.

## Cost Target: < $20/month

See [docs/COST-BUDGET.md](docs/COST-BUDGET.md) for the full cost-optimization strategy. Key levers:

- Sentinel 31-day free trial (10 GB/day ingestion free for new workspaces; keep ingestion low after)
- Azure Functions consumption plan (free up to 1M executions/month)
- Azure OpenAI used only for real incidents (low volume), small token budgets, temperature 0
- Local Cribl (no cloud cost)
- GitHub Actions free tier

## Deployment

1. Deploy Azure resources: `cd terraform-azure-soc && terraform init && terraform apply`
2. Build & push container images to GHCR (see `azure-soc-cicd`); GitHub Actions does this automatically on push.
3. Import KQL rules into Sentinel → Analytics → Scheduled rules.
4. Import `logicapps-soc-playbook.json` into Logic Apps; point it at the Container App URLs.
5. Services run on Azure Container Apps (consumption, scale-to-zero) — enrichment + AI triage.
6. Connect Sysmon / Activity Logs so Sentinel has telemetry.

> The AI triage agent runs in **mock mode by default** ($0). Enable live Azure OpenAI via the `AI_MOCK_MODE=false` env var.

## Demo & Screenshots

Screenshots are captured from the live environment. See `docs/DEPLOYMENT-REFERENCE.md` for the full capture checklist.

| Area | Screenshot | Status |
|---|---|---|
| AI Triage (Swagger) | `docs/screenshots/ca-ai-triage-swagger.png` | ✅ Captured |
| Enrichment (Swagger) | `docs/screenshots/ca-enrichment-swagger.png` | ✅ Captured |
| Repo (README) | `docs/screenshots/gh-repo-home.png` | ✅ Captured |
| CI/CD (GitHub Actions) | `docs/screenshots/gh-actions-run.png` | ✅ Captured |
| GHCR package (AI triage) | `docs/screenshots/ghcr-ai-triage-package.png` | ✅ Captured |
| GHCR package (enrichment) | `docs/screenshots/ghcr-enrichment-package.png` | ✅ Captured |
| Incident (Sentinel view) | `docs/screenshots/test-ai-soc-brute-force-incident-sentinel-view.png` | ✅ Captured |
| Incident (overview detail) | `docs/screenshots/test-ai-soc-brute-force-incident-overview-detail.pdf` | ✅ Captured |
| Sentinel Log overview | `docs/screenshots/ms-sentinel-log-overview.png` | ✅ Captured |
| Logic App run history (all green) | `docs/screenshots/logic-app-run-history.png` | ✅ Captured |
| Logic App designer | `docs/screenshots/logic-app-designer-view.png` | ✅ Captured |
| API connections | `docs/screenshots/api-connections-overview.png` | ✅ Captured |
| Cost analysis | `docs/screenshots/az-cost-analysis.png` | ✅ Captured |
| Architecture | `docs/screenshots/architecture.png` | Placeholder — add draw.io export |
| Container Apps list | `docs/screenshots/container-apps-list.png` | Placeholder — capture in Azure |
| Metrics dashboard | `docs/screenshots/metrics-dashboard.png` | Placeholder — capture in Azure |

Demo video (60–90s walkthrough) will be linked here once recorded.

## Future Work (AWS & GCP Tracks)

This repo will expand to include:

- AWS CloudTrail → Cribl → Sentinel
- AWS Lambda SOAR
- Bedrock AI agent with guardrails
- GCP SCC → Cribl → Sentinel
- GKE deployment of AI triage agent
- Vertex AI secure agent
- Multi-cloud triage orchestration
- Unified metrics across clouds

## Contributions & Feedback

Feel free to open issues or PRs. This project is actively evolving into a full multi-cloud AI-SOC platform.