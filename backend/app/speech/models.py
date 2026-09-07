from dataclasses import dataclass, field
from enum import Enum
from typing import Any


class SegmentQuality(str, Enum):
    SILENCE = "silence"
    NOISE = "noise"
    LOW_QUALITY = "low_quality"
    ANALYZABLE = "analyzable"


@dataclass
class AudioFrame:
    samples: Any  # np.ndarray
    sample_rate: int
    timestamp_ms: float


@dataclass
class AcousticFeatures:
    jitter: float = 0.0
    shimmer: float = 0.0
    hnr: float = 0.0
    pitch_mean: float = 0.0
    pitch_std: float = 0.0
    duration_sec: float = 0.0

    def to_dict(self) -> dict[str, float]:
        return {
            "jitter": self.jitter,
            "shimmer": self.shimmer,
            "hnr": self.hnr,
            "pitch_mean": self.pitch_mean,
            "pitch_std": self.pitch_std,
            "duration_sec": self.duration_sec,
        }

    @classmethod
    def from_dict(cls, data: dict[str, float]) -> "AcousticFeatures":
        return cls(
            jitter=data.get("jitter", 0.0),
            shimmer=data.get("shimmer", 0.0),
            hnr=data.get("hnr", 0.0),
            pitch_mean=data.get("pitch_mean", 0.0),
            pitch_std=data.get("pitch_std", 0.0),
            duration_sec=data.get("duration_sec", 0.0),
        )

    def as_vector(self) -> list[float]:
        return [
            self.jitter,
            self.shimmer,
            self.hnr,
            self.pitch_mean,
            self.pitch_std,
        ]


@dataclass
class UtteranceResult:
    status: SegmentQuality
    duration_ms: int
    snr_db: float = 0.0
    vad_prob_avg: float = 0.0
    features: AcousticFeatures | None = None
    deviation_score: float | None = None
    started_at_ms: float = 0.0
    pcm_samples: Any = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "status": self.status.value,
            "duration_ms": self.duration_ms,
            "snr_db": self.snr_db,
            "vad_prob_avg": self.vad_prob_avg,
            "features": self.features.to_dict() if self.features else None,
            "deviation_score": self.deviation_score,
            "started_at_ms": self.started_at_ms,
        }


@dataclass
class LiveFrameResult:
    speech_active: bool
    energy_dbfs: float
    vad_prob: float
    utterance: UtteranceResult | None = None
    clinical_alert: dict | None = None


@dataclass
class SpeechSummary:
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
    clinical_notes: list[str] = field(default_factory=list)
    clinical_segments: list[dict[str, Any]] = field(default_factory=list)
    peak_clinical_alert: dict[str, Any] | None = None
    utterances: list[UtteranceResult] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        out: dict[str, Any] = {
            "confirmed_seconds": self.confirmed_seconds,
            "vad_active_seconds": self.vad_active_seconds,
            "speech_score": self.speech_score,
            "utterance_count": self.utterance_count,
            "low_quality_count": self.low_quality_count,
            "avg_snr_db": self.avg_snr_db,
            "avg_deviation": self.avg_deviation,
            "avg_jitter": self.avg_jitter,
            "avg_shimmer": self.avg_shimmer,
            "avg_hnr": self.avg_hnr,
            "avg_pitch_std": self.avg_pitch_std,
            "dysarthria_risk": self.dysarthria_risk,
            "aphasia_risk": self.aphasia_risk,
            "clinical_notes": self.clinical_notes,
            "clinical_segments": self.clinical_segments,
            "utterances": [u.to_dict() for u in self.utterances],
        }
        if self.peak_clinical_alert is not None:
            out["peak_clinical_alert"] = self.peak_clinical_alert
        return out
