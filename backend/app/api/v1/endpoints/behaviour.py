from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, DbSession
from app.schemas.common import BehaviourStatusResponse
from app.schemas.sessions import MotionScoreSubmit, SessionSummaryResponse, SpeechScoreSubmit
from app.services import session_service

router = APIRouter()


@router.get("/{user_id}/history", response_model=list[SessionSummaryResponse])
async def get_behaviour_history(
    db: DbSession,
    user: CurrentUser,
    user_id: str,
    limit: int = Query(default=20, ge=1, le=100),
):
    """Riwayat sesi monitoring pasien (balance + speech)."""
    return await session_service.get_behaviour_history(db, user, user_id, limit=limit)


@router.post("/{user_id}/motion")
async def submit_motion_score(
    db: DbSession,
    user: CurrentUser,
    user_id: str,
    body: MotionScoreSubmit,
):
    """Submit skor motion/balance dari perangkat."""
    return await session_service.submit_motion_score(db, user, user_id, body)


@router.post("/{user_id}/speech")
async def submit_speech_score(
    db: DbSession,
    user: CurrentUser,
    user_id: str,
    body: SpeechScoreSubmit,
):
    """Submit skor speech dari perangkat (detik suara, level dB, skor)."""
    return await session_service.submit_speech_score(db, user, user_id, body)


@router.get("/{user_id}/status", response_model=BehaviourStatusResponse)
async def get_user_status(db: DbSession, user: CurrentUser, user_id: str):
    """Status motion, speech, dan risiko terbaru untuk dashboard caregiver."""
    return await session_service.get_behaviour_status(db, user, user_id)
