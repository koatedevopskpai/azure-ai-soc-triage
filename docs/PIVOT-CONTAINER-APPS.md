# Pivot Log: From App Service Quota Blocker to Azure Container Apps

> **Status:** In progress
> **Repo:** azure-ai-soc-triage
> **Date:** 2026-09-06
> **Intended audience:** This document is written to be adapted into a public blog post (Medium / LinkedIn / dev.to) to showcase real-world cloud engineering problem-solving.

---

## TL;DR

While deploying the Azure AI-SOC MVP, `terraform apply` failed on the App Service Plan with:

```
Current Limit (Y1 VMs): 0
Amount required for this deployment (Y1 VMs): 1
```

This was a **subscription-level App Service consumption-plan (Y1) quota of zero** — not a Terraform bug and not a regional capacity issue. Attempts to raise it via the Azure Quota API were rejected (`QuotaNotAvailableForResource`) because **Microsoft.Web is not a supported resource provider for programmatic quota increases** in the quota API.

We pivoted to **Azure Container Apps (consumption plan)**:
- Its quotas were healthy in UK South (`ManagedEnvironmentCount = 20`).
- It supports **scale-to-zero**, so the running MVP costs ~$0–2/month.
- Both the enrichment engine and the AI triage agent run as containers — a better fit for the "agentic" architecture anyway.

---

## 1. The Problem

### Symptom

`terraform apply` created the Resource Group, Log Analytics workspace, Sentinel onboarding, Storage Account, and Key Vault — then failed at the **Service Plan**:

```
Error: creating App Service Plan (Resource Group Name: "rg-ai-soc-mvp",
Server Farm Name: "plan-soc-mvp"): performing CreateOrUpdate:
unexpected status 401 (401 Unauthorized) with response:
{"Code":"Unauthorized","Message":"Operation cannot be completed without
additional quota. ... Current Limit (Y1 VMs): 0 ... Amount required for this
deployment (Y1 VMs): 1 ..."}
```

### Initial diagnosis

The error is misleadingly labelled `401 Unauthorized`, but the real cause is inside the body:

```
Current Limit (Y1 VMs): 0
Amount required for this deployment (Y1 VMs): 1
```

So the subscription literally had **zero App Service consumption-plan (Y1) quota**. The resource group is in `uksouth`; earlier work was in `eastus`.

## 2. Investigation

### 2.1 Was it the region?

We queried the App Service quota in both regions:

```
GET /subscriptions/{sub}/providers/Microsoft.Web/locations/eastus/providers/Microsoft.Quota/quotas/Y1
→ limit 0

GET /subscriptions/{sub}/providers/Microsoft.Web/locations/uksouth/providers/Microsoft.Quota/quotas/Y1
→ limit 0
```

Both were zero. **Not a regional issue** — a subscription-wide App Service quota of zero.

### 2.2 Was the provider registered?

- `Microsoft.Web` → `Registered`
- `Microsoft.OperationalInsights` → `Registered`

So the provider was registered; it was purely a quota-allocation matter.

### 2.3 Could we raise it via the Azure Quota API?

We attempted a quota-increase request:

```
PUT /subscriptions/{sub}/providers/Microsoft.Web/locations/uksouth/providers/Microsoft.Quota/quotas/Y1
{
  "properties": {
    "name": { "value": "Y1" },
    "limit": { "limitObjectType": "LimitValue", "value": 1 },
    "resourceType": "serverfarms"
  }
}
```

Both UK South and East US requests ended in:

```
provisioningState: Failed
error.code: QuotaNotAvailableForResource
```

### 2.4 Root cause

The **Azure Quota API only supports** Compute, Networking, Storage, Machine Learning, HPC Cache, and Purview resource providers. **Microsoft.Web (App Service) quota increases are not available through the programmatic API** — they require a manual Azure Portal support request.

### 2.5 The portal path

The Azure Portal → Subscriptions → Usage + quotas blade initially showed *"No data to display"* for `Y1 VMs`. **This was because the `Microsoft.Quota` resource provider was not registered on the subscription.** After registering it (`az provider register -n Microsoft.Quota`), the blade populates.

