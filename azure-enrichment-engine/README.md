# Azure Enrichment Engine

## Overview

The enrichment engine adds context to Sentinel alerts:
- **GeoIP** data (free via ip-api.com)
- **AbuseIPDB** threat intelligence (free tier: 1,000 lookups/day)
- Structured JSON output

It is called by Logic Apps during the SOAR workflow.

There are two deployment flavors:
1. **Container App (recommended, default)** — `enrich_api.py` exposes a FastAPI HTTP service.
2. **Azure Function (legacy option)** — the `EnrichIP/` folder contains the original Azure Functions HTTP trigger.

> **Why two flavors?** The MVP originally targeted an Azure Function App, but the subscription's App Service (Y1) quota was zero and could not be increased via API. We pivoted to **Azure Container Apps** (scale-to-zero, no quota needed). See `docs/PIVOT-CONTAINER-APPS.md`.

## Endpoints (Container App)

- `GET /health` — health check
- `POST /api/EnrichIP` — accepts JSON `{ "IPAddress": "...", "UserPrincipalName": "...", "AlertName": "..." }`

## Deployment (Container App)

```bash
# build
docker build -t ghcr.io/<owner>/azure-ai-soc-triage/azure-enrichment-engine:latest .
# push
docker push ghcr.io/<owner>/azure-ai-soc-triage/azure-enrichment-engine:latest
```

The container app is defined in `terraform-azure-soc/main.tf` (`azurerm_container_app.enrichment`). GitHub Actions builds/pushes images on push to `main`.

## Folder Structure

```
azure-enrichment-engine/
  enrich_api.py          # FastAPI HTTP service (Container App flavor)
  Dockerfile
  requirements-container.txt   # for the container image
  requirements.txt             # for the Azure Function flavor
  EnrichIP/
    __init__.py
    function.json
  host.json
  local.settings.json   (local only, gitignored)
```

## Run Locally (Container flavor)

```bash
pip install -r requirements-container.txt
uvicorn enrich_api:app --host 0.0.0.0 --port 8001
curl -X POST http://localhost:8001/api/EnrichIP \
  -H "Content-Type: application/json" \
  -d '{"IPAddress": "8.8.8.8", "AlertName": "Brute Force"}'
```

## Run Locally (Function flavor)

```bash
pip install -r requirements.txt
func start
curl -X POST http://localhost:7071/api/EnrichIP \
  -H "Content-Type: application/json" \
  -d '{"IPAddress": "8.8.8.8", "AlertName": "Brute Force"}'
```

## Cost Notes

- Runs on **Azure Container Apps (Consumption)** with **scale-to-zero** (default) → ~$0 when idle.
- External calls are wrapped in `try/except` with timeouts so failures don't hang or retry-cost.
- Free tier APIs keep cost at $0; add `ABUSEIPDB_API_KEY` only if you need abuse scores.

## Notes

Add additional enrichment sources (VirusTotal, WHOIS, internal APIs) as needed.