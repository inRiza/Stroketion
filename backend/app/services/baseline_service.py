import json
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.domain import PersonalBaseline, User
from app.schemas.common import BaselineResponse
from app.speech.baseline import baseline_from_samples, deviation_score
from app.speech.models import AcousticFeatures


async def get_baseline(db: AsyncSession, user: User) -> BaselineResponse:
    row = await db.scalar(select(PersonalBaseline).where(PersonalBaseline.user_id == user.id))
    motion_data = None
    speech_data = None
    updated_at = None
    if row:
        if row.motion_data:
            try:
                motion_data = json.loads(row.motion_data)
            except json.JSONDecodeError:
                motion_data = None
        if row.speech_data:
            try:
                speech_data = json.loads(row.speech_data)
            except json.JSONDecodeError:
                speech_data = None
        updated_at = row.updated_at
    return BaselineResponse(
        user_id=user.id,
        motion_data=motion_data,
        speech_data=speech_data,
        updated_at=updated_at,
    )


async def _get_or_create_baseline_row(db: AsyncSession, user_id: str) -> PersonalBaseline:
    row = await db.scalar(select(PersonalBaseline).where(PersonalBaseline.user_id == user_id))
    if row:
        return row
    row = PersonalBaseline(id=str(uuid4()), user_id=user_id)
    db.add(row)
    await db.flush()
    return row


async def calibrate_speech_baseline(
    db: AsyncSession,
    user: User,
    feature_samples: list[dict],
) -> BaselineResponse:
    if user.role != "patient":
        raise HTTPException(status_code=403, detail="Hanya pasien yang dapat kalibrasi baseline")

    samples = [AcousticFeatures.from_dict(f) for f in feature_samples]
    if len(samples) < 3:
        raise HTTPException(
            status_code=400,
            detail="Minimal 3 utterance analyzable diperlukan untuk kalibrasi",
        )

    baseline_dict = baseline_from_samples(samples)
    row = await _get_or_create_baseline_row(db, user.id)
    row.speech_data = json.dumps(baseline_dict)
    await db.commit()
    await db.refresh(row)

    return BaselineResponse(
        user_id=user.id,
        motion_data=json.loads(row.motion_data) if row.motion_data else None,
        speech_data=baseline_dict,
        updated_at=row.updated_at,
    )


async def update_speech_baseline(
    db: AsyncSession,
    user: User,
    speech_data: dict,
) -> BaselineResponse:
    if user.role != "patient":
        raise HTTPException(status_code=403, detail="Hanya pasien yang dapat update baseline")

    row = await _get_or_create_baseline_row(db, user.id)
    row.speech_data = json.dumps(speech_data)
    await db.commit()
    await db.refresh(row)

    return BaselineResponse(
        user_id=user.id,
        motion_data=json.loads(row.motion_data) if row.motion_data else None,
        speech_data=speech_data,
        updated_at=row.updated_at,
    )


def compute_deviation(features: AcousticFeatures, baseline: dict | None) -> float | None:
    return deviation_score(features, baseline)
