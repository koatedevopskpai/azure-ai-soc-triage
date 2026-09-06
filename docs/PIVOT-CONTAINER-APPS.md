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
5. Built images locally → pushed to GitHub Container Registry (GHCR) via GitHub Actions → deployed to Container Apps.
6. Wired the Logic Apps SOAR playbook via Terraform to the two container app URLs.
7. **Pivot: stopped managing API connections in Terraform** (see §4b).

## 4b. Pivot: API Connections Stay Portal-Managed (Terraform Lesson)

### The problem

The SOAR playbook needs two managed connectors — **Microsoft Sentinel** (`azuresentinel`) and **Office 365 Outlook** (`office365`) — to update incidents and send email. We initially modeled them in Terraform:

```hcl
resource "azurerm_api_connection" "azuresentinel" {
  name                = "azuresentinel"
  resource_group_name = azurerm_resource_group.soc.name
  managed_api_id      = "/subscriptions/<sub>/providers/Microsoft.Web/locations/uksouth/managedApis/azuresentinel"
  display_name        = "azuresentinel"
}
```

After a `terraform apply`, both connections showed:

```
status: Error
error.code: Unauthenticated
error.message: This connection is not authenticated.
```

### Root cause

`azurerm_api_connection` **recreated the connection resources**, which **wiped the OAuth tokens** that had been granted interactively in the portal. The connector list in the Logic App designer only populates once a connection exists, and the connection's `createdTime`/`changedTime` showed Terraform's creation time, proving it had overwritten the portal-authorized versions.

### The fix

Keep the **connections portal-managed** and let Terraform **reference them by name only**:

1. Removed the `azurerm_api_connection` blocks from Terraform.
2. Removed the connection resources from state (`terraform state rm azurerm_api_connection.*`) so Terraform can never touch them again.
3. Created + authorized both connections **in the portal** with the exact names the Logic App expects (`azuresentinel`, `office365`).
4. The Logic App's workflow references them via `$connections` — Terraform only deploys the workflow definition.

### Why this matters

- **OAuth consent is inherently interactive** — it cannot (and should not) be automated away by IaC.
- A reproducible pipeline is great, but **not at the cost of destroying one-time security authorizations**.
- The pragmatic split: **IaC owns resources without secrets/tokens; the portal owns anything that needs interactive consent.** Document the one-time portal steps and keep names stable.

## 4c. Pivot: Managed Identity instead of Entra P2 (The Real Unblock)

### The second blocker

Even with portal-managed connections, **authorizing the `azuresentinel` / `office365` connectors failed**:

> "The tenant needs to have Microsoft Entra ID P2 or Microsoft Entra ID Governance license."

The tenant (likely a trial/developer tenant) **lacks Entra ID P2**, so the interactive OAuth consent flow for these connectors cannot complete.

### The solution: managed identity, no interactive OAuth

The `azuresentinel` connector supports `ManagedServiceIdentity` auth, but the more robust and fully reproducible path was to **drop the connector entirely**:

1. Give the Logic App a **system-assigned identity** (in the ARM template: `"identity": { "type": "SystemAssigned" }`).
2. Grant that identity the **Microsoft Sentinel Responder** role on the Log Analytics workspace (role id `3e150937-b8fe-4cfb-8069-0eaf05ecd056`).
3. Replace the `Update_incident` ApiConnection action with a plain **HTTP action**:
   - `PUT https://management.azure.com/.../incidents/{incident}/comments/{guid}`
   - `authentication: { "type": "ManagedServiceIdentity", "audience": "https://management.azure.com" }`
4. Verified end-to-end: enrichment → AI triage → **comment written to the Sentinel incident**.

### Result

- **No Entra P2, no interactive OAuth, no `azuresentinel` connection needed.**
- The critical closed-loop (AI triage → incident comment) now works with **zero P2/license dependency**.
- The only remaining interactive step is the **Office 365 email** (`Notify_SOC`), which still needs a mailbox authorization — that one can be skipped for the demo or replaced with a free SMTP alternative.

### Pitfalls hit along the way

- `authentication.type` must be **`ManagedServiceIdentity`** (not `ManagedIdentity`) or the action fails with a deserialization error.
- `guid('seed')` is invalid in Logic Apps — use `guid()` (random) or a valid format (`N/D/B/P/X`).
- `workflow().subscriptionId` doesn't exist; derive from `split(workflow().id, '/')[2]` / `[4]`, or better, pass `IncidentARMId` in the trigger body.

## 5. Lessons Learned (Blog-Worthy)

1. **Read the full error body, not the HTTP status.** `401 Unauthorized` was misleading — the quota message was the real signal.
2. **Check quotas BEFORE `terraform apply`.** A two-minute `GET` on the quota API saves a failed apply and a confusing state.
3. **Quota APIs have provider coverage limits.** Not every resource provider supports programmatic quota increases; know which ones do before building automation around them.
4. **Provider registration affects the portal too.** "No data to display" in Usage + quotas was caused by `Microsoft.Quota` being unregistered.
5. **When a quota is a hard blocker, rethink the platform, not just the SKU.** The pivot to Container Apps wasn't just a workaround — scale-to-zero + container-native agents were a better fit for the AI-SOC architecture.
6. **Terraform state stays consistent even on partial apply.** Resources already created were recorded in state; the failed ones were simply absent. A re-run (`terraform plan`) cleanly showed exactly what was missing.
7. **`azurerm_api_connection` recreates connections and wipes OAuth tokens.** Don't model interactive-consent connectors in Terraform; keep them portal-managed and reference them by name. (See §4b.)
8. **A "failed" apply can still create resources.** Container Apps and the Logic App deployment were created in Azure even when Terraform reported failure — requiring `terraform import` or delete-and-recreate. Check actual resource state before assuming a clean slate.
9. **The Logic Apps connector `$connections` value must use the `Microsoft.Web/locations/{region}/managedApis/{connector}` id format** — using `Microsoft.PowerApps/apis` causes `ConnectionsParameterInvalid: missing the required property 'id'`.
10. **Managed connectors can require Entra ID P2 to authorize** — for Sentinel, **managed identity on an HTTP action sidesteps the license requirement entirely** and is more reproducible than the connector. Prefer MI for Azure-resource actions. (See §4c.)

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