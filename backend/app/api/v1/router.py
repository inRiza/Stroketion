from fastapi import APIRouter

from app.api.v1.endpoints import (
    auth,
    baselines,
    behaviour,
    caregivers,
    events,
    links,
    notifications,
    risk_events,
    sessions,
    speech,
    sync,
    users,
)

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(links.router, prefix="/links", tags=["links"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(caregivers.router, prefix="/caregivers", tags=["caregivers"])
api_router.include_router(baselines.router, prefix="/baselines", tags=["baselines"])
api_router.include_router(behaviour.router, prefix="/behaviour", tags=["behaviour"])
api_router.include_router(sessions.router, prefix="/sessions", tags=["sessions"])
api_router.include_router(speech.router, prefix="/speech", tags=["speech"])
api_router.include_router(events.router, prefix="/events", tags=["events"])
api_router.include_router(risk_events.router, prefix="/risk-events", tags=["risk-events"])
api_router.include_router(sync.router, prefix="/sync", tags=["sync"])
api_router.include_router(notifications.router, prefix="/notifications", tags=["notifications"])
