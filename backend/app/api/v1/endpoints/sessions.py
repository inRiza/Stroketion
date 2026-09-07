from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, DbSession
from app.schemas.common import BehaviourStatusResponse
from app.schemas.sessions import (
    MotionScoreSubmit,
    SessionCreate,
    SessionResponse,
    SessionSummaryResponse,
    SpeechScoreSubmit,
)
from app.services.session_service import (
    create_session,
    get_behaviour_history,
    get_behaviour_status,
    get_session,
    list_my_sessions,
    list_patient_sessions,
    submit_motion_score,
    submit_speech_score,
)

router = APIRouter()


@router.post("", response_model=SessionResponse)
async def upload_session(db: DbSession, user: CurrentUser, body: SessionCreate):
    """Upload sesi monitoring lengkap (balance + speech + timeline)."""
    return await create_session(db, user, body)


@router.get("/me", response_model=list[SessionSummaryResponse])
async def my_sessions(
    db: DbSession,
    user: CurrentUser,
    limit: int = Query(default=50, ge=1, le=200),
):
    return await list_my_sessions(db, user, limit=limit)


@router.get("/patients/{patient_id}", response_model=list[SessionSummaryResponse])
async def patient_sessions(
    db: DbSession,
    user: CurrentUser,
    patient_id: str,
    limit: int = Query(default=50, ge=1, le=200),
):
    return await list_patient_sessions(db, user, patient_id, limit=limit)


@router.get("/{session_id}", response_model=SessionResponse)
async def session_detail(db: DbSession, user: CurrentUser, session_id: str):
    return await get_session(db, user, session_id)
