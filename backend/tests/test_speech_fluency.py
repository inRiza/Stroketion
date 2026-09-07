import numpy as np

from app.speech.clinical import live_utterance_alert, utterance_clinical_flags
from app.speech.fluency import analyze_intra_utterance_fluency, session_disfluency_summary
from app.speech.models import SegmentQuality, UtteranceResult


def _stutter_pcm(
    *,
    repeats: int = 6,
    burst_ms: int = 65,
    gap_ms: int = 55,
    sample_rate: int = 16000,
) -> np.ndarray:
    """Simulasi a-a-a-aku: burst pendek + micro-pause."""
    parts: list[np.ndarray] = []
    for _ in range(repeats):
        n_burst = int(sample_rate * burst_ms / 1000)
        n_gap = int(sample_rate * gap_ms / 1000)
        t = np.linspace(0, 4 * np.pi, n_burst)
        parts.append((np.sin(t) * 10000).astype(np.int16))
        parts.append(np.zeros(n_gap, dtype=np.int16))
    n_tail = int(sample_rate * 0.25)
    parts.append((np.sin(np.linspace(0, 6 * np.pi, n_tail)) * 10000).astype(np.int16))
    return np.concatenate(parts)


def _normal_fast_pcm(sample_rate: int = 16000) -> np.ndarray:
    """Percakapan cepat normal: kata/frasa panjang, jeda antar frasa."""
    parts: list[np.ndarray] = []
    for _ in range(6):
        for _word in range(3):
            n_word = int(sample_rate * 0.28)  # ~280ms per kata
            t = np.linspace(0, 10 * np.pi, n_word)
            parts.append((np.sin(t) * 9000).astype(np.int16))
            parts.append(np.zeros(int(sample_rate * 0.07), dtype=np.int16))  # jeda antar kata
        parts.append(np.zeros(int(sample_rate * 0.35), dtype=np.int16))  # jeda antar frasa
    return np.concatenate(parts)


def test_intra_utterance_stutter_detected():
    pcm = _stutter_pcm(repeats=8)
    flu = analyze_intra_utterance_fluency(pcm)
    assert flu["pause_count"] >= 3
    assert flu["disfluency"] in ("medium", "high")


def test_normal_speech_no_micro_pauses():
    sr = 16000
    n = int(sr * 2.0)
    pcm = (np.sin(np.linspace(0, 20 * np.pi, n)) * 8000).astype(np.int16)
    flu = analyze_intra_utterance_fluency(pcm)
    assert flu["disfluency"] == "none"


def test_normal_fast_speech_not_stutter():
    pcm = _normal_fast_pcm()
    flu = analyze_intra_utterance_fluency(pcm)
    assert flu["disfluency"] in ("none", "low")


def test_normal_fast_speech_no_live_alert():
    pcm = _normal_fast_pcm()
    u = UtteranceResult(
        status=SegmentQuality.ANALYZABLE,
        duration_ms=len(pcm) // 16,
        vad_prob_avg=0.85,
        started_at_ms=0,
        pcm_samples=pcm,
    )
    alert = live_utterance_alert([u], u, vad_segment_count=4)
    assert alert is None


def test_single_long_stutter_triggers_live_alert():
    pcm = _stutter_pcm(repeats=9, gap_ms=55)
    u = UtteranceResult(
        status=SegmentQuality.ANALYZABLE,
        duration_ms=len(pcm) // 16,
        vad_prob_avg=0.85,
        started_at_ms=0,
        pcm_samples=pcm,
    )
    alert = live_utterance_alert([u], u, vad_segment_count=2)
    assert alert is not None
    assert alert["severity"] == "high"


def test_utterance_flags_include_disfluency():
    pcm = _stutter_pcm(repeats=8)
    u = UtteranceResult(
        status=SegmentQuality.ANALYZABLE,
        duration_ms=len(pcm) // 16,
        vad_prob_avg=0.8,
        started_at_ms=0,
        pcm_samples=pcm,
    )
    flags = utterance_clinical_flags(u)
    assert "indikasi_disfluensi" in flags or "disfluensi" in flags


def test_softer_stutter_triggers_live_alert():
    pcm = (_stutter_pcm(repeats=7) * 0.35).astype(np.int16)
    u = UtteranceResult(
        status=SegmentQuality.ANALYZABLE,
        duration_ms=len(pcm) // 16,
        vad_prob_avg=0.85,
        started_at_ms=0,
        pcm_samples=pcm,
    )
    alert = live_utterance_alert([u], u, vad_segment_count=2)
    assert alert is not None
    assert alert["severity"] == "high"


def test_session_disfluency_summary():
    pcm = _stutter_pcm(repeats=8)
    u = UtteranceResult(
        status=SegmentQuality.ANALYZABLE,
        duration_ms=len(pcm) // 16,
        vad_prob_avg=0.8,
        started_at_ms=0,
        pcm_samples=pcm,
    )
    summary = session_disfluency_summary([u])
    assert summary["session_disfluency"] in ("low", "medium", "high")
    assert summary["total_micro_pauses"] >= 3
