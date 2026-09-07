from fastapi import APIRouter, HTTPException

from app.api.deps import CurrentUser, DbSession, RedisClient
from app.schemas.common import MessageResponse
from app.schemas.notifications import SosAlertCreate, SosAlertResponse
from app.services.sos_notification_service import (
    acknowledge_sos_alert,
    create_sos_alert,
    get_pending_sos_alerts,
)

router = APIRouter()


@router.post("/sos", response_model=SosAlertResponse)
async def send_sos_alert(
    db: DbSession,
    redis: RedisClient,
    user: CurrentUser,
    body: SosAlertCreate,
):
    if user.role != "patient":
        raise HTTPException(status_code=403, detail="Hanya pasien yang dapat memicu SOS")
    return await create_sos_alert(db, redis, user, body.message)


@router.get("/sos/pending", response_model=list[SosAlertResponse])
async def list_pending_sos_alerts(redis: RedisClient, user: CurrentUser):
    if user.role != "caregiver":
        return []
    return await get_pending_sos_alerts(redis, user)


@router.post("/sos/{alert_id}/ack", response_model=MessageResponse)
async def ack_sos_alert(redis: RedisClient, user: CurrentUser, alert_id: str):
    if user.role != "caregiver":
        return MessageResponse(message="OK")
    await acknowledge_sos_alert(redis, user, alert_id)
    return MessageResponse(message="Alert ditandai ditangani")
