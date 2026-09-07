from datetime import datetime

from pydantic import BaseModel, Field


class SpeechCalibrateRequest(BaseModel):
    features: list[dict[str, float]] = Field(min_length=3)


class SpeechBaselineUpdate(BaseModel):
    speech_data: dict


class SpeechUtteranceResponse(BaseModel):
    id: str
    monitoring_session_id: str
    user_id: str
    started_at_ms: float
    duration_ms: int
    status: str
    snr_db: float
    vad_prob_avg: float
    acoustic_features: dict | None = None
    deviation_score: float | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class SpeechAnalysisSummary(BaseModel):
    confirmed_seconds: int = 0
    vad_active_seconds: int = 0
    speech_score: int = 100
    utterance_count: int = 0
    low_quality_count: int = 0
    avg_snr_db: float = 0.0
    avg_deviation: float | None = None
    avg_jitter: float | None = None
    avg_shimmer: float | None = None
    avg_hnr: float | None = None
    avg_pitch_std: float | None = None
    dysarthria_risk: str = "unknown"
    aphasia_risk: str = "unknown"
    clinical_notes: list[str] = Field(default_factory=list)
