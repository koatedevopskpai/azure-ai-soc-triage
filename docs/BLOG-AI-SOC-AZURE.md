# Building an AI-Powered SOC in Azure: Four Pivots, Zero Cloud Bill

**A real-world engineering story about building an AI-assisted Security Operations Center (SOC) on Azure for under $20/month — and the four blockers that forced us to rethink "the obvious" architecture.**

---

## The Goal

I set out to build a fully automated, AI-assisted SOC pipeline on Azure:

```
Sentinel detects an incident
  → Logic App (SOAR) enriches it (GeoIP)
  → AI triage agent summarizes it, assigns severity, recommends an action
  → The decision is written back into the Sentinel incident
  → The SOC team gets an email
```

All of it **Infrastructure-as-Code (Terraform)**, all of it reproducible, and — critically — **under $20/month** so it could run as a live portfolio piece.

Four times, Azure threw a blocker at me. Each time, the "textbook" answer was a dead end, and the real solution was a pivot that made the architecture *better*, not just *workable*. Here's how it went.

---

## Blocker #1: The App Service Quota That Didn't Exist

The original plan put the two services (enrichment engine + AI triage agent) on **Azure Functions** — the natural choice for HTTP-driven serverless logic.

`terraform apply` created the resource group, Log Analytics workspace, Sentinel, storage, and Key Vault. Then it failed at the App Service Plan:

```
Error: creating App Service Plan ... unexpected status 401 (401 Unauthorized)
{"Code":"Unauthorized","Message":"Operation cannot be completed without
additional quota. ... Current Limit (Y1 VMs): 0 ...
Amount required for this deployment (Y1 VMs): 1 ..."}
```

The `401 Unauthorized` status is a **red herring**. The real problem is in the body: **the subscription had zero App Service consumption-plan (Y1) quota.**

### Investigating

- **Was it regional?** No. `eastus` and `uksouth` both reported `Y1 VMs limit = 0`.
- **Provider registered?** `Microsoft.Web` → Registered. `Microsoft.OperationalInsights` → Registered.
- **Can I raise it via the Azure Quota API?** I tried `PUT .../Microsoft.Quota/quotas/Y1`. Both regions returned `provisioningState: Failed, error.code: QuotaNotAvailableForResource`.

The root cause: **the Azure Quota API only supports a handful of resource providers** (Compute, Networking, Storage, ML, HPC Cache, Purview). **Microsoft.Web (App Service) isn't among them** — quota increases there require a manual, human-reviewed support ticket.

Even the portal was confusing: "Usage + quotas" showed *"No data to display"* for Y1 VMs — because the `Microsoft.Quota` resource provider wasn't registered on the subscription yet.

### The pivot

I stopped fighting for App Service and looked at what the platform *wanted*:

| Criterion | App Service (blocked) | **Azure Container Apps** |
|---|---|---|
| Quota needed | Y1 plan = **0** | ManagedEnvironmentCount = **20** |
| Scale-to-zero | No | **Yes (default)** |
| Monthly cost | Would be $ | **~$0–2** (free grant: 180k vCPU-s, 360k GiB-s, 2M req) |
| Fits AI/agentic microservices | Function-centric | **Container-native** |

Container Apps wasn't a workaround — **it was the better architecture.** My enrichment engine and AI triage agent are containerized FastAPI services, which is exactly what Container Apps runs natively. Scale-to-zero means the running portfolio demo costs **$0 when idle**.

---

## Blocker #2: Terraform Destroyed My OAuth Tokens

