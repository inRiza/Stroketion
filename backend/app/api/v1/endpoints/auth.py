from fastapi import APIRouter

router = APIRouter()


@router.post("/register")
async def register():
    """Register a new user account."""
    return {"message": "not implemented"}


@router.post("/login")
async def login():
    """Authenticate user and return access token."""
    return {"message": "not implemented"}


@router.post("/refresh")
async def refresh_token():
    """Refresh access token."""
    return {"message": "not implemented"}


@router.post("/logout")
async def logout():
    """Invalidate current session."""
    return {"message": "not implemented"}
