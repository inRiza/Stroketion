from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import select

from app.api.deps import CurrentUser, DbSession
from app.models.domain import User
from app.schemas.links import (
    CaregiverLookupResponse,
    LinkedCaregiverResponse,
    LinkedPatientResponse,
    LinkResponse,
    PendingNotificationResponse,
    RequestCaregiverRequest,
    ScanPatientRequest,
    UserProfileResponse,
)
from app.services.link_service import (
    approve_link,
    caregiver_scan_patient,
    get_linked_caregivers,
    get_linked_patients,
    get_pending_notifications,
    lookup_caregiver_by_phone,
    patient_request_caregiver,
    reject_link,
)

router = APIRouter()


@router.get("/users/{user_id}", response_model=UserProfileResponse)
async def get_user_public(db: DbSession, user_id: str):
    user = await db.scalar(select(User).where(User.id == user_id))
    if not user:
        raise HTTPException(status_code=404, detail="User tidak ditemukan")
    return UserProfileResponse.model_validate(user)


@router.get("/me/profile", response_model=UserProfileResponse)
async def get_my_profile(user: CurrentUser):
    return UserProfileResponse.model_validate(user)


@router.get("/caregivers/lookup", response_model=CaregiverLookupResponse)
async def caregiver_lookup(db: DbSession, phone: str = Query(min_length=10)):
    return await lookup_caregiver_by_phone(db, phone)


@router.post("/scan-patient", response_model=LinkResponse)
async def scan_patient(db: DbSession, user: CurrentUser, data: ScanPatientRequest):
    return await caregiver_scan_patient(db, user, data.patient_id)


@router.post("/request-caregiver", response_model=LinkResponse)
async def request_caregiver(db: DbSession, user: CurrentUser, data: RequestCaregiverRequest):
    return await patient_request_caregiver(
        db, user, data.caregiver_id, data.phone, data.relationship
    )


@router.get("/my-patients", response_model=list[LinkedPatientResponse])
async def my_patients(db: DbSession, user: CurrentUser):
    return await get_linked_patients(db, user)


@router.get("/my-caregivers", response_model=list[LinkedCaregiverResponse])
async def my_caregivers(db: DbSession, user: CurrentUser):
    return await get_linked_caregivers(db, user)


@router.get("/pending", response_model=list[PendingNotificationResponse])
async def pending_requests(db: DbSession, user: CurrentUser):
    return await get_pending_notifications(db, user)


@router.post("/{link_id}/approve", response_model=LinkResponse)
async def approve_request(db: DbSession, user: CurrentUser, link_id: str):
    return await approve_link(db, user, link_id)


@router.post("/{link_id}/reject", response_model=LinkResponse)
async def reject_request(db: DbSession, user: CurrentUser, link_id: str):
    return await reject_link(db, user, link_id)
