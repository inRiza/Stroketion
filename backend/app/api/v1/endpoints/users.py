from fastapi import APIRouter

router = APIRouter()


@router.get("/me")
async def get_current_user():
    """Get current authenticated user profile."""
    return {"message": "not implemented"}


@router.get("/")
async def list_users():
    """List users (admin)."""
    return {"message": "not implemented"}


@router.get("/{user_id}")
async def get_user(user_id: str):
    """Get user by ID."""
    return {"message": "not implemented", "user_id": user_id}


@router.patch("/{user_id}")
async def update_user(user_id: str):
    """Update user profile."""
    return {"message": "not implemented", "user_id": user_id}
