import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.fixture
async def client() -> AsyncClient:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _register(client: AsyncClient, role: str, full_name: str) -> dict:
    suffix = uuid.uuid4().hex[:8]
    email = f"{role}.{suffix}@test.dev"
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "secret123",
            "full_name": full_name,
            "role": role,
        },
    )
    assert response.status_code == 200
    return response.json()


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_upload_session_with_speech(client: AsyncClient):
    patient = await _register(client, "patient", "Patient Speech")
    token = patient["access_token"]
    user_id = patient["user"]["id"]

    payload = {
        "id": "session-test-001",
        "started_at": "2026-09-05T10:00:00+00:00",
        "ended_at": "2026-09-05T10:05:00+00:00",
        "location": "home",
        "activity": "daily",
        "duration_seconds": 300,
        "avg_svm": 10.2,
        "max_svm": 18.0,
        "avg_avm_deg": 12.0,
        "max_avm_deg": 45.0,
        "max_tilt_degrees": 15.0,
        "max_heading_deviation_deg": 8.0,
        "fall_events": 0,
        "impact_events": 0,
        "speech_detected_seconds": 120,
        "avg_speech_level": -28.5,
        "balance_score": 92,
        "speech_score": 88,
        "overall_score": 91,
        "risk_level": "low",
        "timeline": [{"offset_sec": 0, "svm": 9.8, "avm_deg": 0, "impact": False, "fall": False}],
        "route": [],
        "distance_meters": 0,
        "gps_active": False,
        "speech_analysis": {
            "confirmed_seconds": 120,
            "vad_active_seconds": 130,
            "speech_score": 88,
            "dysarthria_risk": "none",
            "aphasia_risk": "none",
            "clinical_segments": [
                {
                    "offset_sec": 45,
                    "duration_ms": 5000,
                    "started_at_ms": 45000,
                    "flags": ["indikasi_disfluensi"],
                    "pcm_base64": "AAAA",
                }
            ],
        },
    }

    upload = await client.post("/api/v1/sessions", json=payload, headers=_auth(token))
    assert upload.status_code == 200
    body = upload.json()
    assert body["speech_score"] == 88
    assert body["speech_detected_seconds"] == 130
    assert body["user_id"] == user_id
    assert body["speech_analysis"] is not None
    assert len(body["speech_analysis"]["clinical_segments"]) == 1

    detail = await client.get("/api/v1/sessions/session-test-001", headers=_auth(token))
    assert detail.status_code == 200
    detail_body = detail.json()
    assert detail_body["speech_analysis"]["clinical_segments"][0]["offset_sec"] == 45

    mine = await client.get("/api/v1/sessions/me", headers=_auth(token))
    assert mine.status_code == 200
    assert len(mine.json()) == 1

    speech = await client.post(
        f"/api/v1/behaviour/{user_id}/speech",
        json={
            "speech_score": 85,
            "speech_detected_seconds": 90,
            "avg_speech_level": -30,
        },
        headers=_auth(token),
    )
    assert speech.status_code == 200
    assert speech.json()["speech_score"] == 85

    status = await client.get(f"/api/v1/behaviour/{user_id}/status", headers=_auth(token))
    assert status.status_code == 200
    assert status.json()["speech"] == "Aktif"


@pytest.mark.asyncio
async def test_caregiver_can_view_patient_sessions(client: AsyncClient):
    patient = await _register(client, "patient", "Patient View")
    caregiver = await _register(client, "caregiver", "Caregiver View")

    patient_token = patient["access_token"]
    caregiver_token = caregiver["access_token"]
    patient_id = patient["user"]["id"]
    caregiver_id = caregiver["user"]["id"]

    await client.post(
        "/api/v1/links/request-caregiver",
        json={"caregiver_id": caregiver_id, "relationship": "Keluarga"},
        headers=_auth(patient_token),
    )
    pending = await client.get("/api/v1/links/pending", headers=_auth(caregiver_token))
    link_id = pending.json()[0]["link_id"]
    await client.post(f"/api/v1/links/{link_id}/approve", headers=_auth(caregiver_token))

    await client.post(
        "/api/v1/sessions",
        json={
            "id": "session-view-001",
            "started_at": "2026-09-05T11:00:00+00:00",
            "ended_at": "2026-09-05T11:03:00+00:00",
            "location": "outdoor",
            "activity": "exercise",
            "duration_seconds": 180,
            "avg_svm": 11.0,
            "max_svm": 22.0,
            "avg_avm_deg": 20.0,
            "max_avm_deg": 80.0,
            "max_tilt_degrees": 25.0,
            "max_heading_deviation_deg": 12.0,
            "fall_events": 0,
            "impact_events": 1,
            "speech_detected_seconds": 30,
            "avg_speech_level": -32.0,
            "balance_score": 75,
            "speech_score": 95,
            "overall_score": 82,
            "risk_level": "medium",
            "timeline": [],
            "route": [{"lat": -6.2, "lng": 106.8, "offset_sec": 0}],
            "distance_meters": 450,
            "gps_active": True,
        },
        headers=_auth(patient_token),
    )

    sessions = await client.get(
        f"/api/v1/sessions/patients/{patient_id}",
        headers=_auth(caregiver_token),
    )
    assert sessions.status_code == 200
    assert sessions.json()[0]["speech_score"] == 95

    status = await client.get(
        f"/api/v1/behaviour/{patient_id}/status",
        headers=_auth(caregiver_token),
    )
    assert status.status_code == 200
    assert status.json()["risk_level"] == "MEDIUM"

    detail = await client.get(
        "/api/v1/sessions/session-view-001",
        headers=_auth(caregiver_token),
    )
    assert detail.status_code == 200
    body = detail.json()
    assert body["id"] == "session-view-001"
    assert body["risk_level"] == "MEDIUM"
    assert body["balance_score"] == 75
