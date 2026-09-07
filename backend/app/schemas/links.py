from datetime import datetime

from pydantic import BaseModel


class UserProfileResponse(BaseModel):
    id: str
    email: str
    full_name: str | None
    phone: str | None
    role: str

    model_config = {"from_attributes": True}


class CaregiverLookupResponse(BaseModel):
    id: str
    full_name: str | None
    phone: str | None
    email: str

    model_config = {"from_attributes": True}


class ScanPatientRequest(BaseModel):
    patient_id: str


class RequestCaregiverRequest(BaseModel):
    caregiver_id: str | None = None
    phone: str | None = None
    relationship: str | None = None


class LinkResponse(BaseModel):
    id: str
    patient_id: str
    caregiver_id: str
    status: str
    relationship: str | None
    initiated_by: str
    created_at: datetime

    model_config = {"from_attributes": True}


class LinkedPatientResponse(BaseModel):
    id: str
    full_name: str | None
    email: str
    phone: str | None
    link_id: str
    relationship: str | None

    model_config = {"from_attributes": True}


class LinkedCaregiverResponse(BaseModel):
    id: str
    full_name: str | None
    email: str
    phone: str | None
    link_id: str
    status: str
    relationship: str | None
    initiated_by: str | None = None

    model_config = {"from_attributes": True}


class PendingNotificationResponse(BaseModel):
    link_id: str
    patient_id: str
    patient_name: str | None
    patient_phone: str | None
    relationship: str | None
    created_at: datetime
