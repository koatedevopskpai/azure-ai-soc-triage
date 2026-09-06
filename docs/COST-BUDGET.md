# Azure AI-SOC MVP — Cost Budget & Optimization (< $20/month)

This document is the cost-control playbook for the Azure AI-SOC MVP. The hard constraint is **total monthly cloud spend stays below $20/month**.

## Monthly Budget Ceiling

| Component | Free Allowance | Target Monthly Cost | Levers |
|---|---|---|---|
| Azure Sentinel | 31-day trial: first 10 GB/day ingestion free (new workspaces only; 20/tenant) | $0–$2 | Keep ingestion < 1 GB/day; exclude non-security tables; after trial, PAYG ~£4.28/GB in UK South |
| Azure Container Apps (consumption) | 180k vCPU-sec + 360k GiB-sec + 2M requests/mo free | $0–$2 | **Scale-to-zero** (default); max_replicas=1; 0.25 vCPU/0.5 GiB per app |
| Logic Apps (consumption) | Free tier: 4,000 action runs + 500 workflow runs/month | $0–$3 | Consumption plan; few actions per run |
| Azure OpenAI | No free tier (pay-per-token) | $5–$12 | gpt-4o-mini, temperature 0, max_tokens <= 256, only run on real incidents; mock mode default |
| GitHub Container Registry (GHCR) | Free for public images | $0 | Public repo/images; no ACR cost |
| Key Vault | 10,000 operations/month free | $0 | Standard tier, few secrets |
| Log Analytics | Basic tier per-GB | Included in Sentinel estimate | Keep retention 30 days |
| GitHub Actions | 2,000 min/month free (public repos) | $0 | Public repo, avoid re-running |
| Cribl Lite (local) | Local/self-hosted | $0 | Run on your machine |
| Power BI | Power BI Desktop free | $0 | Desktop only; no cloud service |

**Projected total: ~$5–$17/month** — comfortably under $20.

> **Note on the pivot:** The original plan used an Azure Function App on a consumption App Service Plan (Y1). That plan hit a **zero-quota block** on this subscription, and Container Apps was chosen instead — it avoids the App Service quota entirely, supports scale-to-zero, and uses a **free monthly grant**. See `docs/PIVOT-CONTAINER-APPS.md` for the full story.

## Cost-Control Rules (Hard Rules)

1. **Never ingest > 1 GB/day** into Log Analytics. Sentinel's 10 GB/day allowance is a **31-day free trial** for new workspaces, not a permanent free tier — after it expires, UK South PAYG is ~£4.28/GB. Keeping ingestion at 1 GB/day means ~$5–$6/month once the trial ends; < 1 GB/day stays near $0. Use `-` filters in KQL to drop noise.
2. **Keep retention to 30 days** (set in Terraform). No long-term retention for the MVP.
3. **Azure OpenAI only for real incidents.** Disable the AI step or use a local/mock LLM during development. Set `temperature=0.2` or `0`, `max_tokens=256`, model = `gpt-4o-mini` (cheapest).
4. **Container Apps on the Consumption profile only.** `min_replicas = 0` (scale-to-zero) and `max_replicas = 1` per app. Never use a Dedicated workload profile. 0.25 vCPU / 0.5 GiB per app is plenty.
5. **Logic Apps Consumption tier only.** Monitor action runs; the free tier covers 4,000 action runs/month.
6. **No AKS/GKE, no VMs, no managed SQL.** Everything is serverless.
7. **GitHub Actions on public repo** to get free minutes. Use `workflow_dispatch` and only run on demand for deploys.
8. **Delete/destroy resources when not testing.** `terraform destroy` between build sessions. Only keep the workspace if you're actively developing.
9. **Use free tiers of external enrichment APIs** (ip-api.com is free; AbuseIPDB free tier: 1,000 lookups/day). Wrap with try/except and timeouts so failures don't cost money.

## Worst-Case Scenarios (and How to Avoid)

| Risk | Mitigation |
|---|---|
| 31-day free trial expires and ingestion costs start | Keep ingestion < 1 GB/day (≤ ~$6/mo at UK South PAYG); destroy workspace when not testing |
| AI token blowout | Hard cap `max_tokens`; use `gpt-4o-mini`; disable AI call during dev/mock mode |
| High log ingestion | Filter noise in Cribl/KQL; exclude `SigninLogs` if not needed |
| Logic Apps runaway loops | Add `runAfter` failure handling; set run timeouts; no loops without termination |
| Container Apps replicas stuck running | `min_replicas=0` + `max_replicas=1`; monitor replica count in portal |
| Accidental premium SKUs | Terraform pins `workload_profile_type = "Consumption"`; review plan before apply |

## Monthly Reset Ritual (5 minutes)

1. `terraform plan` and review resource count.
2. Check Log Analytics usage in Azure Portal → Log Analytics workspace → Usage.
3. Check Azure OpenAI token usage → Cost analysis.
4. If spend > $15, destroy non-essential resources with `terraform destroy -target`.
5. Keep a screenshot of cost analysis for your portfolio (shows you engineer for cost).

## What This Enables

- **Low-ingestion-first** design means you can leave the MVP running and still stay under $20/month, including after the 31-day Sentinel trial ends.
- Demonstrates **cost-aware security engineering** — a differentiator for interviews.
- Keeps your portfolio live without financial stress during your 3-month cash-constrained runway.