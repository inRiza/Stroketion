from datetime import datetime
from enum import Enum

from pydantic import BaseModel, EmailStr


class RiskLevel(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


class MessageResponse(BaseModel):
    message: str


class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str | None = None
    role: str = "patient"


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    role: str = "patient"
    phone: str | None = None
    gender: str | None = None
    date_of_birth: str | None = None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str
    role: str | None = None


class UserResponse(BaseModel):
    id: str
    email: EmailStr
    full_name: str | None
    role: str
    created_at: datetime

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class BaselineResponse(BaseModel):
    user_id: str
    motion_data: dict | None = None
    speech_data: dict | None = None
    updated_at: datetime | None = None


class BehaviourStatusResponse(BaseModel):
    user_id: str
    motion: str
    speech: str
    risk_level: RiskLevel
    last_known_normal: datetime | None = None
    first_detected_change: datetime | None = None
    latest_event: datetime | None = None


class EventCreate(BaseModel):
    event_type: str
    description: str | None = None
    occurred_at: datetime


class EventResponse(BaseModel):
    id: str
    user_id: str
    event_type: str
    description: str | None
    occurred_at: datetime

    model_config = {"from_attributes": True}


class RiskEventCreate(BaseModel):
    risk_level: RiskLevel
    motion_status: str | None = None
    speech_status: str | None = None
    last_known_normal_at: datetime | None = None
    first_detected_at: datetime | None = None
    latest_event_at: datetime | None = None


class RiskEventResponse(BaseModel):
    id: str
    user_id: str
    risk_level: RiskLevel
    motion_status: str | None
    speech_status: str | None
    last_known_normal_at: datetime | None
    first_detected_at: datetime | None
    latest_event_at: datetime | None
    created_at: datetime

    model_config = {"from_attributes": True}
