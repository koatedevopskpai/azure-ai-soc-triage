import os
import logging

import requests
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="SOC Enrichment Engine", version="1.0.0")


class AlertPayload(BaseModel):
    IPAddress: str
    UserPrincipalName: str | None = None
    AlertName: str | None = None


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/api/EnrichIP")
def enrich(payload: AlertPayload) -> dict:
    logger.info("Enrichment request for %s", payload.IPAddress)
    ip = payload.IPAddress
    enriched = {"IPAddress": ip}

    # GeoIP (free: ip-api.com)
    try:
        geo_resp = requests.get(
            f"http://ip-api.com/json/{ip}?fields=country,city,isp,lat,lon",
            timeout=5,
        )
        if geo_resp.status_code == 200:
            enriched["Geo"] = geo_resp.json()
    except Exception as e:
        logger.warning("GeoIP lookup failed: %s", e)

    # AbuseIPDB (optional; requires ABUSEIPDB_API_KEY)
    abuse_key = os.getenv("ABUSEIPDB_API_KEY")
    if abuse_key:
        try:
            headers = {"Key": abuse_key, "Accept": "application/json"}
            abuse_resp = requests.get(
                f"https://api.abuseipdb.com/api/v2/check?ipAddress={ip}&maxAgeInDays=30",
                headers=headers,
                timeout=10,
            )
            if abuse_resp.status_code == 200:
                data = abuse_resp.json().get("data", {})
                enriched["AbuseScore"] = data.get("abuseConfidenceScore")
        except Exception as e:
            logger.warning("AbuseIPDB lookup failed: %s", e)

    return enriched