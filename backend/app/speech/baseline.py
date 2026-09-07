import json
import math

from app.speech.models import AcousticFeatures


def features_to_json(features: AcousticFeatures) -> str:
    return json.dumps(features.to_dict())


def features_from_json(raw: str | None) -> AcousticFeatures | None:
    if not raw:
        return None
    try:
        data = json.loads(raw)
        if isinstance(data, dict) and "vector_mean" in data:
            vec = data["vector_mean"]
            return AcousticFeatures(
                jitter=vec[0] if len(vec) > 0 else 0,
                shimmer=vec[1] if len(vec) > 1 else 0,
                hnr=vec[2] if len(vec) > 2 else 0,
                pitch_mean=vec[3] if len(vec) > 3 else 0,
                pitch_std=vec[4] if len(vec) > 4 else 0,
            )
        return AcousticFeatures.from_dict(data)
    except (json.JSONDecodeError, TypeError):
        return None


def baseline_from_samples(samples: list[AcousticFeatures]) -> dict:
    if not samples:
        return {}
    vectors = [s.as_vector() for s in samples]
    dim = len(vectors[0])
    mean = [sum(v[i] for v in vectors) / len(vectors) for i in range(dim)]
    return {
        "vector_mean": mean,
        "sample_count": len(samples),
        "feature_names": ["jitter", "shimmer", "hnr", "pitch_mean", "pitch_std"],
    }


def deviation_score(features: AcousticFeatures, baseline: dict | None) -> float | None:
    if not baseline or "vector_mean" not in baseline:
        return None
    vec = features.as_vector()
    mean = baseline["vector_mean"]
    if len(vec) != len(mean):
        return None
    sq = sum((a - b) ** 2 for a, b in zip(vec, mean, strict=True))
    return float(math.sqrt(sq))


def compute_speech_score(
    confirmed_seconds: int,
    duration_seconds: int,
    avg_deviation: float | None,
    *,
    vad_active_seconds: int = 0,
    dysarthria_risk: str = "unknown",
    aphasia_risk: str = "unknown",
    clinical_segment_count: int = 0,
) -> int:
    score = 100
    speech_seconds = max(confirmed_seconds, vad_active_seconds)

    if duration_seconds > 60 and speech_seconds == 0:
        score -= 10
    elif duration_seconds > 0 and speech_seconds > 0:
        ratio = speech_seconds / duration_seconds
        if ratio < 0.05:
            score -= 5

    if avg_deviation is not None:
        if avg_deviation > 2.0:
            score -= 15
        elif avg_deviation > 1.0:
            score -= 8
        elif avg_deviation > 0.5:
            score -= 3

    dys_penalty = {"high": 28, "medium": 20, "low": 10}
    aph_penalty = {"high": 25, "medium": 18, "low": 10}
    score -= dys_penalty.get(dysarthria_risk, 0)
    score -= aph_penalty.get(aphasia_risk, 0)

    if clinical_segment_count > 0:
        score -= min(12, clinical_segment_count * 6)

    return max(0, min(100, score))
