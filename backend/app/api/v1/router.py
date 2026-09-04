from fastapi import APIRouter

from app.api.v1.endpoints import (
    auth,
    baselines,
    behaviour,
    caregivers,
    events,
    notifications,
    risk_events,
    sync,
    users,
)

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(caregivers.router, prefix="/caregivers", tags=["caregivers"])
api_router.include_router(baselines.router, prefix="/baselines", tags=["baselines"])
api_router.include_router(behaviour.router, prefix="/behaviour", tags=["behaviour"])
api_router.include_router(events.router, prefix="/events", tags=["events"])
api_router.include_router(risk_events.router, prefix="/risk-events", tags=["risk-events"])
api_router.include_router(sync.router, prefix="/sync", tags=["sync"])
api_router.include_router(notifications.router, prefix="/notifications", tags=["notifications"])
