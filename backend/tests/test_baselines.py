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
            "full_name": role,
            "role": role,
        },
    )
    assert response.status_code == 200
    return response.json()


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_calibrate_speech_baseline(client: AsyncClient):
    patient = await _register(client, "patient")
    token = patient["access_token"]

    features = [
        {"jitter": 0.01, "shimmer": 0.02, "hnr": 15.0, "pitch_mean": 120.0, "pitch_std": 8.0, "duration_sec": 1.2},
        {"jitter": 0.012, "shimmer": 0.018, "hnr": 16.0, "pitch_mean": 118.0, "pitch_std": 7.5, "duration_sec": 1.0},
        {"jitter": 0.011, "shimmer": 0.021, "hnr": 14.5, "pitch_mean": 122.0, "pitch_std": 9.0, "duration_sec": 1.1},
    ]

    calibrate = await client.post(
        "/api/v1/baselines/me/speech/calibrate",
        json={"features": features},
        headers=_auth(token),
    )
    assert calibrate.status_code == 200
    body = calibrate.json()
    assert body["speech_data"]["sample_count"] == 3

    baseline = await client.get("/api/v1/baselines/me", headers=_auth(token))
    assert baseline.status_code == 200
    assert baseline.json()["speech_data"] is not None
