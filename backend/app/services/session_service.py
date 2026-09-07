import json
from datetime import UTC, datetime

from fastapi import HTTPException
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.domain import BehaviourEvent, CaregiverLink, LinkStatus, MonitoringSession, RiskEvent, RiskLevel, User
from app.schemas.sessions import (
    MotionScoreSubmit,
    SessionCreate,
    SessionResponse,
    SessionSummaryResponse,
    SpeechScoreSubmit,
    parse_risk_level,
)
from app.schemas.common import BehaviourStatusResponse, RiskLevel as RiskLevelSchema


async def assert_patient_access(db: AsyncSession, actor: User, patient_id: str) -> User:
    if actor.id == patient_id:
        patient = await db.scalar(select(User).where(User.id == patient_id))
        if not patient:
            raise HTTPException(status_code=404, detail="Pasien tidak ditemukan")
        return patient

    if actor.role != "caregiver":
        raise HTTPException(status_code=403, detail="Akses ditolak")

    link = await db.scalar(
        select(CaregiverLink).where(
            CaregiverLink.patient_id == patient_id,
            CaregiverLink.caregiver_id == actor.id,
            CaregiverLink.status == LinkStatus.APPROVED,
        )
    )
    if not link:
        raise HTTPException(status_code=403, detail="Pasien tidak terhubung dengan caregiver ini")

    patient = await db.scalar(select(User).where(User.id == patient_id))
    if not patient:
        raise HTTPException(status_code=404, detail="Pasien tidak ditemukan")
    return patient


def _to_response(session: MonitoringSession) -> SessionResponse:
    timeline = json.loads(session.timeline_json) if session.timeline_json else []
    route = json.loads(session.route_json) if session.route_json else []
    return SessionResponse(
        id=session.id,
        user_id=session.user_id,
        started_at=session.started_at,
        ended_at=session.ended_at,
        location=session.location,
        activity=session.activity,
        duration_seconds=session.duration_seconds,
        avg_svm=session.avg_svm,
        max_svm=session.max_svm,
        avg_avm_deg=session.avg_avm_deg,
        max_avm_deg=session.max_avm_deg,
        max_tilt_degrees=session.max_tilt_degrees,
        max_heading_deviation_deg=session.max_heading_deviation_deg,
        fall_events=session.fall_events,
        impact_events=session.impact_events,
        speech_detected_seconds=session.speech_detected_seconds,
        avg_speech_level=session.avg_speech_level,
        balance_score=session.balance_score,
        speech_score=session.speech_score,
        overall_score=session.overall_score,
        risk_level=RiskLevelSchema(session.risk_level.value),
        timeline=timeline,
        route=route,
        distance_meters=session.distance_meters,
        gps_active=session.gps_active,
        created_at=session.created_at,
    )


def _motion_label(balance_score: int, fall_events: int) -> str:
    if fall_events > 0 or balance_score < 45:
        return "Perlu perhatian"
    if balance_score < 70:
        return "Cukup dinamis"
    return "Stabil"


def _speech_label(speech_score: int, speech_seconds: int) -> str:
    if speech_seconds == 0:
        return "Diam"
    if speech_score < 70:
        return "Jarang"
    if speech_score < 85:
        return "Sedang"
    return "Aktif"


async def create_session(
    db: AsyncSession,
    patient: User,
    data: SessionCreate,
) -> SessionResponse:
    if patient.role != "patient":
        raise HTTPException(status_code=403, detail="Hanya pasien yang dapat mengunggah sesi")

    existing = await db.scalar(
        select(MonitoringSession).where(
            MonitoringSession.id == data.id,
            MonitoringSession.user_id == patient.id,
        )
    )
    if existing:
        return _to_response(existing)

    risk = parse_risk_level(data.risk_level)
    speech_seconds = data.speech_detected_seconds
    speech_score = data.speech_score
    if data.speech_analysis:
        confirmed = int(data.speech_analysis.get("confirmed_seconds", 0))
        vad = int(data.speech_analysis.get("vad_active_seconds", 0))
        speech_seconds = max(speech_seconds, confirmed, vad)
        speech_score = int(data.speech_analysis.get("speech_score", speech_score))

    session = MonitoringSession(
        id=data.id,
        user_id=patient.id,
        started_at=data.started_at,
        ended_at=data.ended_at,
        location=data.location,
        activity=data.activity,
        duration_seconds=data.duration_seconds,
        avg_svm=data.avg_svm,
        max_svm=data.max_svm,
        avg_avm_deg=data.avg_avm_deg,
        max_avm_deg=data.max_avm_deg,
        max_tilt_degrees=data.max_tilt_degrees,
        max_heading_deviation_deg=data.max_heading_deviation_deg,
        fall_events=data.fall_events,
        impact_events=data.impact_events,
        speech_detected_seconds=speech_seconds,
        avg_speech_level=data.avg_speech_level,
        balance_score=data.balance_score,
        speech_score=speech_score,
        overall_score=data.overall_score,
        risk_level=risk,
        timeline_json=json.dumps(data.timeline),
        route_json=json.dumps(data.route),
        distance_meters=data.distance_meters,
        gps_active=data.gps_active,
    )
    db.add(session)

    if risk in (RiskLevel.MEDIUM, RiskLevel.HIGH):
        db.add(
            RiskEvent(
                user_id=patient.id,
                risk_level=risk,
                motion_status=_motion_label(data.balance_score, data.fall_events),
                speech_status=_speech_label(data.speech_score, data.speech_detected_seconds),
                latest_event_at=data.ended_at,
                first_detected_at=data.ended_at,
            )
        )

    await db.commit()
    await db.refresh(session)
    return _to_response(session)


