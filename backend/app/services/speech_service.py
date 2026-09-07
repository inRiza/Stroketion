import base64
import json
from uuid import uuid4

import numpy as np
from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.domain import PersonalBaseline, SpeechUtterance, User
from app.speech.baseline import features_to_json
from app.speech.models import SegmentQuality, SpeechSummary
from app.speech.pipeline import SpeechPipeline, SpeechStreamState


def _stream_key(user_id: str, session_id: str) -> str:
    return f"speech:stream:{user_id}:{session_id}"


async def get_speech_baseline(db: AsyncSession, user_id: str) -> dict | None:
    row = await db.scalar(select(PersonalBaseline).where(PersonalBaseline.user_id == user_id))
    if not row or not row.speech_data:
        return None
    try:
        return json.loads(row.speech_data)
    except json.JSONDecodeError:
        return None


async def save_stream_state(redis: Redis, user_id: str, state: SpeechStreamState) -> None:
    key = _stream_key(user_id, state.monitoring_session_id)
    payload = {
        "monitoring_session_id": state.monitoring_session_id,
        "sample_rate": state.sample_rate,
        "utterance_count": len(state.utterances),
    }
    await redis.set(key, json.dumps(payload), ex=3600)


async def clear_stream_state(redis: Redis, user_id: str, session_id: str) -> None:
    await redis.delete(_stream_key(user_id, session_id))


def decode_pcm_chunk(pcm_base64: str) -> np.ndarray:
    raw = base64.b64decode(pcm_base64)
    return np.frombuffer(raw, dtype=np.int16)


def create_pipeline(baseline: dict | None) -> SpeechPipeline:
    return SpeechPipeline(baseline=baseline)


async def persist_utterances(
    db: AsyncSession,
    user_id: str,
    monitoring_session_id: str,
    summary: SpeechSummary,
) -> None:
    for u in summary.utterances:
        db.add(
            SpeechUtterance(
                id=str(uuid4()),
                monitoring_session_id=monitoring_session_id,
                user_id=user_id,
                started_at_ms=u.started_at_ms,
                duration_ms=u.duration_ms,
                status=u.status.value,
                snr_db=u.snr_db,
                vad_prob_avg=u.vad_prob_avg,
                acoustic_features_json=features_to_json(u.features) if u.features else None,
                deviation_score=u.deviation_score,
            )
        )
    await db.commit()


async def get_session_utterances(
    db: AsyncSession,
    monitoring_session_id: str,
) -> list[SpeechUtterance]:
    result = await db.execute(
        select(SpeechUtterance)
        .where(SpeechUtterance.monitoring_session_id == monitoring_session_id)
        .order_by(SpeechUtterance.started_at_ms)
    )
    return list(result.scalars().all())


async def load_user_from_token(db: AsyncSession, user_id: str) -> User | None:
    return await db.scalar(select(User).where(User.id == user_id))
