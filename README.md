# Azure AI-SOC MVP

AI-Assisted Security Operations Pipeline (Azure Sentinel + SOAR + Enrichment + AI Triage)

This repository contains a complete AI-enabled Security Operations Center (SOC) MVP built entirely on Microsoft Azure. It demonstrates how modern SOC teams can automate triage, enrichment, and response using:

- **Azure Sentinel** (SIEM)
- **Azure Logic Apps** (SOAR)
- **Azure Functions** (Enrichment Engine)
- **AI Triage Agent** (Azure OpenAI)
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
                      │ Azure Functions Engine   │
                      │ (Enrichment + API Calls) │
                      └──────────────┬───────────┘
                                     │
                                     ▼
                      ┌──────────────────────────┐
                      │   AI Triage Agent        │
                      │ (Azure OpenAI)           │
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

- Sentinel free tier (up to 10 GB/day ingestion is free in most regions)
- Azure Functions consumption plan (free up to 1M executions/month)
- Azure OpenAI used only for real incidents (low volume), small token budgets, temperature 0
- Local Cribl (no cloud cost)
- GitHub Actions free tier

## Deployment

1. Deploy Azure resources: `cd terraform-azure-soc && terraform init && terraform apply`
2. Import KQL rules into Sentinel → Analytics → Scheduled rules.
3. Deploy enrichment Function via GitHub Actions or `func azure functionapp publish`.
4. Import `logicapps-soc-playbook.json` into Logic Apps.
5. Run AI triage agent locally or deploy to App Service / Container Apps.
6. Connect Sysmon / Activity Logs so Sentinel has telemetry.

## Demo & Screenshots

Screenshots and demo media will be added here as the live environment is captured.

| Area | Screenshot | Status |
|---|---|---|
| Architecture | `docs/screenshots/architecture.png` | Placeholder — add draw.io export |
| Sentinel | `docs/screenshots/sentinel-incident.png` | Placeholder — incident before/after AI triage |
| Logic Apps | `docs/screenshots/logicapps-run-history.png` | Placeholder — successful run history |
| Function | `docs/screenshots/function-enrichment-logs.png` | Placeholder — enrichment logs + test run |
| AI Triage | `docs/screenshots/ai-triage-json.png` | Placeholder — POST /triage JSON response |
| Metrics | `docs/screenshots/metrics-dashboard.png` | Placeholder — TTT + Automation Success KPI |
| CI/CD | `docs/screenshots/gh-actions-run.png` | Placeholder — GitHub Actions run |

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