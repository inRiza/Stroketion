from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field, field_validator

from app.models.domain import RiskLevel
from app.schemas.common import RiskLevel as RiskLevelSchema


def parse_risk_level(value: str) -> RiskLevel:
    normalized = value.strip().lower()
    mapping = {
        "low": RiskLevel.LOW,
        "medium": RiskLevel.MEDIUM,
        "high": RiskLevel.HIGH,
    }
    if normalized not in mapping:
        raise ValueError(f"Invalid risk level: {value}")
    return mapping[normalized]


class SessionCreate(BaseModel):
    id: str = Field(min_length=1, max_length=64)
    started_at: datetime
    ended_at: datetime
    location: str
    activity: str
    duration_seconds: int = Field(ge=0)
    avg_svm: float = 0
    max_svm: float = 0
    avg_avm_deg: float = 0
    max_avm_deg: float = 0
    max_tilt_degrees: float = 0
    max_heading_deviation_deg: float = 0
    fall_events: int = 0
    impact_events: int = 0
    speech_detected_seconds: int = 0
    avg_speech_level: float = 0
    balance_score: int = Field(ge=0, le=100)
    speech_score: int = Field(ge=0, le=100)
    overall_score: int = Field(ge=0, le=100)
    risk_level: str
    timeline: list[dict[str, Any]] = Field(default_factory=list)
    route: list[dict[str, Any]] = Field(default_factory=list)
    distance_meters: float = 0
    gps_active: bool = False
    speech_analysis: dict[str, Any] | None = None

    @field_validator("risk_level")
    @classmethod
    def validate_risk(cls, value: str) -> str:
        parse_risk_level(value)
        return value


class SessionResponse(BaseModel):
    id: str
    user_id: str
    started_at: datetime
    ended_at: datetime
    location: str
    activity: str
    duration_seconds: int
    avg_svm: float
    max_svm: float
    avg_avm_deg: float
    max_avm_deg: float
    max_tilt_degrees: float
    max_heading_deviation_deg: float
    fall_events: int
    impact_events: int
    speech_detected_seconds: int
    avg_speech_level: float
    balance_score: int
    speech_score: int
    overall_score: int
    risk_level: RiskLevelSchema
    timeline: list[dict[str, Any]]
    route: list[dict[str, Any]]
    distance_meters: float
    gps_active: bool
    speech_analysis: dict[str, Any] | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class SessionSummaryResponse(BaseModel):
    id: str
    started_at: datetime
    ended_at: datetime
    location: str
    activity: str
    duration_seconds: int
    balance_score: int
    speech_score: int
    overall_score: int
    risk_level: RiskLevelSchema


class MotionScoreSubmit(BaseModel):
    balance_score: int = Field(ge=0, le=100)
    avg_svm: float = 0
    max_svm: float = 0
    avg_avm_deg: float = 0
    max_avm_deg: float = 0
    max_tilt_degrees: float = 0
    fall_events: int = 0
    impact_events: int = 0
    session_id: str | None = None
    occurred_at: datetime | None = None


class SpeechScoreSubmit(BaseModel):
    speech_score: int = Field(ge=0, le=100)
    speech_detected_seconds: int = Field(ge=0)
    avg_speech_level: float = 0
    session_id: str | None = None
    occurred_at: datetime | None = None
