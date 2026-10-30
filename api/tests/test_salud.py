from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import app


def test_salud():
    client = TestClient(app)
    response = client.get("/salud")
    assert response.status_code in (200, 503)
    body = response.json()
    assert body["api"] == "ok"
    assert "db" in body
