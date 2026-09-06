# Building an AI-Powered SOC on Azure: Four Pivots, a $20 Cap, and Zero Cloud Bill

I built a fully automated AI-assisted Security Operations Center (SOC) on Azure — and it almost never got off the ground. Four separate blockers forced me to throw out "the obvious" solution each time. The result was a better architecture, a working end-to-end demo, and a running cost of roughly zero.

**The pipeline I wanted:**
Sentinel detects an incident → Logic App enriches it (GeoIP) → an AI triage agent summarizes it and recommends an action → the decision is written back into the Sentinel incident → the SOC team gets an email. All in Terraform, all reproducible, all under $20/month.

**Blocker #1 — an App Service quota that didn't exist.**
`terraform apply` failed on the App Service Plan: the subscription had *zero* Y1 consumption-plan quota. Raising it via the Azure Quota API? Rejected — Microsoft.Web isn't a supported provider there, so only a manual support ticket would do.

Instead of waiting, I pivoted to **Azure Container Apps**: healthy quotas, container-native (which suited my FastAPI microservices anyway), and **scale-to-zero** — the demo costs nothing when idle. The "workaround" was the better architecture.

**Blocker #2 — Terraform destroyed my OAuth tokens.**
`azurerm_api_connection` recreated my Azure Sentinel and Office 365 connections, wiping the interactive authorizations. Fix: **IaC owns resources without secrets; the portal owns anything needing interactive consent.** Terraform references connections by name; the portal holds the tokens.

**Blocker #3 — "Your tenant needs Microsoft Entra ID P2."**
My developer tenant can't authorize the Sentinel connector — a hard license wall. Solution: **drop the connector entirely.** Give the Logic App a system-assigned identity, grant it the Microsoft Sentinel Responder role, and call the Sentinel REST API via a plain HTTP action with `ManagedServiceIdentity` auth. No OAuth, no P2 license, fully reproducible.

**Blocker #4 — SendGrid removed its free tier.**
Swapped to **SMTP2GO** (1,000 emails/month free) via the same HTTP pattern. Because the provider is a Terraform variable, it was a config change, not a rewrite.

**The payoff — a fully green closed loop:**
Synthetic sign-in data → custom Log Analytics table → Sentinel rule fires → incident created → Logic App enriches → AI triage returns a structured decision → comment written to the incident (managed identity) → email sent (SMTP2GO). All five actions Succeeded, verified in the run history and in the incident itself.

**Three lessons I'd want my past self to know:**
1. Read the full error body, not the HTTP status — a `401` hid a quota message that was the real story.
2. Check quotas and provider registration *before* `terraform apply` — five minutes of API calls would have skipped Blocker #1.
3. For any workflow that calls an Azure resource, reach for **managed identity first** — it's cleaner and license-free.

The full reproducible project (Terraform, Container Apps services, detection pack, CI/CD, and the complete pivot documentation) is on GitHub:

**🔗 github.com/koatedevopskpai/azure-ai-soc-triage**

If you're building SOC automation, AI security, or multi-cloud telemetry pipelines — I'd love to connect and swap war stories.

---

*Full deep-dive version of this story (11 lessons, all the code patterns, and the exact failure messages) is on my blog: [link to Medium/dev.to post].*

#Azure #MicrosoftSentinel #SOC #AI #SecurityEngineering #Terraform #ContainerApps #InfrastructureAsCode