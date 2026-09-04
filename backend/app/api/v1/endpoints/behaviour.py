from fastapi import APIRouter

router = APIRouter()


@router.get("/{user_id}/history")
async def get_behaviour_history(user_id: str):
    """Get behaviour history timeline for a user."""
    return {"message": "not implemented", "user_id": user_id}


@router.post("/{user_id}/motion")
async def submit_motion_score(user_id: str):
    """Submit motion behaviour score from device."""
    return {"message": "not implemented", "user_id": user_id}


@router.post("/{user_id}/speech")
async def submit_speech_score(user_id: str):
    """Submit speech behaviour score from device."""
    return {"message": "not implemented", "user_id": user_id}


@router.get("/{user_id}/status")
async def get_user_status(user_id: str):
    """Get current motion, speech, and risk status for caregiver dashboard."""
    return {"message": "not implemented", "user_id": user_id}
