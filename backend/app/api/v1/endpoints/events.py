from fastapi import APIRouter

router = APIRouter()


@router.get("/")
async def list_events():
    """List behaviour events with optional filters."""
    return {"message": "not implemented"}


@router.post("/")
async def create_event():
    """Store a behaviour event (motion/speech change)."""
    return {"message": "not implemented"}


@router.get("/{event_id}")
async def get_event(event_id: str):
    """Get event details."""
    return {"message": "not implemented", "event_id": event_id}


@router.get("/users/{user_id}/timeline")
async def get_user_timeline(user_id: str):
    """Get chronological event timeline for caregiver view."""
    return {"message": "not implemented", "user_id": user_id}
