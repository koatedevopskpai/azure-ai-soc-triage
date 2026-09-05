import os
import json
import logging
from typing import Literal

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="AI SOC Triage Agent", version="1.0.0")


class EnrichedAlert(BaseModel):
    IPAddress: str
    Geo: dict | None = None
    AbuseScore: int | None = None
    AlertName: str | None = None
    UserPrincipalName: str | None = None


class TriageDecision(BaseModel):
    summary: str = Field(description="2-sentence summary of the alert")
    severity: Literal["Critical", "High", "Medium", "Low"]
    recommended_action: Literal["Block_IP", "Disable_User", "Investigate", "Ignore"]
    runbook_reference: str = Field(description="Runbook section ID")


SYSTEM_PROMPT = """
You are an SOC triage assistant. You must:
- Summarise the alert in 2 sentences.
- Assign severity: Critical, High, Medium, Low.
- Recommend ONE action: Block_IP, Disable_User, Investigate, Ignore.
- Map to a runbook section ID (e.g., RB-LOGIN-01, RB-NET-02).
Return ONLY JSON with keys: summary, severity, recommended_action, runbook_reference.
Do NOT include any free-form text outside JSON.
"""

# Mock mode: when AI_MOCK_MODE=true (or no Azure OpenAI config present),
# return a deterministic heuristic decision with ZERO token spend.
AI_MOCK_MODE = os.getenv("AI_MOCK_MODE", "true").lower() == "true"

_client = None
if not AI_MOCK_MODE:
    try:
        from openai import AzureOpenAI

        _client = AzureOpenAI(
            azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
            api_key=os.getenv("AZURE_OPENAI_KEY"),
            api_version=os.getenv("AZURE_OPENAI_API_VERSION", "2024-02-01"),
        )
    except Exception as e:  # pragma: no cover
        logger.warning("Azure OpenAI client failed to initialise: %s", e)
        _client = None


def _mock_triage(alert: EnrichedAlert) -> TriageDecision:
    """Deterministic, zero-cost triage used during development / demo."""
    score = alert.AbuseScore or 0
    geo = alert.Geo or {}
    country = (geo.get("country") or "Unknown").lower()
    suspicious_country = country in ("ru", "cn", "kp", "ir", "ng")

    if score >= 80 or (score >= 50 and suspicious_country):
        return TriageDecision(
            summary=f"High-confidence abusive IP {alert.IPAddress} with abuse score {score}.",
            severity="High",
            recommended_action="Block_IP",
            runbook_reference="RB-NET-02",
        )
    if suspicious_country or score >= 40:
        return TriageDecision(
            summary=f"Alert {alert.AlertName or 'Unnamed'} from suspicious origin {country}.",
            severity="Medium",
            recommended_action="Investigate",
            runbook_reference="RB-LOGIN-01",
        )
    return TriageDecision(
        summary=f"Alert {alert.AlertName or 'Unnamed'} from {alert.IPAddress} appears benign.",
        severity="Low",
        recommended_action="Ignore",
        runbook_reference="RB-GEN-00",
    )


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "mock_mode": AI_MOCK_MODE}


@app.post("/triage", response_model=TriageDecision)
async def triage(alert: EnrichedAlert) -> TriageDecision:
    try:
        if AI_MOCK_MODE or _client is None:
            logger.info("Mock triage (AI_MOCK_MODE=%s)", AI_MOCK_MODE)
            return _mock_triage(alert)

        content = f"Enriched alert:\n{alert.model_dump_json()}"
        resp = _client.chat.completions.create(
            model=os.getenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4o-mini"),
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": content},
            ],
            temperature=0.0,
            max_tokens=256,
        )
        raw = resp.choices[0].message.content
        logger.info("LLM raw response: %s", raw)
        data = json.loads(raw)
        return TriageDecision(**data)
    except Exception as e:
        logger.error("Triage error: %s", e)
        raise HTTPException(status_code=500, detail="Triage failed")