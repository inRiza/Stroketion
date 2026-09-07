import base64
import uuid
from unittest.mock import patch

import numpy as np
import pytest
from starlette.testclient import TestClient

from app.main import app
from app.speech.pipeline import SpeechPipeline, SpeechStreamState


def test_pipeline_finalize_empty():
    pipeline = SpeechPipeline()
    state = SpeechStreamState("sess-1")
    summary = pipeline.finalize(state, 60)
    assert summary.confirmed_seconds == 0
    assert summary.speech_score == 100


def test_pipeline_process_speech_frames():
    pytest.importorskip("torch")
    pytest.importorskip("df")
    pytest.importorskip("parselmouth")

    pipeline = SpeechPipeline()
    state = SpeechStreamState("sess-2")
    t = np.linspace(0, 0.1, 1600)
    speech = (np.sin(2 * np.pi * 200 * t) * 12000).astype(np.int16)
    silence = np.zeros(1600, dtype=np.int16)

    for i in range(5):
        pipeline.process_frame(state, speech, i * 100.0)
    pipeline.process_frame(state, silence, 700.0)

    summary = pipeline.finalize(state, 10)
    assert summary.utterance_count >= 0


def test_websocket_rejects_without_ml_deps():
    suffix = uuid.uuid4().hex[:8]
    with patch("app.api.v1.endpoints.speech.ensure_speech_ml") as ensure:
        from app.speech.deps import SpeechMlUnavailableError

        ensure.side_effect = SpeechMlUnavailableError("dependencies", "torch missing")

        with TestClient(app) as sync_client:
            reg = sync_client.post(
                "/api/v1/auth/register",
                json={
                    "email": f"patient.{suffix}@test.dev",
                    "password": "secret123",
                    "full_name": "Patient",
                    "role": "patient",
                },
            )
            token = reg.json()["access_token"]

            with sync_client.websocket_connect(f"/api/v1/speech/stream?token={token}") as ws:
                ws.send_json({
                    "type": "start",
                    "monitoring_session_id": "ws-reject-001",
                    "sample_rate": 16000,
                })
                first = ws.receive_json()
                if first["type"] == "loading":
                    err = ws.receive_json()
                else:
                    err = first
                assert err["type"] == "error"
                assert err["code"] == "speech_ml_unavailable"


def test_websocket_speech_stream():
    pytest.importorskip("torch")
    pytest.importorskip("df")
    pytest.importorskip("parselmouth")

    suffix = uuid.uuid4().hex[:8]
    with TestClient(app) as sync_client:
        reg = sync_client.post(
            "/api/v1/auth/register",
            json={
                "email": f"patient.{suffix}@test.dev",
                "password": "secret123",
                "full_name": "Patient",
                "role": "patient",
            },
        )
        assert reg.status_code == 200
        token = reg.json()["access_token"]

        with sync_client.websocket_connect(f"/api/v1/speech/stream?token={token}") as ws:
            ws.send_json({
                "type": "start",
                "monitoring_session_id": "ws-test-001",
                "sample_rate": 16000,
            })
            first = ws.receive_json()
            if first["type"] == "loading":
                ready = ws.receive_json()
            else:
                ready = first
            assert ready["type"] == "ready"

            silence = np.zeros(3200, dtype=np.int16)

            ws.send_json({
                "type": "chunk",
                "pcm_base64": base64.b64encode(silence.tobytes()).decode(),
                "timestamp_ms": 100,
            })
            live = ws.receive_json()
            assert live["type"] == "live"

            ws.send_json({"type": "stop", "duration_seconds": 5})
            summary = ws.receive_json()
            assert summary["type"] == "summary"
            assert "speech_score" in summary
