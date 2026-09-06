# Deployment Reference: Live Container Apps & Screenshot Checklist

> **Last verified:** 2026-09-06
> **Resource group:** `rg-ai-soc-mvp`
> **Container Apps environment:** `cae-soc-mvp` (UK South)

## Live Endpoints

| Service | Base URL |
|---|---|
| AI Triage Agent | `https://ca-ai-triage-b9lo2q--sz8ngr1.ambitiousmeadow-3dfc826d.uksouth.azurecontainerapps.io` |
| Enrichment Engine | `https://ca-enrichment-b9lo2q--btionpk.ambitiousmeadow-3dfc826d.uksouth.azurecontainerapps.io` |

Stable (revision-independent) FQDNs:

| Service | FQDN |
|---|---|
| AI Triage Agent | `https://ca-ai-triage-b9lo2q.ambitiousmeadow-3dfc826d.uksouth.azurecontainerapps.io` |
| Enrichment Engine | `https://ca-enrichment-b9lo2q.ambitiousmeadow-3dfc826d.uksouth.azurecontainerapps.io` |

> The `--<suffix>` URLs above pin to a specific revision. The stable FQDNs route to the current active revision — use those for the Logic App playbook and demos.

## Live Endpoint Map

| Endpoint | Method | Purpose | Sample Response |
|---|---|---|---|
| `/health` (AI Triage) | GET | Liveness | `{"status":"ok","mock_mode":true}` |
| `/triage` (AI Triage) | POST | AI triage decision | `{"summary":"...","severity":"High","recommended_action":"Block_IP","runbook_reference":"RB-NET-02"}` |
| `/health` (Enrichment) | GET | Liveness | `{"status":"ok"}` |
| `/api/EnrichIP` (Enrichment) | POST | Enrich IP with GeoIP + AbuseIPDB | `{"IPAddress":"8.8.8.8","Geo":{"country":"United States","city":"Ashburn","isp":"Google LLC",...}}` |

## Test Requests

```powershell
# AI Triage (mock mode)
$triage = '{"IPAddress":"185.220.101.10","AlertName":"Brute Force","AbuseScore":95,"Geo":{"country":"RU"}}'
Set-Content -LiteralPath "$env:TEMP\triage.json" -Value $triage -NoNewline -Encoding ascii
curl.exe -s -X POST "https://ca-ai-triage-b9lo2q.ambitiousmeadow-3dfc826d.uksouth.azurecontainerapps.io/triage" -H "Content-Type: application/json" --data-binary "@$env:TEMP\triage.json"

# Enrichment
$enrich = '{"IPAddress":"8.8.8.8","AlertName":"Test"}'
Set-Content -LiteralPath "$env:TEMP\enrich.json" -Value $enrich -NoNewline -Encoding ascii
curl.exe -s -X POST "https://ca-enrichment-b9lo2q.ambitiousmeadow-3dfc826d.uksouth.azurecontainerapps.io/api/EnrichIP" -H "Content-Type: application/json" --data-binary "@$env:TEMP\enrich.json"
```

> PowerShell aliases `curl` to `Invoke-WebRequest`; use `curl.exe` explicitly.

## Azure Portal Navigation

- Container Apps: Azure Portal → `rg-ai-soc-mvp` → `ca-ai-triage-b9lo2q` / `ca-enrichment-b9lo2q`
- Container Apps environment: Azure Portal → `rg-ai-soc-mvp` → `cae-soc-mvp`
- Sentinel workspace: `log-soc-mvp` (workspace ID `872af58a-45db-4e38-a411-b61504195236`)
- Key Vault: `kv-soc-mvp-b9lo2q`

---

## Screenshot Checklist

> Capture each and save to `docs/screenshots/`. Update the table in the root `README.md` and remove the "Placeholder" status as each is captured.

### A. Infrastructure (Terraform / Resource Group)
- [ ] **`terraform-outputs.png`** — terminal showing `terraform output` (URLs, workspace ID, RG name)
- [ ] **`resource-group.png`** — Azure Portal `rg-ai-soc-mvp` showing all resources
- [ ] **`container-apps-list.png`** — Container Apps list (2 apps, Succeeded, UK South)

### B. Container Apps (running services)
- [ ] **`ca-ai-triage-overview.png`** — AI Triage container app overview page (running, revision, image)
- [ ] **`ca-ai-triage-triage-response.png`** — `POST /triage` JSON response in browser/terminal
- [ ] **`ca-enrichment-overview.png`** — Enrichment container app overview page
- [ ] **`ca-enrichment-enrich-response.png`** — `POST /api/EnrichIP` JSON response (GeoIP shown)

### C. Container Apps environment
- [ ] **`cae-overview.png`** — Container Apps environment page (consumption profile, UK South)

### D. GitHub
- [ ] **`ghcr-packages.png`** — GHCR package listing (both images, public)
- [ ] **`gh-actions-run.png`** — GitHub Actions workflow run (3 jobs green)
- [ ] **`gh-repo-home.png`** — Repo home page with README rendered

### E. Sentinel (once detection rules are imported)
- [ ] **`sentinel-analytics-rules.png`** — Analytics rules list showing Brute Force (T1110) + Ransomware (T1486)
- [ ] **`sentinel-incident-before.png`** — An incident before automation runs
- [ ] **`sentinel-incident-after.png`** — Same incident after AI triage comment added

### F. Logic Apps SOAR (once playbook is deployed)
- [ ] **`logicapps-designer.png`** — Playbook designer showing full workflow
- [ ] **`logicapps-run-history.png`** — Successful run history
- [ ] **`logicapps-run-detail.png`** — Run detail showing enrichment + AI triage outputs

### G. Metrics
- [ ] **`metrics-workbook.png`** — Sentinel workbook with TTT + Automation Success Rate

### H. Cost
- [ ] **`cost-analysis.png`** — Azure Cost Analysis showing ~$0–2/month (great portfolio proof)

## Demo Video Script Reference

See the README's demo section. Scenes map 1:1 to the sections above (B → F covers the full end-to-end: trigger → SOAR → enrich → AI triage → incident update).