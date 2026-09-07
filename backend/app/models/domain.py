import enum
from datetime import datetime
from uuid import uuid4

from sqlalchemy import DateTime, Enum, ForeignKey, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class RiskLevel(str, enum.Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


class LinkStatus(str, enum.Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    hashed_password: Mapped[str] = mapped_column(String(255))
    full_name: Mapped[str | None] = mapped_column(String(255))
    phone: Mapped[str | None] = mapped_column(String(20), unique=True, nullable=True)
    gender: Mapped[str | None] = mapped_column(String(20))
    date_of_birth: Mapped[str | None] = mapped_column(String(20))
    role: Mapped[str] = mapped_column(String(50), default="patient")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class CaregiverLink(Base):
    __tablename__ = "caregiver_links"
    __table_args__ = (UniqueConstraint("patient_id", "caregiver_id", name="uq_patient_caregiver"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    patient_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    caregiver_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    status: Mapped[LinkStatus] = mapped_column(Enum(LinkStatus), default=LinkStatus.PENDING)
    relationship: Mapped[str | None] = mapped_column(String(100))
    initiated_by: Mapped[str] = mapped_column(String(20), default="patient")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class PersonalBaseline(Base):
    __tablename__ = "personal_baselines"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), unique=True)
    motion_data: Mapped[str | None] = mapped_column(Text)
    speech_data: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class BehaviourEvent(Base):
    __tablename__ = "behaviour_events"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    event_type: Mapped[str] = mapped_column(String(50))
    description: Mapped[str | None] = mapped_column(Text)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class RiskEvent(Base):
    __tablename__ = "risk_events"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    risk_level: Mapped[RiskLevel] = mapped_column(Enum(RiskLevel))
    motion_status: Mapped[str | None] = mapped_column(String(50))
    speech_status: Mapped[str | None] = mapped_column(String(50))
    last_known_normal_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    first_detected_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    latest_event_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class DeviceToken(Base):
    __tablename__ = "device_tokens"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    fcm_token: Mapped[str] = mapped_column(String(512), unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class MonitoringSession(Base):
    __tablename__ = "monitoring_sessions"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    ended_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    location: Mapped[str] = mapped_column(String(20))
    activity: Mapped[str] = mapped_column(String(20))
    duration_seconds: Mapped[int] = mapped_column()
    avg_svm: Mapped[float] = mapped_column()
    max_svm: Mapped[float] = mapped_column()
    avg_avm_deg: Mapped[float] = mapped_column()
    max_avm_deg: Mapped[float] = mapped_column()
    max_tilt_degrees: Mapped[float] = mapped_column()
    max_heading_deviation_deg: Mapped[float] = mapped_column(default=0)
    fall_events: Mapped[int] = mapped_column(default=0)
    impact_events: Mapped[int] = mapped_column(default=0)
    speech_detected_seconds: Mapped[int] = mapped_column(default=0)
    avg_speech_level: Mapped[float] = mapped_column(default=0)
    balance_score: Mapped[int] = mapped_column()
    speech_score: Mapped[int] = mapped_column()
    overall_score: Mapped[int] = mapped_column()
    risk_level: Mapped[RiskLevel] = mapped_column(Enum(RiskLevel))
    timeline_json: Mapped[str | None] = mapped_column(Text)
    route_json: Mapped[str | None] = mapped_column(Text)
    distance_meters: Mapped[float] = mapped_column(default=0)
    gps_active: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class SpeechUtterance(Base):
    __tablename__ = "speech_utterances"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    monitoring_session_id: Mapped[str] = mapped_column(String(64), index=True)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    started_at_ms: Mapped[float] = mapped_column(default=0)
    duration_ms: Mapped[int] = mapped_column(default=0)
    status: Mapped[str] = mapped_column(String(20))
    snr_db: Mapped[float] = mapped_column(default=0)
    vad_prob_avg: Mapped[float] = mapped_column(default=0)
    acoustic_features_json: Mapped[str | None] = mapped_column(Text)
    deviation_score: Mapped[float | None] = mapped_column(nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
