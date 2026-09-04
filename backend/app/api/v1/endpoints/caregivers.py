from fastapi import APIRouter

router = APIRouter()


@router.get("/")
async def list_caregivers():
    """List caregivers linked to a patient."""
    return {"message": "not implemented"}


@router.post("/")
async def create_caregiver_link():
    """Link a caregiver to a patient."""
    return {"message": "not implemented"}


@router.get("/{caregiver_id}")
async def get_caregiver(caregiver_id: str):
    """Get caregiver details."""
    return {"message": "not implemented", "caregiver_id": caregiver_id}


@router.delete("/{caregiver_id}")
async def remove_caregiver_link(caregiver_id: str):
    """Remove caregiver link from patient."""
    return {"message": "not implemented", "caregiver_id": caregiver_id}
