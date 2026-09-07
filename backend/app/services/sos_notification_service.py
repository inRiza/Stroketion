import json
from datetime import UTC, datetime
from uuid import uuid4

from fastapi import HTTPException
from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.domain import CaregiverLink, LinkStatus, User
from app.schemas.notifications import SosAlertResponse

SOS_ALERT_TTL_SECONDS = 60 * 60 * 24


def _alert_key(alert_id: str) -> str:
    return f"sos:alert:{alert_id}"


def _caregiver_pending_key(caregiver_id: str) -> str:
    return f"sos:caregiver:{caregiver_id}:pending"


def _caregiver_ack_key(caregiver_id: str, alert_id: str) -> str:
    return f"sos:caregiver:{caregiver_id}:ack:{alert_id}"


async def create_sos_alert(
    db: AsyncSession,
    redis: Redis,
    patient: User,
    message: str,
) -> SosAlertResponse:
    alert_id = str(uuid4())
    created_at = datetime.now(UTC)
    payload = {
        "id": alert_id,
        "patient_id": patient.id,
        "patient_name": patient.full_name or patient.email,
        "message": message,
        "created_at": created_at.isoformat(),
    }

    await redis.set(_alert_key(alert_id), json.dumps(payload), ex=SOS_ALERT_TTL_SECONDS)

    result = await db.execute(
        select(CaregiverLink.caregiver_id).where(
            CaregiverLink.patient_id == patient.id,
            CaregiverLink.status == LinkStatus.APPROVED,
        )
    )
    caregiver_ids = result.scalars().all()
    for caregiver_id in caregiver_ids:
        await redis.sadd(_caregiver_pending_key(caregiver_id), alert_id)
        await redis.expire(_caregiver_pending_key(caregiver_id), SOS_ALERT_TTL_SECONDS)

    return SosAlertResponse(
        id=alert_id,
        patient_id=patient.id,
        patient_name=patient.full_name or patient.email,
        message=message,
        created_at=created_at,
    )


async def get_pending_sos_alerts(
    redis: Redis,
    caregiver: User,
) -> list[SosAlertResponse]:
    pending_key = _caregiver_pending_key(caregiver.id)
    alert_ids = await redis.smembers(pending_key)
    alerts: list[SosAlertResponse] = []

    for alert_id in sorted(alert_ids):
        acked = await redis.exists(_caregiver_ack_key(caregiver.id, alert_id))
        if acked:
            continue

        raw = await redis.get(_alert_key(alert_id))
        if not raw:
            await redis.srem(pending_key, alert_id)
            continue

        data = json.loads(raw)
        alerts.append(
            SosAlertResponse(
                id=data["id"],
                patient_id=data["patient_id"],
                patient_name=data["patient_name"],
                message=data["message"],
                created_at=datetime.fromisoformat(data["created_at"]),
            )
        )

    return alerts


async def acknowledge_sos_alert(
    redis: Redis,
    caregiver: User,
    alert_id: str,
) -> None:
    pending_key = _caregiver_pending_key(caregiver.id)
    is_pending = await redis.sismember(pending_key, alert_id)
    if not is_pending:
        raise HTTPException(status_code=404, detail="Alert SOS tidak ditemukan")

    await redis.set(
        _caregiver_ack_key(caregiver.id, alert_id),
        "1",
        ex=SOS_ALERT_TTL_SECONDS,
    )
    await redis.srem(pending_key, alert_id)
