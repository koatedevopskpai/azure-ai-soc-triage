# Azure Enrichment Engine (Azure Function)

## Overview

This Azure Function enriches Sentinel alerts with:
- **GeoIP** data (free via ip-api.com)
- **AbuseIPDB** threat intelligence (free tier: 1,000 lookups/day)
- Structured JSON output

It is triggered by Logic Apps during the SOAR workflow.

## Endpoints

- `POST /api/EnrichIP` — accepts JSON `{ "IPAddress": "...", "UserPrincipalName": "...", "AlertName": "..." }`

## Deployment

Use GitHub Actions or the Functions CLI:

```bash
func azure functionapp publish <FUNCTION_APP_NAME>
```

## Folder Structure

```
azure-enrichment-engine/
  EnrichIP/
    __init__.py
    function.json
  requirements.txt
  host.json
  local.settings.json   (local only, gitignored)
```

## Run Locally

```bash
pip install -r requirements.txt
func start
curl -X POST http://localhost:7071/api/EnrichIP \
  -H "Content-Type: application/json" \
  -d '{"IPAddress": "8.8.8.8", "AlertName": "Brute Force"}'
```

## Cost Notes

- Runs on the **Consumption plan** (free up to 1M executions/month).
- External calls are wrapped in `try/except` with timeouts so failures don't hang or retry-cost.
- Free tier APIs keep cost at $0; add `ABUSEIPDB_API_KEY` only if you need abuse scores.

## Notes

Add additional enrichment sources (VirusTotal, WHOIS, internal APIs) as needed.