A manual portal request is still the correct route for an App Service Y1 quota increase — but it requires a human-reviewed support ticket and can take time.

## 3. The Pivot: Azure Container Apps

### Why Container Apps?

| Criterion | App Service (Function/Web) | Azure Container Apps |
|---|---|---|
| Quota needed | Y1 consumption plan (was **0**) | `ManagedEnvironmentCount` (was **20**) |
| Scale-to-zero | No | **Yes (default)** |
| Fits < $20/mo budget | Yes, if quota existed | Yes — ~$0–2/mo with scale-to-zero + free grant |
| Fits "agentic" architecture | Function-centric | Container-native microservices |
| Quota increase required? | Yes (manual support ticket) | **No** |

### Cost picture for Container Apps (consumption plan)

- Free grant per month: **180,000 vCPU-seconds**, **360,000 GiB-seconds**, **2M requests** (per subscription).
- **Scale-to-zero is the default** — no replicas running = no compute charge when idle.
- A low-traffic demo service (a few requests/day for screenshots and portfolio demos) is effectively **~$0–2/month**.

### What changed in the architecture

```
Before (blocked)                          After (working)
────────────────────                      ────────────────────
Sentinel                                   Sentinel
  → Logic Apps (SOAR)                        → Logic Apps (SOAR)
  → Azure Function (enrichment)              → Container App: enrichment-engine
  → FastAPI service (AI triage)              → Container App: ai-triage-agent
  → Sentinel incident update                 → Sentinel incident update

App Service Plan (Y1) BLOCKED               Azure Container Apps environment
                                             - consumption profile
                                             - scale-to-zero
```

## 4. What We Did

1. Registered `Microsoft.App` provider (`az provider register -n Microsoft.App`).
2. Verified Container Apps quotas in UK South:
   - `ManagedEnvironmentCount` = 20 ✅
   - `SessionPools` = 20 ✅
3. Updated Terraform:
   - Removed `azurerm_service_plan` + `azurerm_linux_function_app`.
   - Added `azurerm_container_app_environment` (consumption profile) + two `azurerm_container_app`s.
   - Kept Resource Group, Sentinel/Log Analytics, Storage, Key Vault (all healthy).
4. Added Dockerfiles to `ai-soc-triage-agent` and `azure-enrichment-engine`.
5. Build images locally → push to Azure Container Registry → deploy to Container Apps.

## 5. Lessons Learned (Blog-Worthy)

1. **Read the full error body, not the HTTP status.** `401 Unauthorized` was misleading — the quota message was the real signal.
2. **Check quotas BEFORE `terraform apply`.** A two-minute `GET` on the quota API saves a failed apply and a confusing state.
3. **Quota APIs have provider coverage limits.** Not every resource provider supports programmatic quota increases; know which ones do before building automation around them.
4. **Provider registration affects the portal too.** "No data to display" in Usage + quotas was caused by `Microsoft.Quota` being unregistered.
5. **When a quota is a hard blocker, rethink the platform, not just the SKU.** The pivot to Container Apps wasn't just a workaround — scale-to-zero + container-native agents were a better fit for the AI-SOC architecture.
6. **Terraform state stays consistent even on partial apply.** Resources already created were recorded in state; the failed ones were simply absent. A re-run (`terraform plan`) cleanly showed exactly what was missing.

## 6. Metrics / Validation

> To be completed after deployment. Capture:
> - Container Apps environment + app names
> - `/health` and `/triage` responses from the deployed AI triage agent
> - Enrichment engine response
> - Cost analysis screenshot at month-end

---

## Appendix: Useful Commands

```bash
# Check App Service Y1 quota
az rest --method get --uri "https://management.azure.com/subscriptions/<sub>/providers/Microsoft.Web/locations/uksouth/providers/Microsoft.Quota/quotas/Y1?api-version=2025-09-01"

# Register providers
az provider register -n Microsoft.Quota
az provider register -n Microsoft.App

# Check Container Apps quotas
az rest --method get --uri "https://management.azure.com/subscriptions/<sub>/providers/Microsoft.App/locations/uksouth/providers/Microsoft.Quota/quotas?api-version=2025-09-01"
```