# Logic Apps SOAR Playbook

## Overview

This Logic App orchestrates the full closed-loop SOAR workflow:

1. **Trigger** — Sentinel incident created (HTTP request from Sentinel playbook connector)
2. **Enrichment** — call Azure Function (`/EnrichIP`) for GeoIP + threat intel
3. **AI triage** — call AI Triage Agent (`/triage`) for summary, severity, action, runbook ref
4. **Compose** — build a comment string from the AI decision
5. **Update Sentinel incident** — write the AI triage output back into the incident as a comment
6. **Notify SOC** — email the team with enrichment + AI triage results

This is the **minimum viable AI-SOC pipeline**: `Sentinel → SOAR → Enrichment → AI Triage → Sentinel Incident Update`.

## Deployment

Import `logicapps-soc-playbook.json` via:

1. Azure Portal → Logic Apps → Create → Blank.
2. In the designer, switch to **Code view** and paste this definition.
3. Set parameters:
   - `functionUrl` → your Function App `/api/EnrichIP` URL + code
   - `aiTriageUrl` → your AI Triage Agent `/triage` URL
   - `sentinelConnectionName` → the Azure Sentinel API connection (created via Azure Sentinel → Playbooks → Add playbook)
4. Attach to a Sentinel Automation rule (or "Run playbook" from the incident page).

## Key Actions

- `Call_Enrichment_Function`
- `Call_AI_Triage`
- `Compose_Comment`
- `Update_Sentinel_Incident`
- `Notify_SOC`

## Cost Notes

- Runs on the **Consumption tier** (free allowance: 4,000 action runs + 500 workflow runs/month).
- Low run volume in the MVP easily stays within free tier.
- Add failure handling (`runAfter: Failed`) and retry policies only if needed — each retry costs an action run.

## Notes

Extend with automated containment actions (disable user, block IP) when moving toward production.