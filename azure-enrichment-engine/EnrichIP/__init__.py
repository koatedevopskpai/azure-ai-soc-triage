import azure.functions as func
import logging
import requests
import json
import os
from pydantic import BaseModel, ValidationError


class AlertPayload(BaseModel):
    IPAddress: str
    UserPrincipalName: str | None = None
    AlertName: str | None = None


def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("Enrichment function triggered")

    try:
        body = req.get_json()
        payload = AlertPayload(**body)
    except (ValueError, ValidationError) as e:
        return func.HttpResponse(
            f"Invalid payload: {str(e)}",
            status_code=400,
        )

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
        logging.warning(f"GeoIP lookup failed: {e}")

    # AbuseIPDB (optional; requires ABUSEIPDB_API_KEY in app settings)
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
            logging.warning(f"AbuseIPDB lookup failed: {e}")

    return func.HttpResponse(
        json.dumps(enriched),
        status_code=200,
        mimetype="application/json",
    )