async def list_my_sessions(
    db: AsyncSession,
    patient: User,
    limit: int = 50,
) -> list[SessionSummaryResponse]:
    if patient.role != "patient":
        raise HTTPException(status_code=403, detail="Hanya pasien")

    result = await db.execute(
        select(MonitoringSession)
        .where(MonitoringSession.user_id == patient.id)
        .order_by(desc(MonitoringSession.started_at))
        .limit(limit)
    )
    sessions = result.scalars().all()
    return [
        SessionSummaryResponse(
            id=s.id,
            started_at=s.started_at,
            ended_at=s.ended_at,
            location=s.location,
            activity=s.activity,
            duration_seconds=s.duration_seconds,
            balance_score=s.balance_score,
            speech_score=s.speech_score,
            overall_score=s.overall_score,
            risk_level=RiskLevelSchema(s.risk_level.value),
        )
        for s in sessions
    ]


async def list_patient_sessions(
    db: AsyncSession,
    actor: User,
    patient_id: str,
    limit: int = 50,
) -> list[SessionSummaryResponse]:
    await assert_patient_access(db, actor, patient_id)
    result = await db.execute(
        select(MonitoringSession)
        .where(MonitoringSession.user_id == patient_id)
        .order_by(desc(MonitoringSession.started_at))
        .limit(limit)
    )
    sessions = result.scalars().all()
    return [
        SessionSummaryResponse(
            id=s.id,
            started_at=s.started_at,
            ended_at=s.ended_at,
            location=s.location,
            activity=s.activity,
            duration_seconds=s.duration_seconds,
            balance_score=s.balance_score,
            speech_score=s.speech_score,
            overall_score=s.overall_score,
            risk_level=RiskLevelSchema(s.risk_level.value),
        )
        for s in sessions
    ]


async def get_session(
    db: AsyncSession,
    actor: User,
    session_id: str,
) -> SessionResponse:
    session = await db.scalar(select(MonitoringSession).where(MonitoringSession.id == session_id))
    if not session:
        raise HTTPException(status_code=404, detail="Sesi tidak ditemukan")
    await assert_patient_access(db, actor, session.user_id)
    return _to_response(session)


async def get_behaviour_status(
    db: AsyncSession,
    actor: User,
    patient_id: str,
) -> BehaviourStatusResponse:
    await assert_patient_access(db, actor, patient_id)
    session = await db.scalar(
        select(MonitoringSession)
        .where(MonitoringSession.user_id == patient_id)
        .order_by(desc(MonitoringSession.started_at))
        .limit(1)
    )
    if not session:
        return BehaviourStatusResponse(
            user_id=patient_id,
            motion="Belum ada data",
            speech="Belum ada data",
            risk_level=RiskLevelSchema.LOW,
        )

    return BehaviourStatusResponse(
        user_id=patient_id,
        motion=_motion_label(session.balance_score, session.fall_events),
        speech=_speech_label(session.speech_score, session.speech_detected_seconds),
        risk_level=RiskLevelSchema(session.risk_level.value),
        latest_event=session.ended_at,
        last_known_normal=session.started_at if session.risk_level == RiskLevel.LOW else None,
        first_detected_change=session.ended_at if session.risk_level != RiskLevel.LOW else None,
    )


async def get_behaviour_history(
    db: AsyncSession,
    actor: User,
    patient_id: str,
    limit: int = 20,
) -> list[SessionSummaryResponse]:
    return await list_patient_sessions(db, actor, patient_id, limit=limit)


async def submit_motion_score(
    db: AsyncSession,
    actor: User,
    patient_id: str,
    data: MotionScoreSubmit,
) -> dict:
    await assert_patient_access(db, actor, patient_id)
    if actor.id != patient_id:
        raise HTTPException(status_code=403, detail="Hanya pasien yang dapat submit skor motion")

    occurred_at = data.occurred_at or datetime.now(UTC)
    db.add(
        BehaviourEvent(
            user_id=patient_id,
            event_type="motion_score",
            description=json.dumps(data.model_dump()),
            occurred_at=occurred_at,
        )
    )
    await db.commit()
    return {"message": "Skor motion tersimpan", "balance_score": data.balance_score}


async def submit_speech_score(
    db: AsyncSession,
    actor: User,
    patient_id: str,
    data: SpeechScoreSubmit,
) -> dict:
    await assert_patient_access(db, actor, patient_id)
    if actor.id != patient_id:
        raise HTTPException(status_code=403, detail="Hanya pasien yang dapat submit skor speech")

    occurred_at = data.occurred_at or datetime.now(UTC)
    db.add(
        BehaviourEvent(
            user_id=patient_id,
            event_type="speech_score",
            description=json.dumps(data.model_dump()),
            occurred_at=occurred_at,
        )
    )
    await db.commit()
    return {
        "message": "Skor speech tersimpan",
        "speech_score": data.speech_score,
        "speech_detected_seconds": data.speech_detected_seconds,
    }
