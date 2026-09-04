from fastapi import APIRouter

router = APIRouter()


@router.get("/{user_id}")
async def get_baseline(user_id: str):
    """Get personal baseline for motion and speech behaviour."""
    return {"message": "not implemented", "user_id": user_id}


@router.post("/{user_id}")
async def create_baseline(user_id: str):
    """Create or initialize personal baseline."""
    return {"message": "not implemented", "user_id": user_id}


@router.patch("/{user_id}")
async def update_baseline(user_id: str):
    """Update personal baseline from collected data."""
    return {"message": "not implemented", "user_id": user_id}
