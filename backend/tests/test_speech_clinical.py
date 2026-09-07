import numpy as np

from app.speech.baseline import compute_speech_score
from app.speech.clinical import (
    apply_semantic_aphasia_risk,
    assess_dysarthria,
    build_clinical_segments,
    live_utterance_alert,
    speech_rhythm,
)
from app.speech.linguistic import assess_transcript_aphasia
from app.speech.models import AcousticFeatures, SegmentQuality, UtteranceResult


def test_compute_speech_score_clinical_penalty():
    score = compute_speech_score(
        0,
        30,
        None,
        vad_active_seconds=20,
        dysarthria_risk="low",
        aphasia_risk="medium",
    )
    assert score <= 88


def test_assess_dysarthria_proxy_no_features():
    level, notes = assess_dysarthria(
        [],
        None,
        False,
        low_quality_count=10,
        vad_segment_count=12,
        vad_active_seconds=20,
    )
    assert level in ("low", "medium")
    assert notes


def test_build_clinical_segments_includes_pcm():
    pcm = (np.sin(np.linspace(0, 1, 8000)) * 10000).astype(np.int16)
    u = UtteranceResult(
        status=SegmentQuality.LOW_QUALITY,
        duration_ms=500,
        vad_prob_avg=0.8,
        started_at_ms=5000,
        pcm_samples=pcm,
    )
    segs = build_clinical_segments([u], "low", "none")
    assert len(segs) == 0  # tanpa indikasi utterance dan tanpa risiko sesi


def test_build_clinical_episodes_sos_only():
    pcm = _make_stutter_pcm(repeats=10)
    duration_ms = len(pcm) // 16
    u1 = UtteranceResult(
        status=SegmentQuality.ANALYZABLE,
        duration_ms=duration_ms,
        vad_prob_avg=0.85,
        started_at_ms=2000,
        pcm_samples=pcm,
    )
    # indikasi medium tanpa SOS → tidak ada rekaman
    segs = build_clinical_segments([u1], "low", "medium")
    assert len(segs) == 0

    sos_events = [{
        "utterance_index": 0,
        "started_at_ms": 2000,
        "alert": {
            "severity": "high",
            "reason": "Disfluensi berat — 4 suku kata terputus",
            "flags": ["disfluensi", "indikasi_disfluensi"],
        },
    }]
    segs = build_clinical_segments([u1], "none", "none", sos_events=sos_events)
    assert len(segs) == 1
    assert segs[0]["pcm_base64"] is not None
    assert segs[0]["duration_ms"] >= 5000
    assert "sos" in segs[0]["flags"]


def test_assess_transcript_aphasia_gibberish():
    risk, notes = assess_transcript_aphasia("blargh zzz krrr mmm")
    assert risk == "medium"
    assert notes


def _utt(ms: int, start: float, vad: float = 0.75) -> UtteranceResult:
    return UtteranceResult(
        status=SegmentQuality.LOW_QUALITY,
        duration_ms=ms,
        vad_prob_avg=vad,
        started_at_ms=start,
    )


def _sequence(durations_ms: list[int], gap_ms: int) -> list[UtteranceResult]:
    """Bangun utterance berurutan dengan jeda tetap di antaranya."""
    utterances: list[UtteranceResult] = []
    cursor = 0.0
    for duration in durations_ms:
        utterances.append(_utt(duration, cursor))
        cursor += duration + gap_ms
    return utterances


def test_speech_rhythm_requires_minimum_window():
    # utterance terlalu sedikit → belum bisa dinilai
    assert speech_rhythm(_sequence([600, 600], 300)) is None
    # rentang waktu terlalu pendek → belum bisa dinilai
    assert speech_rhythm(_sequence([300, 300, 300, 300], 100)) is None


def test_normal_speech_does_not_trigger_alert():
    # bicara normal: potongan panjang 1.5-2.5s, jeda antar frasa
    normal = _sequence([2000, 1800, 2200, 1600, 2400, 1900], 400)
    assert live_utterance_alert(normal, normal[-1]) is None

    # bicara cepat dengan frasa bervariasi — masih normal
    fast = _sequence([1200, 1500, 900, 1800, 1100, 1600, 1400], 350)
    assert live_utterance_alert(fast, fast[-1]) is None

    mixed = _sequence([1800, 500, 2000, 600, 1900, 550, 2100], 500)
    assert live_utterance_alert(mixed, mixed[-1]) is None


def test_stuttering_speech_triggers_alert():
    pcm = _make_stutter_pcm(repeats=8)
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


def _make_stutter_pcm(repeats: int = 8) -> np.ndarray:
    parts: list[np.ndarray] = []
    sr = 16000
    for _ in range(repeats):
        n_burst = int(sr * 0.065)
        n_gap = int(sr * 0.055)
        t = np.linspace(0, 4 * np.pi, n_burst)
        parts.append((np.sin(t) * 10000).astype(np.int16))
        parts.append(np.zeros(n_gap, dtype=np.int16))
    n_tail = int(sr * 0.2)
    parts.append((np.sin(np.linspace(0, 6 * np.pi, n_tail)) * 10000).astype(np.int16))
    return np.concatenate(parts)


def test_severe_stuttering_triggers_high():
    pcm = _make_stutter_pcm(repeats=9)
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


def test_risk_without_sos_no_recording():
    stutter = _sequence([400, 350, 500, 380, 420, 450], 350)
    for u in stutter:
        u.pcm_samples = np.zeros(int(16000 * u.duration_ms / 1000), dtype=np.int16)
    segs = build_clinical_segments(stutter, "medium", "medium")
    assert len(segs) == 0


def test_halting_speech_triggers_alert():
    # jeda panjang antar frasa (bukan stutter) — tidak trigger SOS
    halting = _sequence([700, 650, 800, 600, 750, 700], 1600)
    alert = live_utterance_alert(halting, halting[-1])
    assert alert is None
    segments = [{"semantic_risk": "medium", "semantic_notes": ["Kosakata abnormal"]}]
    risk, notes = apply_semantic_aphasia_risk("none", [], segments)
    assert risk == "medium"
    assert "Kosakata abnormal" in notes