Next, the SOAR playbook needed managed connectors — **Microsoft Sentinel** (to update incidents) and **Office 365 Outlook** (to send email). I modeled them in Terraform:

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
"this connection is not authenticated"
```

**Root cause:** `azurerm_api_connection` **recreated the connection resources**, which **wiped the OAuth tokens** I'd authorized interactively in the portal. IaC silently destroyed one-time security grants.

### The fix

**IaC owns resources without secrets; the portal owns anything that needs interactive consent.**

1. Removed the `azurerm_api_connection` blocks from Terraform.
2. `terraform state rm` the connections so Terraform could never touch them again.
3. Created + authorized both in the portal, with the exact names the Logic App expects.
4. Terraform deploys only the workflow definition, which *references* the connections by name.

**Lesson:** OAuth consent is inherently interactive. Don't fight it with IaC — document the one-time portal step and keep names stable.

---

## Blocker #3: "Your Tenant Needs Microsoft Entra ID P2"

With portal-managed connections in place, I went to authorize them. Azure refused:

> **The tenant needs to have Microsoft Entra ID P2 or Microsoft Entra ID Governance license.**

My tenant (a developer/trial tenant) **doesn't have Entra P2**. The interactive OAuth flow for these connectors can't complete. This is a hard license wall — not something more portal-clicking fixes.

### The solution: managed identity, no OAuth at all

The `azuresentinel` connector happens to support `ManagedServiceIdentity` auth. But the cleanest, most reproducible path was to **drop the connector entirely** and call the Sentinel REST API directly:

1. Give the Logic App a **system-assigned identity**:
   ```json
   "identity": { "type": "SystemAssigned" }
   ```
2. Grant that identity the **Microsoft Sentinel Responder** role on the workspace.
3. Replace the `ApiConnection` action with a plain **HTTP action**:
   ```json
   {
     "method": "PUT",
     "uri": "https://management.azure.com/.../incidents/{incident}/comments/{guid}",
     "authentication": {
       "type": "ManagedServiceIdentity",
       "audience": "https://management.azure.com"
     }
   }
   ```

**Result:** no Entra P2, no OAuth, no connector needed. The AI triage decision is written back into the Sentinel incident using the Logic App's own identity — fully IaC-reproducible.

**Pitfalls I hit (so you don't):**
- The auth type must be **`ManagedServiceIdentity`**, not `ManagedIdentity` (deserialization error otherwise).
- `guid('seed')` is invalid in Logic Apps — use `guid()` or a valid format.
- `workflow().subscriptionId` doesn't exist — pass `IncidentARMId` in the trigger body instead.

---

## Blocker #4: SendGrid Dropped Its Free Tier

For email, I'd replaced Office 365 with SendGrid via a plain HTTP action. Then **SendGrid removed its free tier**.

### The pivot: SMTP2GO

| Provider | Free tier |
|---|---|
| SendGrid | ❌ Removed |
| MailerSend | 500/mo |
| **SMTP2GO** | **1,000/mo, 200/day, no time limit** |

SMTP2GO has a simple HTTP REST API — same pattern as the SendGrid step:

```
POST https://api.smtp2go.com/v3/email/send
Header: X-Smtp2go-Api-Key: <key>
Body:   { sender, to: [...], subject, text_body }
```

No SMTP connector, no OAuth, no Entra dependency. Because the provider choice is a **Terraform variable** (`smtp2go_api_key`, sensitive, empty by default), swapping providers is a config change, not a rewrite.

---

## The Working End-to-End Flow

With all four pivots done, the full closed loop runs green:

```
Synthetic sign-in data → AISOCSigninLogs_CL (custom table, ~$0 to ingest)
  → Sentinel analytics rule fires ("AI-SOC Brute Force - T1110")
  → Incident created automatically
  → Logic App playbook:
      1. Call_Enrichment    → GeoIP (Container App)       ✅
      2. Call_AI_Triage     → structured decision (Container App) ✅
      3. Compose_Comment    → AI triage decision          ✅
      4. Update_incident    → comment written to incident ✅ (Managed Identity)
      5. Notify_SOC         → SMTP2GO email               ✅
```

Verified in the incident itself:

```json
"message": "AI Triage Decision: {
  \"summary\": \"Alert AI-SOC Brute Force - Multiple Failed Sign-ins (T1110) from 185.220.101.10...\",
  \"severity\": \"Low\",
  \"recommended_action\": \"Ignore\",
  \"runbook_reference\": \"RB-GEN-00\"
}"
```

**Cost: ~$0–2/month.** Scale-to-zero containers, a free analytics rule, a few KB of custom-table ingestion, and a free email tier.

---

## The 11 Lessons

1. **Read the full error body, not the HTTP status.** `401 Unauthorized` was misleading — the quota message was the real signal.
2. **Check quotas BEFORE `terraform apply`.** A two-minute `GET` on the quota API saves a failed apply and a confusing state.
3. **Quota APIs have provider coverage limits.** Not every resource provider supports programmatic quota increases.
4. **Provider registration affects the portal too.** "No data to display" = `Microsoft.Quota` not registered.
5. **When a quota is a hard blocker, rethink the platform, not just the SKU.** Container Apps was a better fit, not a consolation prize.
6. **Terraform state stays consistent even on partial apply.** Re-run `terraform plan` to see exactly what's missing.
7. **`azurerm_api_connection` recreates connections and wipes OAuth tokens.** Keep interactive-consent resources portal-managed.
8. **A "failed" apply can still create resources.** Check actual resource state before assuming a clean slate.
9. **Logic Apps `$connections` needs the `Microsoft.Web/locations/{region}/managedApis/{connector}` id format.**
10. **Managed connectors can require Entra P2.** Managed identity on an HTTP action sidesteps the license entirely — prefer MI for Azure-resource actions.
11. **Email providers' free tiers change.** Pin the provider in IaC variables so swapping is a config change.

---

## What I'd Do Differently

- **Check quotas + provider registration up front** — 5 minutes of API calls would have skipped Blocker #1 entirely.
- **Plan for interactive-consent resources from the start** — decide up front: IaC or portal? Don't let Terraform near OAuth tokens.
- **Design for managed identity first** — for anything calling an Azure resource from a workflow, MI is cleaner and license-free.

---

## Want to see the code?

The full, reproducible project is on GitHub:

**[github.com/koatedevopskpai/azure-ai-soc-triage](https://github.com/koatedevopskpai/azure-ai-soc-triage)**

It includes the Terraform (Container Apps, Logic App, Sentinel), the two containerized services (enrichment + AI triage), the detection pack (including the custom-table demo rule + synthetic-data ingestion script), the CI/CD pipeline, and the full cost-budget and pivot documentation.

*Building an AI-SOC taught me that the interesting engineering isn't in the happy path — it's in the four blockers that forced a better architecture.*

---

*If you're building SOC automation, AI security, or multi-cloud telemetry pipelines — I'd love to connect and hear how you're solving the same problems.*