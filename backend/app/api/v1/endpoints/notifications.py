from fastapi import APIRouter

router = APIRouter()


@router.post("/register-device")
async def register_device():
    """Register FCM device token for push notifications."""
    return {"message": "not implemented"}


@router.post("/send")
async def send_notification():
    """Send notification to caregiver (internal/admin)."""
    return {"message": "not implemented"}


@router.get("/")
async def list_notifications():
    """List notification history for a user."""
    return {"message": "not implemented"}
