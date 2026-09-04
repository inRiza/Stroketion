from fastapi import APIRouter

router = APIRouter()


@router.post("/push")
async def sync_from_device():
    """Sync behaviour data from mobile device to backend."""
    return {"message": "not implemented"}


@router.get("/pull")
async def pull_updates():
    """Pull latest updates for mobile device."""
    return {"message": "not implemented"}


@router.post("/batch")
async def batch_sync():
    """Batch sync multiple records."""
    return {"message": "not implemented"}
