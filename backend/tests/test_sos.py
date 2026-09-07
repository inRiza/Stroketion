import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.fixture
async def client() -> AsyncClient:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _register(client: AsyncClient, role: str) -> dict:
    suffix = uuid.uuid4().hex[:8]
    email = f"{role}.{suffix}@test.dev"
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "secret123",
            "full_name": email.split("@")[0],
            "role": role,
        },
    )
    assert response.status_code == 200
    return response.json()


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_sos_alert_flow(client: AsyncClient):
    patient = await _register(client, "patient")
    caregiver = await _register(client, "caregiver")

    patient_token = patient["access_token"]
    caregiver_token = caregiver["access_token"]
    caregiver_id = caregiver["user"]["id"]

    await client.post(
        "/api/v1/links/request-caregiver",
        json={"caregiver_id": caregiver_id},
        headers=_auth(patient_token),
    )
    pending = await client.get("/api/v1/links/pending", headers=_auth(caregiver_token))
    link_id = pending.json()[0]["link_id"]
    await client.post(f"/api/v1/links/{link_id}/approve", headers=_auth(caregiver_token))

    create = await client.post(
        "/api/v1/notifications/sos",
        json={"message": "Risiko tinggi terdeteksi"},
        headers=_auth(patient_token),
    )
    assert create.status_code == 200
    alert_id = create.json()["id"]

    pending_alerts = await client.get(
        "/api/v1/notifications/sos/pending",
        headers=_auth(caregiver_token),
    )
    assert pending_alerts.status_code == 200
    alerts = pending_alerts.json()
    assert len(alerts) == 1
    assert alerts[0]["id"] == alert_id

    ack = await client.post(
        f"/api/v1/notifications/sos/{alert_id}/ack",
        headers=_auth(caregiver_token),
    )
    assert ack.status_code == 200

    after_ack = await client.get(
        "/api/v1/notifications/sos/pending",
        headers=_auth(caregiver_token),
    )
    assert after_ack.json() == []
