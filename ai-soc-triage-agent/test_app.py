from fastapi.testclient import TestClient

from app import app, EnrichedAlert

client = TestClient(app)


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_triage_mock_block():
    alert = EnrichedAlert(
        IPAddress="185.220.101.10",
        AlertName="Brute Force",
        AbuseScore=95,
        Geo={"country": "RU"},
    )
    r = client.post("/triage", json=alert.model_dump())
    assert r.status_code == 200
    body = r.json()
    assert body["recommended_action"] == "Block_IP"
    assert body["severity"] == "High"


def test_triage_mock_ignore():
    alert = EnrichedAlert(IPAddress="8.8.8.8", AlertName="Test", Geo={"country": "US"})
    r = client.post("/triage", json=alert.model_dump())
    assert r.status_code == 200
    assert r.json()["recommended_action"] == "Ignore"