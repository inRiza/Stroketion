from fastapi import APIRouter

from app.api.deps import CurrentUser, DbSession
from app.schemas.common import BaselineResponse
from app.schemas.speech import SpeechBaselineUpdate, SpeechCalibrateRequest
from app.services import baseline_service

router = APIRouter()


@router.get("/me", response_model=BaselineResponse)
async def get_my_baseline(db: DbSession, user: CurrentUser):
    return await baseline_service.get_baseline(db, user)


@router.post("/me/speech/calibrate", response_model=BaselineResponse)
async def calibrate_speech(db: DbSession, user: CurrentUser, body: SpeechCalibrateRequest):
    return await baseline_service.calibrate_speech_baseline(db, user, body.features)


@router.patch("/me/speech", response_model=BaselineResponse)
async def update_speech_baseline(db: DbSession, user: CurrentUser, body: SpeechBaselineUpdate):
    return await baseline_service.update_speech_baseline(db, user, body.speech_data)
