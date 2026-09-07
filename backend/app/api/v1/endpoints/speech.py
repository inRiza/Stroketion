import asyncio
import json
import logging
from typing import Any

from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect
from jose import JWTError, jwt
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import CurrentUser, DbSession, RedisClient
from app.core.config import settings
from app.core.database import async_session
from app.core.security import ALGORITHM
from app.schemas.speech import SpeechUtteranceResponse
from app.services.speech_service import (
    clear_stream_state,
    create_pipeline,
    decode_pcm_chunk,
    get_session_utterances,
    get_speech_baseline,
    persist_utterances,
    save_stream_state,
)
from app.speech.deps import SpeechMlUnavailableError, ensure_speech_ml
from app.speech.pipeline import SpeechStreamState

router = APIRouter()
logger = logging.getLogger(__name__)


async def _user_from_token(token: str, db: AsyncSession):
    from sqlalchemy import select

    from app.models.domain import User

    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        if not user_id:
            return None
    except JWTError:
        return None
    return await db.scalar(select(User).where(User.id == user_id))


@router.websocket("/stream")
async def speech_stream(websocket: WebSocket):
    await websocket.accept()
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=4401)
        return

    async with async_session() as db:
        user = await _user_from_token(token, db)
        if not user or user.role != "patient":
            await websocket.close(code=4403)
            return

        baseline = await get_speech_baseline(db, user.id)
        pipeline = create_pipeline(baseline)
        state: SpeechStreamState | None = None
        duration_seconds = 0
        redis = None

        try:
            from app.core.redis import redis_client

            redis = redis_client
        except Exception:
            redis = None

        try:
            while True:
                raw = await websocket.receive_text()
                msg: dict[str, Any] = json.loads(raw)
                msg_type = msg.get("type")

                if msg_type == "start":
                    from app.speech.deps import _warmed

                    if not _warmed:
                        await websocket.send_json({
                            "type": "loading",
                            "message": "Memuat model speech...",
                        })
                    try:
                        await asyncio.to_thread(ensure_speech_ml, warm=True)
                    except SpeechMlUnavailableError as exc:
                        await websocket.send_json({
                            "type": "error",
                            "code": "speech_ml_unavailable",
                            "message": str(exc),
                        })
                        await websocket.close(code=4503)
                        return

                    session_id = msg.get("monitoring_session_id", "")
                    sample_rate = int(msg.get("sample_rate", 16000))
                    state = SpeechStreamState(session_id, sample_rate)
                    duration_seconds = 0
                    if redis:
                        try:
                            await save_stream_state(redis, user.id, state)
                        except Exception:
                            pass
                    await websocket.send_json({"type": "ready", "session_id": session_id})

                elif msg_type == "chunk" and state is not None:
                    pcm = decode_pcm_chunk(msg["pcm_base64"])
                    timestamp_ms = float(msg.get("timestamp_ms", 0))
                    try:
                        live = await asyncio.to_thread(
                            pipeline.process_frame,
                            state,
                            pcm,
                            timestamp_ms,
                        )
                    except SpeechMlUnavailableError as exc:
                        await websocket.send_json({
                            "type": "error",
                            "code": "speech_ml_unavailable",
                            "message": str(exc),
                        })
                        continue
                    except Exception as exc:
                        logger.exception("speech chunk processing failed")
                        await websocket.send_json({
                            "type": "error",
                            "code": "speech_processing_error",
                            "message": str(exc),
                        })
                        continue
                    payload: dict[str, Any] = {
                        "type": "live",
                        "speech_active": live.speech_active,
                        "energy_dbfs": round(live.energy_dbfs, 1),
                        "vad_prob": round(live.vad_prob, 2),
                    }
                    if live.utterance:
                        payload["utterance"] = live.utterance.to_dict()
                    if live.clinical_alert:
                        payload["clinical_alert"] = live.clinical_alert
                    await websocket.send_json(payload)

                elif msg_type == "tick":
                    duration_seconds = int(msg.get("duration_seconds", duration_seconds))

                elif msg_type == "stop" and state is not None:
                    summary = await asyncio.to_thread(
                        pipeline.finalize,
                        state,
                        max(duration_seconds, 1),
                    )
                    await persist_utterances(db, user.id, state.monitoring_session_id, summary)
                    if redis:
                        try:
                            await clear_stream_state(redis, user.id, state.monitoring_session_id)
                        except Exception:
                            pass
                    await websocket.send_json({"type": "summary", **summary.to_dict()})
                    break

        except WebSocketDisconnect:
            if state is not None and redis:
                try:
                    await clear_stream_state(redis, user.id, state.monitoring_session_id)
                except Exception:
                    pass
        except SpeechMlUnavailableError as exc:
            await websocket.send_json({
                "type": "error",
                "code": "speech_ml_unavailable",
                "message": str(exc),
            })
        except json.JSONDecodeError:
            await websocket.send_json({"type": "error", "message": "Invalid JSON"})
        except Exception as exc:
            await websocket.send_json({"type": "error", "message": str(exc)})


@router.get("/sessions/{session_id}/utterances", response_model=list[SpeechUtteranceResponse])
async def list_utterances(db: DbSession, user: CurrentUser, session_id: str):
    rows = await get_session_utterances(db, session_id)
    if not rows:
        return []
    if rows[0].user_id != user.id and user.role != "caregiver":
        raise HTTPException(status_code=403, detail="Akses ditolak")

    result = []
    for row in rows:
        features = None
        if row.acoustic_features_json:
            try:
                features = json.loads(row.acoustic_features_json)
            except json.JSONDecodeError:
                features = None
        result.append(
            SpeechUtteranceResponse(
                id=row.id,
                monitoring_session_id=row.monitoring_session_id,
                user_id=row.user_id,
                started_at_ms=row.started_at_ms,
                duration_ms=row.duration_ms,
                status=row.status,
                snr_db=row.snr_db,
                vad_prob_avg=row.vad_prob_avg,
                acoustic_features=features,
                deviation_score=row.deviation_score,
                created_at=row.created_at,
            )
        )
    return result
