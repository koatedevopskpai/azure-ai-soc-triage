# AI Triage Agent (Azure OpenAI)

## Overview

This FastAPI service performs AI-assisted triage:
- Summarises alerts
- Assigns severity (Critical / High / Medium / Low)
- Recommends an action (Block_IP / Disable_User / Investigate / Ignore)
- Maps a runbook reference
- Returns strict JSON (Pydantic-validated)

## Endpoints

- `GET /health` — health + mock-mode status
- `POST /triage` — accepts an enriched alert, returns a `TriageDecision`

## Run Locally (Mock Mode — $0)

```bash
pip install -r requirements.txt
uvicorn app:app --reload --port 8000
curl -X POST http://localhost:8000/triage \
  -H "Content-Type: application/json" \
  -d '{"IPAddress": "185.220.101.10", "AlertName": "Brute Force", "AbuseScore": 95, "Geo": {"country": "RU"}}'
```

By default `AI_MOCK_MODE=true` so the service returns a **deterministic heuristic triage with zero Azure OpenAI spend**. This is perfect for local dev, CI, and portfolio demos.

## Enable Real LLM (Azure OpenAI)

Set these environment variables and `AI_MOCK_MODE=false`:

```bash
export AI_MOCK_MODE=false
export AZURE_OPENAI_ENDPOINT=https://<resource>.openai.azure.com/
export AZURE_OPENAI_KEY=<key>
export AZURE_OPENAI_DEPLOYMENT=gpt-4o-mini
```

## Cost Control

- Model: `gpt-4o-mini` (cheapest) — pinned in code default.
- `temperature=0.0`, `max_tokens=256` → predictable, small token spend.
- Only invoked for real incidents; dev/demo runs use mock mode.

## Tests

```bash
pip install pytest
pytest test_app.py
```

The tests cover health, mock block, and mock ignore paths — no cloud calls.

## Deployment

Deploy to Azure App Service or Container Apps. See `azure-soc-cicd` for CI/CD.